import hashlib
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from .config import get_settings

_passwords = PasswordHasher()


def hash_password(value: str) -> str:
    return _passwords.hash(value)


def verify_password(encoded: str, value: str) -> bool:
    try:
        return _passwords.verify(encoded, value)
    except (InvalidHashError, VerificationError):
        return False


def random_token(bytes_: int = 32) -> str:
    return secrets.token_urlsafe(bytes_)


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def access_token(user_id: str, session_id: str, role: str) -> tuple[str, datetime]:
    settings = get_settings()
    expires = datetime.now(UTC) + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": user_id,
        "sid": session_id,
        "role": role,
        "iss": settings.issuer,
        "exp": expires,
        "iat": datetime.now(UTC),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256"), expires


def decode_token(value: str) -> dict:
    settings = get_settings()
    return jwt.decode(
        value,
        settings.jwt_secret,
        algorithms=["HS256"],
        issuer=settings.issuer,
        options={"require": ["sub", "sid", "exp", "iat", "iss"]},
    )
