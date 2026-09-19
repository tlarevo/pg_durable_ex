#!/usr/bin/env bash
set -euo pipefail

PROJECT="pg-durable-ex-test-pg18"
COMPOSE_FILE="docker/docker-compose.pg18.yml"
PORT="${PG_DURABLE_PG18_PORT:-55418}"

cleanup() {
  echo "Cleaning up PG18 test environment (project: ${PROJECT})..."
  docker compose -f "${COMPOSE_FILE}" --project-name "${PROJECT}" down -v 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Starting PostgreSQL 18 with pg_durable v0.2.7 (port ${PORT}) ==="
docker compose -f "${COMPOSE_FILE}" --project-name "${PROJECT}" down -v 2>/dev/null || true
docker compose -f "${COMPOSE_FILE}" --project-name "${PROJECT}" up -d

# Wait for ready — container is named by Compose project, not the service key
CONTAINER="${PROJECT}-pg_durable_pg18-1"

echo "Waiting for PostgreSQL 18 on port ${PORT}..."
until docker exec "${CONTAINER}" pg_isready -U postgres -d postgres 2>/dev/null; do
  sleep 1
done

# Verify
echo "Verifying pg_durable..."
docker exec "${CONTAINER}" psql -U postgres -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_durable';"

echo "=== Running integration tests (PG18, port ${PORT}) ==="
PG_DURABLE_INTEGRATION=1 PG_DURABLE_PG_VERSION=18 mix test --include pg_durable_integration

echo "=== PG18 integration tests complete ==="
