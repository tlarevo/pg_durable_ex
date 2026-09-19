# pg_durable DSL Compatibility Matrix

This document inventories every upstream pg_durable DSL construct and classifies its v0.1 support status in pg_durable_ex.

## Classification Legend

| Status | Meaning |
|--------|---------|
| **supported** | Typed Elixir builder + SQL renderer. First-class API, fully tested. |
| **rejected** | Structured diagnostic emitted; SQL never rendered. Design mismatch or anti-pattern. |
| **raw-pass-through** | Escape hatch via `PgDurable.Node.RawExpr`. Embed arbitrary pg_durable SQL; marked unsafe. |
| **deferred** | No typed builder. Diagnostic tells the user to use a raw expression. Candidate for v0.2+ based on user demand. |

---

## Graph Operators

| Construct | Syntax | Category | v0.1 Status | Notes |
|-----------|--------|----------|-------------|-------|
| Sequence | `~>` | graph operator | supported | Core sequencing |
| Named Result Capture | `\|=>` | graph operator | supported | Captures step result |
| Join | `&` | graph operator | supported | Two-way parallel join |
| Race | `\|` | graph operator | deferred | First-wins concurrency |
| Conditional then | `?>` | graph operator | supported | Basic if-then |
| Conditional else | `!>` | graph operator | supported | Basic if-else |
| Eternal loop | `@>` | graph operator | deferred | Infinite loop |

---

## Graph Functions

| Construct | Syntax | Category | v0.1 Status | Notes |
|-----------|--------|----------|-------------|-------|
| SQL node | raw SQL string | graph function | supported | Developer-authored SQL |
| Sleep | `df.sleep(seconds)` | graph function | supported | Timed pause |
| Wait for schedule | `df.wait_for_schedule(cron)` | graph function | deferred | Cron scheduling |
| HTTP | `df.http(url, method, body, headers, timeout)` | graph function | deferred | External HTTP |
| Join (function) | `df.join(a, b)` | graph function | supported | Equivalent to `&` |
| Join3 | `df.join3(a, b, c)` | graph function | deferred | Three-way join |
| Race (function) | `df.race(a, b)` | graph function | deferred | Equivalent to `\|\|` |
| If | `df.if(cond, then, else)` | graph function | supported | Conditional branch |
| If rows | `df.if_rows(name, then, else)` | graph function | deferred | Row-count conditional |
| Loop | `df.loop(body)` | graph function | deferred | Bounded loop |
| Loop with condition | `df.loop(body, cond)` | graph function | deferred | Conditional loop |
| Break | `df.break()` | graph function | deferred | Exit loop |
| Break with value | `df.break(value)` | graph function | deferred | Exit loop with value |
| Wait for signal | `df.wait_for_signal(name)` | graph function | supported | Block until signal |
| Wait for signal (timeout) | `df.wait_for_signal(name, timeout)` | graph function | supported | Signal with timeout |

---

## Result Substitution

| Construct | Syntax | Category | v0.1 Status | Notes |
|-----------|--------|----------|-------------|-------|
| Named result | `$name` | result substitution | supported | Reference prior result |
| Column access | `$name.column` | result substitution | supported | Specific column |
| Null-safe result | `$name?` | result substitution | deferred | Null-safe reference |
| Null-safe column | `$name.column?` | result substitution | deferred | Null-safe column |
| Row-set expansion | `$name.*` | result substitution | supported | Expand into VALUES |

---

## Control-Plane Functions

| Construct | Syntax | Category | v0.1 Status | Notes |
|-----------|--------|----------|-------------|-------|
| Start workflow | `df.start(func)` | control-plane | supported | Begin durable procedure |
| Start with label | `df.start(func, label)` | control-plane | supported | Named instance |
| Start with database | `df.start(func, label, database)` | control-plane | deferred | Multi-database |
| Get status | `df.status(id)` | control-plane | supported | Query instance state |
| Get result | `df.result(id)` | control-plane | supported | Completion result |
| Cancel | `df.cancel(id)` | control-plane | supported | Cancel instance |
| Cancel with reason | `df.cancel(id, reason)` | control-plane | supported | Cancel with explanation |
| Explain | `df.explain(input)` | control-plane | supported | Inspect workflow plan |
| List instances | `df.list_instances(...)` | control-plane | supported | Paginated listing |
| Signal | `df.signal(id, name, data)` | control-plane | supported | Send signal |
| Await instance | `df.await_instance(id)` | control-plane | deferred | Block until done |
| Await with timeout | `df.await_instance(id, timeout)` | control-plane | deferred | Await with deadline |
| Set variable | `df.setvar(name, value)` | control-plane | deferred | Workflow variable |
| Get variable | `df.getvar(name)` | control-plane | deferred | Read variable |
| Unset variable | `df.unsetvar(name)` | control-plane | deferred | Remove variable |
| Clear variables | `df.clearvars()` | control-plane | deferred | Remove all variables |

---

## Setup/Privilege Helpers

| Construct | Syntax | Category | v0.1 Status | Notes |
|-----------|--------|----------|-------------|-------|
| Grant usage | `df.grant_usage(role)` | setup helper | supported | Grant pg_durable access |

---

## Summary

| Status | Count |
|--------|-------|
| Supported | 22 |
| Deferred | 22 |
| Rejected | 0 |
| **Total** | **44** |

v0.1 support: 22 constructs fully implemented with typed Elixir builders and SQL renderers, 22 deferred to future versions, 0 rejected.

---

## v0.1 Classification Rationale

**Supported constructs** are the core primitives for basic orchestration: sequence, join, conditional branch, result capture/substitution, sleep, signal wait, SQL nodes, and the full control-plane lifecycle (start, status, result, cancel, explain, list, signal). These cover the viability gate — a developer can model and execute a real durable workflow with branching, parallelism, and external coordination.

**Deferred constructs** are not needed for initial viability. They fall into three groups:
- **Loop constructs** (eternal loop, bounded loop, conditional loop, break) — complex graph semantics requiring cycle detection and state machine translation
- **Advanced concurrency** (race, Join3) — first-wins and three-way join patterns needed for specific orchestration topologies
- **Ergonomic/advanced features** (null-safe substitution, cron scheduling, HTTP egress, workflow variables, instance await, multi-database) — valuable but not blocking for the core use case

**Rejected constructs:** none. Every upstream pg_durable DSL construct maps to a plausible Elixir API. The DSL is well-designed and there are no anti-patterns or design mismatches that warrant rejection.

---

## Raw Expression Escape Hatch

`PgDurable.Node.RawExpr` is the escape hatch for embedding arbitrary pg_durable SQL that has no typed builder yet.

```elixir
import PgDurable.Node.RawExpr

# Escape hatch for deferred constructs
"df.race(df.http('https://api.example.com'), df.sleep(5))"
|> raw_expr()
|> PgDurable.Graph.compile()
```

**Semantics:**
- RawExpr wraps a string of pg_durable SQL syntax and injects it verbatim into the rendered output
- The compiler treats it as opaque — no validation, no type-checking, no transformation
- The rendered SQL is syntactically valid pg_durable but pg_durable_ex cannot reason about its behavior

**Constraints — always mark raw expressions unsafe in documentation:**
- pg_durable_ex cannot validate the SQL at compile time
- The upstream syntax may change across pg_durable versions without warning
- Error messages from raw expressions will reference the raw SQL, not the Elixir source
- RawExpr bypasses the typed builder's guarantees about parameter safety and result capture

**When to use:**
- When a deferred construct blocks a real workflow
- When testing upstream features not yet modeled by the builder
- When the developer needs full control over the generated SQL

**When to avoid:**
- In library code that exposes a public API
- When a typed builder exists for the construct
- When the developer is unsure of the pg_durable SQL syntax
