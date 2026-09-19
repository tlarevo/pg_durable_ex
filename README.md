# pg_durable_ex

Thin Elixir facade, compiler, and execution client for [Microsoft pg_durable](https://github.com/microsoft/pg_durable).

> **Status: Experimental** — Upstream pg_durable is currently labeled Preview. pg_durable_ex remains experimental until conformance and viability gates pass.

## What is pg_durable_ex?

A typed Elixir API for building and inspecting durable workflows via PostgreSQL's pg_durable extension. It provides:

- Typed workflow AST (SQL, sequence, named results, joins, conditionals, sleep, signals)
- Safe SQL generation with literal/identifier quoting
- Result reference typing (`$name`, `$name.column`, `$name.*`)
- Workflow validation with structured diagnostics
- SQL inspection for debugging

## What pg_durable_ex is NOT

- An Ecto adapter (see [pg_durable_ecto](https://github.com/tlarevo/pg_durable_ecto))
- An Oban bridge (see [pg_durable_oban](https://github.com/tlarevo/pg_durable_oban))
- An Ash adapter (deferred)
- A workflow execution runtime (pg_durable handles execution in PostgreSQL)

## Installation

Add `pg_durable_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pg_durable_ex, "~> 0.1.0", git: "https://github.com/tlarevo/pg_durable_ex.git"}
  ]
end
```

## Quick Start

```elixir
# Build a workflow
workflow =
  PgDurable.new(name: "process_data")
  |> Map.put(:root,
    PgDurable.then(
      PgDurable.named(
        PgDurable.sql("SELECT id FROM documents WHERE processed = false LIMIT 100"),
        "batch"
      ),
      PgDurable.sql(
        "UPDATE documents SET processed = true WHERE id IN (SELECT id FROM $batch.*)"
      )
    )
  )

# Inspect the generated SQL
{:ok, sql} = PgDurable.to_sql(workflow)
# => "SELECT df.start('SELECT id ...' |=> 'batch' ~> 'UPDATE documents ...')"

# Validate before rendering
:ok = PgDurable.validate(workflow)
```

## Public API

### Workflow Construction

| Function | Description |
|----------|-------------|
| `PgDurable.new(name: "name")` | Create a workflow |
| `PgDurable.sql("SELECT 1")` | Raw SQL node |
| `PgDurable.then(left, right)` | Sequence (`~>`) |
| `PgDurable.named(node, "name")` | Named result capture (`\|=>`) |
| `PgDurable.join(left, right)` | Parallel join (`&`) |
| `PgDurable.if_(condition, then, else)` | Conditional (`?> !>`) |
| `PgDurable.sleep(seconds)` | Timed pause (`df.sleep/1`) |
| `PgDurable.wait_for_signal("name")` | Block until signal (`df.wait_for_signal/1`) |
| `PgDurable.raw_expr("df.sleep(10)")` | Escape hatch for deferred constructs |

### References

| Function | Produces | Example |
|----------|----------|---------|
| `PgDurable.ref(:name)` | `$name` | Result reference |
| `PgDurable.ref(:result, :column)` | `$name.column` | Column access |
| `PgDurable.rowset(:name)` | `$name.*` | Row-set expansion |

### Rendering and Validation

| Function | Returns | Description |
|----------|---------|-------------|
| `PgDurable.to_expr(workflow)` | `{:ok, string} \| {:error, [Diagnostic]}` | Graph expression string |
| `PgDurable.to_sql(workflow)` | `{:ok, string} \| {:error, [Diagnostic]}` | Full `SELECT df.start(...)` statement |
| `PgDurable.to_start_sql(workflow)` | Same as `to_sql/1` | Alias |
| `PgDurable.validate(workflow)` | `:ok \| [Diagnostic.t()]` | Validate before rendering |

## Supported Constructs (v0.1)

22 of 44 upstream constructs are supported with typed builders:

| Category | Supported | Deferred |
|----------|-----------|----------|
| Graph operators | `~>`, `\|=>`, `&`, `?> !>` | `\|` (race), `@>` (loop) |
| Graph functions | SQL node, `df.sleep/1`, `df.if/3`, `df.wait_for_signal/1` | `df.http/5`, `df.wait_for_schedule/1`, `df.join3/3`, `df.race/2`, `df.loop/1,2`, `df.break/0,1`, `df.if_rows/3` |
| Result substitution | `$name`, `$name.column`, `$name.*` | `$name?`, `$name.column?` |
| Control plane | `df.start`, `df.status`, `df.result`, `df.cancel`, `df.explain`, `df.list_instances`, `df.signal` | `df.await_instance`, `df.setvar/getvar` |

Use `PgDurable.raw_expr/1` as an escape hatch for deferred constructs.

See [docs/compatibility/pg_durable_dsl_matrix.md](docs/compatibility/pg_durable_dsl_matrix.md) for the full construct matrix.

## SQL Safety Model

All SQL strings pass through `PgDurable.SQL.Safety` before rendering:

- **String literals**: single-quote escaped, null bytes rejected
- **Identifiers**: double-quote escaped, null bytes rejected
- **Literals**: type-aware quoting (integers, floats, booleans, dates, JSON)
- **Raw expressions**: `PgDurable.Node.RawExpr` bypasses safety — use with caution

## Compatibility

| Component | Version |
|-----------|---------|
| pg_durable | v0.2.7 (pinned) |
| PostgreSQL | 17, 18 |
| Elixir | 1.17+ |
| OTP | 27+ |

See [docs/compatibility/version_policy.md](docs/compatibility/version_policy.md) for the full version policy.

## Development

```bash
devbox shell          # enter supported environment
devbox run test       # unit tests (no PostgreSQL required)
devbox run check      # format + compile (warnings-as-errors) + unit tests
```

## Integration Testing

Integration tests exercise pg_durable against real PostgreSQL instances. **Never use your system PostgreSQL for integration tests.**

```bash
# Start PG17 with pg_durable
docker compose -f docker/docker-compose.pg17.yml up -d

# Run all integration tests
PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration

# Run a specific integration test
PG_DURABLE_INTEGRATION=1 mix test test/pg_durable/conformance_test.exs

# Or use the lifecycle script
bin/test-integration-pg17.sh

# Stop and cleanup
docker compose -f docker/docker-compose.pg17.yml down -v
```

See [docs/integration_test_contract.md](docs/integration_test_contract.md) for the full isolation contract.

## SQL Inspection and Debugging

```elixir
# See the graph expression
{:ok, expr} = PgDurable.to_expr(workflow)

# See the full SQL statement
{:ok, sql} = PgDurable.to_sql(workflow)

# Validate before rendering
:ok = PgDurable.validate(workflow)
```

See [docs/debugging/sql_inspection.md](docs/debugging/sql_inspection.md) for the full guide.

## Optional Adapters

- **[pg_durable_ecto](https://github.com/tlarevo/pg_durable_ecto)** — `Ecto.Repo` execution API, `Ecto.Query` lowering
- **[pg_durable_oban](https://github.com/tlarevo/pg_durable_oban)** — Oban bridge for hybrid pg_durable + Oban execution

## Contributing

1. Read the [integration test contract](docs/integration_test_contract.md) before writing tests.
2. Unit tests are required for all changes — they must pass without PostgreSQL.
3. Integration tests are required when changing pg_durable interaction, SQL generation, or connection handling.

## License

TODO: to be determined
