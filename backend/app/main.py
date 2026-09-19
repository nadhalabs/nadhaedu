import asyncio
import re
import secrets
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from starlette.exceptions import HTTPException
from starlette.middleware.trustedhost import TrustedHostMiddleware

from .academic import router as academic_router
from .api import router
from .cms_operations import router as cms_operations_router
from .config import get_settings
from .db import session_factory
from .delivery import SMTPPasswordResetDelivery
from .errors import APIError, api_error_handler, http_error_handler, validation_error_handler
from .media_workflow import router as media_workflow_router
from .observability import Metrics, configure_logging, request_observability, scrub_error_event
from .rate_limit import DistributedRateLimiter, policy_for
from .readiness import schema_status

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate_runtime()
    app.state.settings = settings
    app.state.logger = configure_logging()
    app.state.metrics = Metrics()
    app.state.redis = Redis.from_url(
        settings.redis_url, decode_responses=True, socket_connect_timeout=2, socket_timeout=2
    )
    app.state.rate_limiter = DistributedRateLimiter(app.state.redis, settings)
    app.state.password_reset_delivery = SMTPPasswordResetDelivery(settings)
    if settings.sentry_dsn:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.environment,
            send_default_pii=False,
            traces_sample_rate=0.0,
            before_send=scrub_error_event,
            include_local_variables=False,
        )
    try:
        yield
    finally:
        await app.state.redis.aclose()
        factory = session_factory()
        await factory.kw["bind"].dispose()
        session_factory.cache_clear()


app = FastAPI(title="Nadha Edu API", version="1.0.0", lifespan=lifespan)
app.state.settings = settings
app.state.logger = configure_logging()
app.state.metrics = Metrics()
app.state.redis = Redis.from_url(
    settings.redis_url, decode_responses=True, socket_connect_timeout=2, socket_timeout=2
)
app.state.rate_limiter = DistributedRateLimiter(app.state.redis, settings)
app.state.password_reset_delivery = SMTPPasswordResetDelivery(settings)
app.add_exception_handler(APIError, api_error_handler)
app.add_exception_handler(RequestValidationError, validation_error_handler)
app.add_exception_handler(HTTPException, http_error_handler)
if settings.environment in {"staging", "production"}:
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=[host.strip() for host in settings.allowed_hosts.split(",")],
    )
origins = [x.strip() for x in get_settings().cors_origins.split(",") if x.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"],
    expose_headers=["X-Request-ID", "Retry-After"],
)


@app.middleware("http")
async def correlation(request: Request, call_next):
    supplied_id = request.headers.get("X-Request-ID", "")
    request.state.request_id = (
        supplied_id if re.fullmatch(r"[A-Za-z0-9._-]{1,64}", supplied_id) else str(uuid.uuid4())
    )

    async def protected_call(request):
        policy = policy_for(request)
        if policy and settings.environment in {"staging", "production"}:
            try:
                await request.app.state.rate_limiter.enforce(request, policy)
            except APIError as error:
                response = await api_error_handler(request, error)
                if hasattr(error, "retry_after"):
                    response.headers["Retry-After"] = str(error.retry_after)
                return response
        return await call_next(request)

    response = await request_observability(request, protected_call)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Frame-Options"] = "DENY"
    if settings.environment in {"staging", "production"}:
        response.headers["Strict-Transport-Security"] = "max-age=31536000"
    if request.url.path.startswith(("/api/", "/v1/")):
        response.headers["Cache-Control"] = "no-store"
    response.headers["X-Request-ID"] = request.state.request_id
    if request.url.path.startswith("/v1/"):
        response.headers["Deprecation"] = "true"
        response.headers["Sunset"] = "Tue, 31 Aug 2027 00:00:00 GMT"
        response.headers["Link"] = '</api/v1>; rel="successor-version"'
    return response


@app.get("/health/live")
async def liveness():
    return {"status": "ok"}


@app.get("/health/ready")
async def readiness(request: Request):
    try:
        async with asyncio.timeout(5):
            async with session_factory()() as db:
                await db.execute(text("SELECT 1"))
                schema = await schema_status(db)
            if not schema["schemaReady"]:
                raise RuntimeError("migration mismatch")
    except (SQLAlchemyError, RuntimeError, TimeoutError):
        raise APIError(503, "NOT_READY", "The service is not ready to receive traffic.")
    redis_ready = await request.app.state.rate_limiter.redis_ready()
    if not redis_ready and request.app.state.settings.redis_required:
        raise APIError(503, "NOT_READY", "The service is not ready to receive traffic.")
    return {"status": "ready", "redisStatus": "healthy" if redis_ready else "degraded"}


@app.get("/metrics", include_in_schema=False)
async def metrics(request: Request):
    expected = settings.metrics_token
    if expected and not secrets.compare_digest(
        request.headers.get("Authorization", ""), f"Bearer {expected}"
    ):
        raise APIError(404, "NOT_FOUND", "Resource not found.")
    return PlainTextResponse(
        request.app.state.metrics.render(), media_type="text/plain; version=0.0.4"
    )


@app.get("/health", deprecated=True)
async def health_compatibility():
    return {"status": "ok"}


app.include_router(media_workflow_router, prefix="/api/v1")
app.include_router(router, prefix="/api/v1")
app.include_router(academic_router, prefix="/api/v1")
app.include_router(academic_router, prefix="/v1", include_in_schema=False)
app.include_router(cms_operations_router, prefix="/api/v1")
app.include_router(router, prefix="/v1", include_in_schema=False)
app.include_router(cms_operations_router, prefix="/v1", include_in_schema=False)
