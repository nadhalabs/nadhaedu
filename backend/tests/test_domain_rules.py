import base64
from datetime import UTC, datetime

import pytest

from app.errors import APIError
from app.services import (
    cursor_decode,
    cursor_encode,
    fingerprint,
    scalar_cursor_decode,
    scalar_cursor_encode,
)


def test_cursor_round_trip_is_stable():
    instant = datetime(2026, 8, 31, 10, 0, tzinfo=UTC)
    assert cursor_decode(cursor_encode(instant, "credential-id")) == (instant, "credential-id")


def test_invalid_cursor_is_typed():
    with pytest.raises(APIError) as error:
        cursor_decode("not-valid")
    assert error.value.code == "INVALID_CURSOR"


def test_cursor_rejects_timezone_less_timestamp():
    raw = base64.urlsafe_b64encode(b"2026-08-31T12:00:00|row-id").decode().rstrip("=")
    with pytest.raises(APIError) as error:
        cursor_decode(raw)
    assert error.value.code == "INVALID_CURSOR"


def test_scalar_cursor_round_trip_is_stable():
    assert scalar_cursor_decode(scalar_cursor_encode(4.75, "course-id")) == (
        4.75,
        "course-id",
    )


def test_request_fingerprint_is_order_independent_but_content_sensitive():
    assert fingerprint({"a": 1, "b": 2}) == fingerprint({"b": 2, "a": 1})
    assert fingerprint({"a": 1}) != fingerprint({"a": 2})
