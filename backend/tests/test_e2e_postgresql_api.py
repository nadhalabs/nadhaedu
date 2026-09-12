import os
import uuid
from urllib.parse import parse_qs, urlparse

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.db import session_factory

pytestmark = pytest.mark.skipif(
    not os.getenv("POSTGRES_TEST_URL"), reason="POSTGRES_TEST_URL is required"
)


class CaptureDelivery:
    def __init__(self):
        self.urls = []

    async def send(self, *, recipient, reset_url, expires_minutes):
        self.urls.append(reset_url)


@pytest_asyncio.fixture(autouse=True)
async def dispose_application_pool_between_event_loops():
    yield
    await session_factory().kw["bind"].dispose()


@pytest.mark.asyncio
async def test_auth_refresh_and_canonical_api_contract():
    from app.main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://integration.test"
    ) as client:
        registration = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "integration-contract-20260831@example.com",
                "password": "correct-horse-battery-staple",
                "displayName": "Integration Learner",
            },
        )
        if registration.status_code == 409:
            registration = await client.post(
                "/api/v1/auth/login",
                json={
                    "email": "integration-contract-20260831@example.com",
                    "password": "correct-horse-battery-staple",
                },
            )
        assert registration.status_code == 200 or registration.status_code == 201
        session = registration.json()
        assert session["accessToken"] and session["refreshToken"]
        headers = {"Authorization": f"Bearer {session['accessToken']}"}
        me = await client.get("/api/v1/auth/me", headers=headers)
        assert me.status_code == 200
        assert me.headers["x-request-id"]

        refreshed = await client.post(
            "/api/v1/auth/refresh", json={"refreshToken": session["refreshToken"]}
        )
        assert refreshed.status_code == 200
        assert refreshed.json()["refreshToken"] != session["refreshToken"]
        assert (await client.get("/api/v1/auth/me", headers=headers)).status_code == 401
        new_headers = {"Authorization": f"Bearer {refreshed.json()['accessToken']}"}
        assert (await client.get("/api/v1/courses?pageSize=10")).status_code == 200
        assert (await client.get("/api/v1/entitlements", headers=new_headers)).status_code == 200
        assert (await client.get("/v1/entitlements", headers=new_headers)).status_code == 200


@pytest.mark.asyncio
async def test_password_reset_delivery_single_use_and_session_revocation():
    from app.main import app

    delivery = CaptureDelivery()
    app.state.password_reset_delivery = delivery
    email = f"reset-integration-{uuid.uuid4()}@example.com"
    password = "correct-horse-battery-staple"
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://integration.test"
    ) as client:
        registered = await client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": password, "displayName": "Reset Learner"},
        )
        assert registered.status_code == 201
        old_headers = {"Authorization": f"Bearer {registered.json()['accessToken']}"}
        unknown = await client.post(
            "/api/v1/auth/password-reset/request", json={"email": "unknown-20260831@example.com"}
        )
        known = await client.post("/api/v1/auth/password-reset/request", json={"email": email})
        assert unknown.status_code == known.status_code == 202
        assert len(delivery.urls) == 1
        token = parse_qs(urlparse(delivery.urls[0]).query)["token"][0]
        confirmed = await client.post(
            "/api/v1/auth/password-reset/confirm",
            json={
                "email": email,
                "verificationCode": token,
                "newPassword": "new-correct-horse-battery-staple",
            },
        )
        assert confirmed.status_code == 200
        assert (await client.get("/api/v1/auth/me", headers=old_headers)).status_code == 401
        reused = await client.post(
            "/api/v1/auth/password-reset/confirm",
            json={
                "email": email,
                "verificationCode": token,
                "newPassword": "another-correct-horse-battery",
            },
        )
        assert reused.status_code == 410
