# pg_durable_ex Core Alpha Release Gate

## Criteria

Before declaring alpha, ALL of the following must be true:

### Test Evidence

- [ ] Unit test suite passes (`mix test`)
- [ ] Integration tests pass against PG17 with pg_durable v0.2.7
- [ ] Integration tests pass against PG18 with pg_durable v0.2.7
- [ ] Adversarial SQL safety tests pass
- [ ] Conformance tests cover all v0.1-supported constructs

### Documentation

- [ ] README.md is complete with public API examples
- [ ] Version policy documented
- [ ] DSL compatibility matrix is evidence-backed
- [ ] SQL safety documentation exists
- [ ] Integration test contract documented
- [ ] SQL inspection/debugging guide exists
- [ ] Alpha gate document exists (this file)

### Code Quality

- [ ] `mix format --check-formatted` passes
- [ ] `mix compile --warnings-as-errors` passes
- [ ] No TODO/FIXME in production code (test code OK)
- [ ] Diagnostic-first error handling throughout
- [ ] No generic `ArgumentError` in public API

### Release Artifacts

- [ ] `mix.exs` has correct version, description, licenses
- [ ] `.formatter.exs` covers all source files
- [ ] `.gitignore` excludes build artifacts
- [ ] LICENSE file exists (or explicit TODO)

## Known Limitations (Alpha)

- pg_durable is upstream Preview — not production-ready
- No Hex package published yet (install via git)
- No Ecto/Oban/Ash adapters (separate projects)
- `race`, `loop`, `break`, HTTP constructs are deferred
- Null-safe references (`$name?`, `$name.column?`) are deferred
- No ARM64 Docker images (amd64 only via emulation)

## What Alpha Is NOT

- Not a stable API guarantee
- Not production-ready
- Not a complete pg_durable feature coverage
- Not an endorsement of pg_durable for production use
