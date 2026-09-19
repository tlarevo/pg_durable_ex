#!/usr/bin/env bash
set -euo pipefail

# Atomic lifecycle: start → verify → test → cleanup
cleanup() {
  echo "Cleaning up PG17 test environment..."
  docker compose -f docker/docker-compose.pg17.yml down -v 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Starting PostgreSQL 17 with pg_durable v0.2.7 ==="
docker compose -f docker/docker-compose.pg17.yml down -v 2>/dev/null || true
docker compose -f docker/docker-compose.pg17.yml up -d

# Wait for ready
echo "Waiting for PostgreSQL 17..."
until docker compose -f docker/docker-compose.pg17.yml exec -T pg_durable_pg17 pg_isready -U postgres -d postgres 2>/dev/null; do
  sleep 1
done

# Verify
echo "Verifying pg_durable..."
docker compose -f docker/docker-compose.pg17.yml exec -T pg_durable_pg17 psql -U postgres -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_durable';"

echo "=== Running integration tests (PG17) ==="
PG_DURABLE_INTEGRATION=1 PG_DURABLE_PG_VERSION=17 mix test --include pg_durable_integration

echo "=== PG17 integration tests complete ==="
