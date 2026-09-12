import os

import pytest


def pytest_sessionstart(session):
    if os.getenv("REQUIRE_INTEGRATION_SERVICES") == "1":
        missing = [key for key in ("POSTGRES_TEST_URL", "REDIS_TEST_URL") if not os.getenv(key)]
        if missing:
            pytest.exit("Integration verification requires: " + ", ".join(missing), returncode=1)
