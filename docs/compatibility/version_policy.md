# pg_durable Version Support Policy

## Supported pg_durable versions

| Version  | Status          | PostgreSQL | Notes                                   |
|----------|-----------------|------------|-----------------------------------------|
| v0.2.7   | Primary target  | 17, 18     | Pinned at September 2026 project refresh |
| main     | Experimental    | 17, 18     | Non-blocking drift lane, detects breaking changes early |

## Experimental versions

Any upstream pg_durable version not explicitly listed as supported is experimental. Experimental versions may work but are not guaranteed.

## Unsupported versions

pg_durable versions prior to v0.2.0 are not supported and will not receive bug fixes.

## pg_durable_ex version mapping

pg_durable_ex versions do not directly map to pg_durable versions. The compatibility matrix in `docs/compatibility/pg_durable_dsl_matrix.md` defines which pg_durable constructs each pg_durable_ex version supports.

## Upstream changes

When pg_durable changes DSL syntax, function signatures, result shapes, or privilege behavior:

1. The compatibility matrix is updated
2. Breaking changes require a pg_durable_ex minor or major version bump
3. Non-breaking additions may be picked up in patch releases

## Reporting compatibility bugs

Open an issue at https://github.com/tlarevo/pg_durable_ex/issues with:

- pg_durable version
- PostgreSQL version
- pg_durable_ex version
- Reproduction steps
- Expected vs actual behavior

## Running the compatibility test suite locally

```bash
# Unit tests (no PostgreSQL required)
devbox run test

# Integration tests against PG17
devbox run test-integration-pg17

# Integration tests against PG18
devbox run test-integration-pg18
```

Integration tests require Docker or Podman. Never use your system PostgreSQL.

## CI lanes

| Lane            | Trigger        | PostgreSQL | pg_durable | Purpose                          |
|-----------------|----------------|------------|------------|----------------------------------|
| Unit            | Every PR       | None       | None       | Format, compile, unit tests      |
| Integration PG17| Main push      | 17 (disposable) | v0.2.7 | Conformance against PG17    |
| Integration PG18| Main push      | 18 (disposable) | v0.2.7 | Conformance against PG18    |
| Upstream drift  | Scheduled      | 17/18      | main       | Detect breaking changes early    |

## Production readiness

**pg_durable is currently labeled Preview upstream.** pg_durable_ex does not claim production or stable readiness until both conformance and command-centre viability gates pass.
