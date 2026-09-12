from functools import lru_cache
from urllib.parse import urlparse

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="LEARNING_PLATFORM_", env_file=".env")
    database_url: str = "postgresql+asyncpg://learning:learning@localhost/learning_platform"
    jwt_secret: str = "development-only-change-me-before-deploying"
    issuer: str = "learning-platform-api"
    access_token_minutes: int = Field(15, ge=1, le=60)
    refresh_token_days: int = Field(30, ge=1, le=90)
    public_base_url: str = "http://localhost:8000"
    cors_origins: str = "http://localhost:3000"
    environment: str = "development"
    allowed_hosts: str = "localhost,127.0.0.1,testserver"
    redis_url: str = "redis://localhost:6379/0"
    redis_namespace: str = "learning-platform:development"
    media_signing_secret: str = "development-media-secret-change-before-deploying"
    cloudinary_cloud_name: str = ""
    cloudinary_api_key: str = ""
    cloudinary_api_secret: str = Field(default="", repr=False)
    media_token_minutes: int = Field(10, ge=1, le=60)
    media_cdn_base_url: str = "http://localhost:8000/media-origin"
    password_reset_url: str = "http://localhost:3000/reset-password"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_address: str = ""
    smtp_use_tls: bool = True
    sentry_dsn: str = ""
    metrics_token: str = ""
    database_pool_size: int = Field(10, ge=1, le=100)
    database_max_overflow: int = Field(20, ge=0, le=100)
    database_pool_timeout_seconds: int = Field(10, ge=1, le=60)
    statement_timeout_ms: int = Field(10000, ge=1, le=120000)
    apple_key_id: str = ""
    apple_issuer_id: str = ""
    apple_private_key: str = ""
    apple_bundle_id: str = ""
    apple_app_id: int | None = None
    apple_environment: str = "production"
    apple_root_certificate_paths: str = ""
    google_play_service_account_json: str = ""
    google_play_package_name: str = ""
    google_play_pubsub_audience: str = ""
    google_play_pubsub_service_account: str = ""
    stripe_api_key: str = ""
    stripe_webhook_secret: str = ""

    def validate_runtime(self) -> None:
        media_values = (self.cloudinary_cloud_name, self.cloudinary_api_key, self.cloudinary_api_secret)
        if any(media_values) and not all(media_values):
            raise ValueError("Cloudinary provider configuration is incomplete.")
        if self.environment not in {"development", "test", "staging", "production"}:
            raise ValueError("Unsupported environment.")
        if self.environment in {"staging", "production"}:
            required = {
                "jwt_secret": self.jwt_secret,
                "media_signing_secret": self.media_signing_secret,
                "redis_url": self.redis_url,
                "smtp_host": self.smtp_host,
                "smtp_from_address": self.smtp_from_address,
                "password_reset_url": self.password_reset_url,
                "media_cdn_base_url": self.media_cdn_base_url,
                "metrics_token": self.metrics_token,
            }
            insecure = [
                name
                for name, value in required.items()
                if not value
                or any(
                    marker in value.lower()
                    for marker in ("development", "localhost", "replace_", "replace-", "change_me")
                )
            ]
            if insecure:
                raise ValueError(f"Unsafe or missing runtime configuration: {', '.join(insecure)}")
            if len(self.jwt_secret) < 32 or len(self.media_signing_secret) < 32:
                raise ValueError("Signing secrets must contain at least 32 characters.")
            if "*" in {origin.strip() for origin in self.cors_origins.split(",")}:
                raise ValueError("Wildcard CORS is forbidden outside development/test.")
            if urlparse(self.media_cdn_base_url).scheme != "https":
                raise ValueError("Production media CDN URL must use HTTPS.")
            apple_values = (
                self.apple_key_id,
                self.apple_issuer_id,
                self.apple_private_key,
                self.apple_bundle_id,
                self.apple_root_certificate_paths,
            )
            if any(apple_values) and (not all(apple_values) or self.apple_app_id is None):
                raise ValueError("Apple provider configuration is incomplete.")
            google_values = (
                self.google_play_service_account_json,
                self.google_play_package_name,
                self.google_play_pubsub_audience,
                self.google_play_pubsub_service_account,
            )
            if any(google_values) and not all(google_values):
                raise ValueError("Google Play provider configuration is incomplete.")
            if bool(self.stripe_api_key) != bool(self.stripe_webhook_secret):
                raise ValueError("Stripe provider configuration is incomplete.")
            if self.jwt_secret == self.media_signing_secret:
                raise ValueError("Authentication and media signing keys must be different.")
            if len(self.metrics_token) < 32:
                raise ValueError("Metrics token must contain at least 32 characters.")
            for name in ("public_base_url", "password_reset_url", "media_cdn_base_url"):
                parsed = urlparse(getattr(self, name))
                if (
                    parsed.scheme != "https"
                    or not parsed.hostname
                    or parsed.username
                    or parsed.password
                    or parsed.fragment
                    or parsed.hostname in {"localhost", "127.0.0.1", "::1"}
                    or parsed.hostname.endswith(".invalid")
                ):
                    raise ValueError(f"{name} must be an external HTTPS URL without credentials.")
            cors = [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]
            if not cors or any(
                urlparse(origin).scheme != "https"
                or not urlparse(origin).hostname
                or urlparse(origin).path not in {"", "/"}
                or urlparse(origin).query
                or urlparse(origin).fragment
                or urlparse(origin).username
                for origin in cors
            ):
                raise ValueError("CORS must contain exact HTTPS origins.")
            hosts = [host.strip() for host in self.allowed_hosts.split(",") if host.strip()]
            if not hosts or any(
                "*" in host or "/" in host or host in {"localhost", "127.0.0.1", "testserver"}
                for host in hosts
            ):
                raise ValueError("Explicit external allowed_hosts are required.")
            database = urlparse(self.database_url)
            if (
                database.scheme != "postgresql+asyncpg"
                or not database.hostname
                or database.hostname in {"localhost", "127.0.0.1"}
                or database.password in {None, "", "learning", "postgres", "CHANGE_ME"}
            ):
                raise ValueError("An explicitly configured PostgreSQL database is required.")
            if self.redis_namespace.endswith(":development"):
                raise ValueError("Set a separate Redis namespace for this environment.")
            if self.environment == "production" and not self.smtp_use_tls:
                raise ValueError("Production SMTP requires TLS.")


@lru_cache
def get_settings() -> Settings:
    return Settings()
