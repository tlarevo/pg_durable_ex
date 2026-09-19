# Core Completion Gate

Every release must satisfy every gate below. No exceptions, no partial passes.

## PR Evidence

Every PR must demonstrate:

- [ ] `mix format --check-formatted` passes
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix test` passes (unit)
- [ ] Integration tests pass (PG17 + PG18)
- [ ] No regressions in conformance test count

## CI Evidence

CI runs **three lanes on every PR and every push to main**:

- [ ] Unit test lane (format + compile + test)
- [ ] Integration PG17 lane (real pg_durable extension, `PG_DURABLE_INTEGRATION=1`)
- [ ] Integration PG18 lane (real pg_durable extension, `PG_DURABLE_INTEGRATION=1`)

All three lanes are required for merge. Integration lanes run against live PostgreSQL containers with the pg_durable extension loaded. A green CI means the extension, its SQL safety layer, and the Elixir wrapper all agree.

## Review Evidence

- [ ] All diagnostic codes are stable and documented
- [ ] No generic exceptions in public API — every error carries a typed tag
- [ ] SQL output is inspectable — no opaque query strings
- [ ] No secrets or credentials in code or history
- [ ] Public API surface matches `lib/pg_durable.ex` facade

## What is NOT Included in Alpha

- Production-ready connection pooling (use DBConnection for that)
- Cluster-wide durability guarantees (single-node only)
- Automatic failover or replication
- Full monitoring/metrics integration (telemetry events are emitted, dashboards are DIY)
- Backwards-compatible upgrade path from alpha (schema may change)
- Production load testing or performance benchmarks

## How to Gate a Release

1. Open a PR. CI runs all three lanes.
2. PR evidence checklist is self-service — run the commands locally, CI confirms on push.
3. Review evidence is reviewer-checked against the diff.
4. All three boxes checked → release can be tagged.
