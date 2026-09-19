#!/usr/bin/env bash
set -euo pipefail

PG_VERSION="${PG_DURABLE_PG_VERSION:-17}"

echo "Stopping test PostgreSQL instances..."

case "$PG_VERSION" in
  17) docker compose -f docker/docker-compose.pg17.yml down -v ;;
  18) docker compose -f docker/docker-compose.pg18.yml down -v ;;
  all)
    docker compose -f docker/docker-compose.pg17.yml down -v
    docker compose -f docker/docker-compose.pg18.yml down -v
    ;;
  *)
    echo "Stopping all..."
    docker compose -f docker/docker-compose.pg17.yml down -v
    docker compose -f docker/docker-compose.pg18.yml down -v
    ;;
esac

echo "Done."
