# SQL Safety Layer — Trust Model

## Trust Categories

pg_durable_ex classifies all SQL content into five trust categories:

1. **Library-generated identifiers** — CTE names, column aliases, and result references produced internally by the compiler. Fully trusted; quoted via `quote_identifier/1`.

2. **Developer-authored SQL** — Raw SQL fragments provided by the library user in node definitions. Quoted as string literals via `embed_node_sql/1`, but the developer is responsible for correctness. This is the primary escape hatch.

3. **Typed references** — Struct references (`Ref.Result`, `Ref.Column`, `Ref.RowSet`) created via the `PgDurable.Ref` API. Rendered to safe `$name` tokens by `SQL.Reference.render/1`. Names validated against `^[a-zA-Z_][a-zA-Z0-9_]*$`.

4. **User-supplied literals** — Values from application code converted to SQL via `quote_literal/1`. Each type is handled specifically: strings escaped, numbers formatted, booleans mapped, timestamps cast, complex types JSON-encoded.

5. **External/untrusted input** — Never passed to the SQL safety layer. Application code must never forward raw user input into SQL; use parameterized queries or the `quote_literal/1` layer at minimum.

## Code vs Data

- **Code** is SQL syntax: keywords, expressions, function calls, JOIN clauses. This is what developers write in node definitions. The library does not attempt to parse or validate code — it is the developer's responsibility.
- **Data** is values: strings, numbers, booleans, dates, identifiers. This is what the safety layer quotes and validates.

The boundary is clear: if it looks like SQL, it's code. If it's a value that gets interpolated into SQL, it's data.

## Escape Hatches

Raw SQL expressions in node definitions are escape hatches. The library quotes them as string literals but cannot verify their correctness. Developers must:

- Ensure syntax is valid PostgreSQL
- Avoid constructing SQL from untrusted input
- Use typed references for cross-node data flow instead of raw SQL

## Result References vs User Strings

Result references (`$name`, `$name.column`, `$name.*`) are not user strings. They are:

1. Created via the typed `PgDurable.Ref` API
2. Validated against a strict identifier regex
3. Rendered to safe SQL tokens that PostgreSQL interprets as result-set references

User strings pass through `quote_sql_string/1` which wraps them in single quotes. References never touch the quoting layer — they are a distinct, safer path.

## String-Literal Quoting Strategy

All string literals use PostgreSQL **escape string syntax** (`E'...'`). This makes quoting deterministic regardless of the `standard_conforming_strings` GUC setting:

- Single quotes are doubled (`''`).
- Backslashes are doubled (`\\` → literal backslash).
- This is safe under both `standard_conforming_strings=on` (PG ≥ 9.1 default) and `=off`.

The `E'...'` prefix tells PostgreSQL to always interpret backslash escapes, so the quoted form produces the same parsed value regardless of session-level GUC.

## Library Guarantees

1. **Null bytes are rejected** at every quoting entry point.
2. **SQL injection via string values is prevented** by escaping single quotes (`''`) and backslashes (`\\`) within `E'...'` literals.
3. **Identifier injection is prevented** by double-quote escaping.
4. **Type mismatches are rejected** — `quote_literal/1` returns an error for unrecognized types instead of producing dangerous output.
5. **All SQL produced by the library is inspectable** — functions return `{:ok, sql}` tuples, never silently inject SQL into connections.
