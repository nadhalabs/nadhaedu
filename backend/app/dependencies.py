from datetime import UTC, datetime
from typing import Annotated

from fastapi import Depends, Header
from jwt import InvalidTokenError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .db import get_session
from .errors import APIError
from .models import AuthSession, User, UserRole
from .security import decode_token

DB = Annotated[AsyncSession, Depends(get_session)]


async def optional_user(db: DB, authorization: Annotated[str | None, Header()] = None) -> User | None:
    if not authorization:
        return None
    return await current_user(db, authorization)


OptionalPrincipal = Annotated[User | None, Depends(optional_user)]


async def current_user(db: DB, authorization: Annotated[str | None, Header()] = None) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise APIError(401, "AUTHENTICATION_REQUIRED", "Authentication is required.")
    try:
        payload = decode_token(authorization[7:])
    except InvalidTokenError:
        raise APIError(401, "SESSION_EXPIRED", "The session is invalid or expired.")
    session = await db.scalar(
        select(AuthSession).where(
            AuthSession.id == payload["sid"], AuthSession.user_id == payload["sub"]
        )
    )
    if not session or session.revoked_at is not None:
        raise APIError(401, "SESSION_REVOKED", "The session has been revoked.")
    session_expires_at = session.expires_at
    if session_expires_at.tzinfo is None:
        session_expires_at = session_expires_at.replace(tzinfo=UTC)
    if session_expires_at <= datetime.now(UTC):
        raise APIError(401, "SESSION_EXPIRED", "The session is invalid or expired.")
    user = await db.get(User, payload["sub"])
    if not user or not user.is_active:
        raise APIError(401, "AUTHENTICATION_REQUIRED", "Account is unavailable.")
    user.current_session_id = payload["sid"]
    return user


import enum


class AdminPermission(str, enum.Enum):
    view_dashboard = "view_dashboard"
    manage_content = "manage_content"
    manage_users = "manage_users"
    revoke_certificates = "revoke_certificates"
    reconcile_commerce = "reconcile_commerce"
    view_audit_logs = "view_audit_logs"


ROLE_PERMISSIONS: dict[UserRole, set[AdminPermission]] = {
    UserRole.super_admin: set(AdminPermission),
    UserRole.admin: {
        AdminPermission.view_dashboard,
        AdminPermission.manage_content,
        AdminPermission.manage_users,
        AdminPermission.revoke_certificates,
        AdminPermission.reconcile_commerce,
        AdminPermission.view_audit_logs,
    },
    UserRole.content_manager: {
        AdminPermission.view_dashboard,
        AdminPermission.manage_content,
    },
    UserRole.support: {
        AdminPermission.view_dashboard,
        AdminPermission.manage_users,
        AdminPermission.revoke_certificates,
        AdminPermission.view_audit_logs,
    },
    UserRole.learner: set(),
}


def require_permission(permission: AdminPermission):
    async def _check(user: Annotated[User, Depends(current_user)]) -> User:
        allowed = ROLE_PERMISSIONS.get(user.role, set())
        if permission not in allowed:
            raise APIError(403, "FORBIDDEN", f"Permission '{permission.value}' is required.")
        return user

    return _check


async def cms_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role not in {
        UserRole.super_admin,
        UserRole.admin,
        UserRole.content_manager,
        UserRole.support,
    }:
        raise APIError(403, "FORBIDDEN", "Administrative permission is required.")
    return user


async def admin_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role not in {UserRole.super_admin, UserRole.admin}:
        raise APIError(403, "FORBIDDEN", "Administrator permission is required.")
    return user


async def content_manager_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role not in {UserRole.super_admin, UserRole.admin, UserRole.content_manager}:
        raise APIError(403, "FORBIDDEN", "Content manager permission is required.")
    return user


async def support_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role not in {UserRole.super_admin, UserRole.admin, UserRole.support}:
        raise APIError(403, "FORBIDDEN", "Support staff permission is required.")
    return user


async def super_admin_user(user: Annotated[User, Depends(current_user)]) -> User:
    if user.role != UserRole.super_admin:
        raise APIError(403, "FORBIDDEN", "Super administrator permission is required.")
    return user


Principal = Annotated[User, Depends(current_user)]
AdminPrincipal = Annotated[User, Depends(admin_user)]
CmsPrincipal = Annotated[User, Depends(cms_user)]
ContentManagerPrincipal = Annotated[User, Depends(content_manager_user)]
SupportPrincipal = Annotated[User, Depends(support_user)]
SuperAdminPrincipal = Annotated[User, Depends(super_admin_user)]
