#!/usr/bin/env bash
set -euo pipefail

echo "=== Running integration tests on PG17 ==="
bin/test-integration-pg17.sh

echo ""
echo "=== Running integration tests on PG18 ==="
bin/test-integration-pg18.sh

echo ""
echo "=== All integration tests complete ==="
