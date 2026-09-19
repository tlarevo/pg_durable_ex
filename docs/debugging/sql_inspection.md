# SQL Inspection and Debugging Guide

## Inspecting Generated SQL

pg_durable_ex generates SQL that you can inspect before execution. Rendering functions (`to_expr`, `to_sql`) return `{:ok, sql}` on success or `{:error, [Diagnostic]}` on failure. Validation (`validate`) returns `:ok` or a plain list of diagnostics.

### Graph Expression

`PgDurable.to_expr/1` renders just the graph expression — the inner DAG without the `df.start()` wrapper:

```elixir
{:ok, expr} = PgDurable.to_expr(workflow)
# => "'SELECT 1' ~> 'SELECT 2'"
```

Use this to verify the structure of your workflow DAG before wrapping it in a full statement.

### Full SQL Statement

`PgDurable.to_sql/1` renders the complete `SELECT df.start(...)` statement ready for execution:

```elixir
{:ok, sql} = PgDurable.to_sql(workflow)
# => "SELECT df.start('SELECT 1' ~> 'SELECT 2')"
```

`PgDurable.to_start_sql/1` is an alias for `to_sql/1`.

### Rendering Examples

**Simple sequence:**

```elixir
PgDurable.sql("SELECT 1")
|> PgDurable.then(PgDurable.sql("SELECT 2"))
|> PgDurable.to_expr()
# => {:ok, "'SELECT 1' ~> 'SELECT 2'"}
```

**Named result with reference:**

```elixir
PgDurable.named(PgDurable.sql("SELECT id FROM users LIMIT 10"), "users")
|> PgDurable.then(PgDurable.sql("SELECT * FROM orders WHERE user_id IN (SELECT id FROM $users.*)"))
|> PgDurable.to_expr()
# => {:ok, "'SELECT id FROM users LIMIT 10' |=> 'users' ~> 'SELECT * FROM orders WHERE user_id IN (SELECT id FROM $users.*)'"}
```

**Parallel join:**

```elixir
PgDurable.join(
  PgDurable.sql("SELECT 1 AS a"),
  PgDurable.sql("SELECT 2 AS b")
)
|> PgDurable.to_expr()
# => {:ok, "'SELECT 1 AS a' & 'SELECT 2 AS b'"}
```

**Conditional branch:**

```elixir
PgDurable.if_(
  PgDurable.sql("SELECT flag FROM config"),
  PgDurable.sql("SELECT 'yes'"),
  PgDurable.sql("SELECT 'no'")
)
|> PgDurable.to_expr()
# => {:ok, "'SELECT flag FROM config' ?> 'SELECT yes' !> 'SELECT no'"}
```

**Sleep and signal:**

```elixir
PgDurable.sleep(30)
|> PgDurable.to_expr()
# => {:ok, "df.sleep(30)"}

PgDurable.wait_for_signal("approval")
|> PgDurable.to_expr()
# => {:ok, "df.wait_for_signal('approval')"}
```

## Validating Workflows

Always validate before rendering to catch structural errors early:

```elixir
case PgDurable.validate(workflow) do
  :ok ->
    # Safe to render
    {:ok, sql} = PgDurable.to_sql(workflow)

  diagnostics ->
    # diagnostics is a list of PgDurable.Diagnostic structs
    Enum.each(diagnostics, fn diag ->
      IO.puts(PgDurable.Diagnostic.format(diag))
    end)
end
```

`PgDurable.validate/1` returns `:ok` or a plain list of `PgDurable.Diagnostic` structs (no `{:error, …}` tuple). It checks:

- Workflow name is identifier-like
- Workflow has a root node
- All node types are recognized
- Named result names are valid identifiers
- SQL nodes have non-empty SQL
- Sleep seconds are non-negative
- Signal names are non-empty
- No unknown node types

## Common Diagnostic Codes

All diagnostics are `PgDurable.Diagnostic` structs with `:code`, `:message`, and `:severity` fields. Format them with `PgDurable.Diagnostic.format/1`.

### Workflow-Level Errors

| Code | Severity | Meaning |
|------|----------|---------|
| `:invalid_workflow_name` | error | Workflow name must be identifier-like (`/^[a-zA-Z_][a-zA-Z0-9_]*$/`) |
| `:invalid_label` | error | Workflow label must be a non-empty string |
| `:missing_root` | error | Workflow has no root node |
| `:invalid_input` | error | Expected a Workflow struct |

### Node Errors

| Code | Severity | Meaning |
|------|----------|---------|
| `:unknown_node` | error | Unrecognized node type in the workflow tree |
| `:invalid_named_result` | error | Named result name is not identifier-like |
| `:invalid_if_condition` | error | If condition must be a non-empty SQL expression |
| `:invalid_sql_node` | error | SQL node has empty SQL |
| `:invalid_sleep` | error | Sleep seconds must be a non-negative number |
| `:invalid_signal` | error | Signal name must be non-empty |
| `:invalid_raw_expr` | error | Raw expression must be non-empty |
| `:forward_reference` | warning | Reference to a named result used before it is defined |
| `:duplicate_named_result` | warning | Same named result defined more than once |

### SQL Safety Errors

| Code | Severity | Meaning |
|------|----------|---------|
| `:null_byte` | error | SQL string or identifier contains a null byte |
| `:invalid_type` | error | Expected a specific type (string, atom) |
| `:invalid_float` | error | Float value is `NaN`, `Infinity`, or `-Infinity` |
| `:unsupported_type` | error | Cannot convert value to SQL literal |
| `:json_encode_error` | error | JSON encoding failed (e.g. invalid map value) |

### Reference Errors

| Code | Severity | Meaning |
|------|----------|---------|
| `:invalid_reference` | error | Expected a `PgDurable.Ref` struct |
| `:invalid_name` | error | Reference name is empty, contains null bytes, or has invalid characters |

## Troubleshooting

### "Cannot render node" error

The node type is not supported in v0.1. Use `PgDurable.raw_expr/1` as an escape hatch:

```elixir
# Instead of a typed builder for a deferred construct:
PgDurable.raw_expr("df.race(df.http('https://api.example.com'), df.sleep(5))")
```

See the [construct matrix](../compatibility/pg_durable_dsl_matrix.md) for supported vs deferred constructs.

### Forward reference warning

A `$name` reference appears before the `|=>` that defines it. pg_durable requires results to be captured before use. Reorder your workflow so named results come before their references.

### Duplicate named result warning

Two named results use the same name. Use unique names — pg_durable does not allow overwriting named results.

### Null byte in SQL

SQL strings and identifiers must not contain null bytes (`\0`). This is a PostgreSQL constraint enforced at the safety layer.

### Invalid identifier characters

Names must match `/^[a-zA-Z_][a-zA-Z0-9_]*$/`. This applies to workflow names, named results, references, and signal names.

## Running Integration Tests for Debugging

Integration tests require Docker or Podman and run against disposable PostgreSQL instances. **Never use your system PostgreSQL.**

```bash
# Start a fresh PG17 instance
docker compose -f docker/docker-compose.pg17.yml up -d

# Run all integration tests
PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration

# Run a specific test file
PG_DURABLE_INTEGRATION=1 mix test test/pg_durable/conformance_test.exs

# Run a single test by name
PG_DURABLE_INTEGRATION=1 mix test test/pg_durable/conformance_test.exs --only test_name

# Stop and cleanup
docker compose -f docker/docker-compose.pg17.yml down -v
```

For PG18:

```bash
docker compose -f docker/docker-compose.pg18.yml up -d
PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration
docker compose -f docker/docker-compose.pg18.yml down -v
```

Or use the atomic lifecycle scripts:

```bash
bin/test-integration-pg17.sh   # starts, runs, stops
bin/test-integration-pg18.sh
```
