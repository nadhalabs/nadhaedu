#!/usr/bin/env bash
set -euo pipefail
: "${RESTORE_DATABASE_URL:?RESTORE_DATABASE_URL is required}"
: "${BACKUP_PATH:?BACKUP_PATH is required}"
pg_bin="${POSTGRES_BIN:-}"
"${pg_bin}pg_restore" --clean --if-exists --no-owner --no-acl --dbname="$RESTORE_DATABASE_URL" "$BACKUP_PATH"
"${pg_bin}psql" "$RESTORE_DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT version_num FROM alembic_version;" -c "SELECT count(*) AS users FROM users;" -c "SELECT count(*) AS courses FROM courses;" -c "SELECT count(*) AS orphan_lessons FROM lessons l LEFT JOIN course_modules m ON m.id=l.module_id WHERE m.id IS NULL;"
