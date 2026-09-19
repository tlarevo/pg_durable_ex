# pg_durable_ex

Thin typed facade, compiler, and execution client for [pg_durable](https://github.com/nicholasgasior/pg_durable).

> **Status: Experimental** — upstream pg_durable is in Preview. This library makes no production-readiness claims.

## Architecture

- **OTP** supervises the runtime tree and connection pools.
- **pg_durable** owns durable state — the single source of truth for transactional consistency.
- **Oban** owns bounded async execution — jobs, retries, and backoff.
- **PostgreSQL / Ecto** owns domain records — queries, migrations, and schema.
- **Provider executors** own external effects — side effects triggered by durable state changes.

No two layers may become authoritative for the same state. Each layer has a single responsibility; crossing boundaries requires explicit handoff through the layer above or below.

## Getting Started

### Prerequisites

- Elixir 1.17+
- OTP 27+
- [Devbox](https://www.jetify.com/devbox/) recommended for reproducible toolchains

### Installation

Add `pg_durable_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_durable_ex, "~> 0.1.0"}
  ]
end
```

### Clone

```bash
git clone git@github.com:tlarevo/pg_durable_ex.git
cd pg_durable_ex
```

## Development

```bash
# Enter the devbox shell
devbox shell

# Run unit tests (no external services required)
devbox run test

# Full check: format + compile (warnings-as-errors) + unit tests
devbox run check
```

Or manually:

```bash
mix deps.get
mix test
```

## Integration Testing

Integration tests exercise pg_durable against real PostgreSQL instances. **Never use system PostgreSQL for integration tests** — disposable, project-owned instances only.

```bash
# Run integration tests against PostgreSQL 17
devbox run test-integration-pg17

# Run integration tests against PostgreSQL 18
devbox run test-integration-pg18

# Run both PG17 and PG18 integration lanes
devbox run test-integration
```

Requires Docker or Podman to spin up disposable PostgreSQL containers. See [docs/integration_test_contract.md](docs/integration_test_contract.md) for the full isolation contract.

## Compatibility

| Component | Version |
|-----------|---------|
| pg_durable | v0.2.7 |
| PostgreSQL | 17, 18 |

See [docs/compatibility/version_policy.md](docs/compatibility/version_policy.md) for the version compatibility and upgrade policy.

## Contributing

1. Read the [integration test contract](docs/integration_test_contract.md) before writing tests.
2. Unit tests are required for all changes — they must pass without PostgreSQL or any external service.
3. Integration tests are required when changing pg_durable interaction, SQL generation, or connection handling.

## License

TODO: to be determined.
