#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_PATH:?BACKUP_PATH is required}"
umask 077
pg_bin="${POSTGRES_BIN:-}"
"${pg_bin}pg_dump" --format=custom --no-owner --no-acl --file="$BACKUP_PATH" "$DATABASE_URL"
"${pg_bin}pg_restore" --list "$BACKUP_PATH" >/dev/null
