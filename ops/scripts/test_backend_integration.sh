#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT/backend"
: "${POSTGRES_TEST_URL:?Set POSTGRES_TEST_URL to an isolated PostgreSQL test database}"
: "${REDIS_TEST_URL:?Set REDIS_TEST_URL to an isolated Redis test instance}"
export LEARNING_PLATFORM_DATABASE_URL="$POSTGRES_TEST_URL"
export LEARNING_PLATFORM_ENVIRONMENT=test
export LEARNING_PLATFORM_REDIS_URL="$REDIS_TEST_URL"
export REQUIRE_INTEGRATION_SERVICES=1
python -m alembic upgrade head
python -m alembic check
python -m pytest -o addopts='' -q --junitxml=../build/backend-integration-results.xml
