# Changelog

All notable changes to pg_durable_ex will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Core workflow AST with 8 node types
- Typed result references ($name, $name.column, $name.*)
- SQL safety layer (quoting, literals, identifiers)
- Workflow renderer (to_expr, to_sql, to_start_sql)
- Public facade API on PgDurable module
- Semantic validation with structured diagnostics
- Integration harness for PG17/PG18
- Conformance tests against real pg_durable v0.2.7
- Adversarial SQL safety tests
- DSL compatibility matrix (44 constructs)
