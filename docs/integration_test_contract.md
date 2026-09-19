# Integration Test Isolation Contract

This document defines the rules for pg_durable integration tests. Follow these without exception.

## Rule 1: Never use system PostgreSQL

Integration tests for pg_durable **must never** connect to, create databases on, or depend on the system PostgreSQL installation. System PostgreSQL is shared infrastructure — tests that modify it break other work and violate isolation.

## Rule 2: Disposable project-owned instances only

Every integration test run must operate against a disposable PostgreSQL instance that:
- Is created for the test run and destroyed after.
- Lives in an isolated namespace (container, separate data directory, non-default port).
- Contains no data from prior test runs.

## Rule 3: Separate PG17 and PG18 compatibility lanes

Integration tests run in two parallel lanes:
- **PG17 lane** — targets PostgreSQL 17.
- **PG18 lane** — targets PostgreSQL 18.

Each lane uses its own disposable instance. A test that passes on PG17 may fail on PG18; both lanes must pass independently.

## Rule 4: Pinned pg_durable release versions

Integration tests against the release channel use a pinned pg_durable version (currently **v0.2.7**). Source-level viability tests may test against the pg_durable source at a known commit, but this is a separate concern from release compatibility.

## Rule 5: Non-default or dynamically allocated ports

Disposable instances must bind to non-default ports (e.g. **55417** for PG17, **55418** for PG18) or use fully dynamic port allocation. Never bind to the default PostgreSQL port (5432).

## Rule 6: Server version, extension version, and harness identity checks

Before any destructive setup (creating databases, installing extensions, running migrations), the test harness must verify:
- **Server major version** matches the lane target (17 or 18).
- **pg_durable extension version** matches the pinned release.
- **Harness identity** confirms the instance belongs to this test run and is not a shared or persistent instance.

If any check fails, abort with a clear error — never proceed with an unverified instance.

## Rule 7: Cleanup after test run

Every test run must clean up:
- Disposable PostgreSQL containers or data directories.
- Any databases, roles, or extensions created during the test.
- Temp files, logs, and connection pools.

Cleanup runs regardless of test pass/fail status.

## Rule 8: Three testing layers

| Layer | Scope | PostgreSQL required | pg_durable required |
|-------|-------|--------------------|--------------------|
| **Unit** | Mix only, pure Elixir | No | No |
| **Release integration** | Disposable PG17/PG18 containers | Yes | Yes |
| **Source/viability** | Reproducible pg_durable source build | Yes | Yes (source) |

Unit tests must pass in isolation without any external services. Integration and source tests are opt-in via the `PG_DURABLE_INTEGRATION=1` environment variable.

## Rule 9: Failure escalation

If the required isolated environment **cannot** be established (Docker unavailable, port conflicts, image pull failure, version mismatch), the test harness must **fail with an actionable error message**. It must never:

- Fall back to system PostgreSQL.
- Skip the test silently.
- Connect to an unverified instance.

The error message must state what failed, what was expected, and how to fix it.
