#!/usr/bin/env bash
set -euo pipefail

PG_VERSION="${PG_DURABLE_PG_VERSION:-17}"

echo "Starting PostgreSQL ${PG_VERSION} with pg_durable..."

case "$PG_VERSION" in
  17)
    docker compose -f docker/docker-compose.pg17.yml up -d
    echo "Waiting for PostgreSQL 17 to be ready on port 55417..."
    until docker compose -f docker/docker-compose.pg17.yml exec -T pg_durable_pg17 pg_isready -U postgres -d postgres 2>/dev/null; do
      sleep 1
    done
    echo "Verifying pg_durable extension..."
    docker compose -f docker/docker-compose.pg17.yml exec -T pg_durable_pg17 psql -U postgres -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_durable';"
    ;;
  18)
    docker compose -f docker/docker-compose.pg18.yml up -d
    echo "Waiting for PostgreSQL 18 to be ready on port 55418..."
    until docker compose -f docker/docker-compose.pg18.yml exec -T pg_durable_pg18 pg_isready -U postgres -d postgres 2>/dev/null; do
      sleep 1
    done
    echo "Verifying pg_durable extension..."
    docker compose -f docker/docker-compose.pg18.yml exec -T pg_durable_pg18 psql -U postgres -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_durable';"
    ;;
  *)
    echo "Unsupported PG version: $PG_VERSION (expected 17 or 18)"
    exit 1
    ;;
esac

echo "PostgreSQL ${PG_VERSION} ready with pg_durable."
