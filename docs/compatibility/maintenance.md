# Upstream Compatibility Maintenance

## Process

When a new pg_durable version is released:

1. Check the upstream CHANGELOG for breaking changes
2. Update the pinned version in:
   - docker/docker-compose.pg17.yml
   - docker/docker-compose.pg18.yml
   - docs/compatibility/version_policy.md
   - mix.exs (if version constraint changes)
3. Run the conformance test suite against the new version
4. Update the DSL matrix with any new/changed constructs
5. Update this document

## Automated Drift Detection

The CI integration lanes test against the pinned version. A scheduled upstream/main lane (when implemented) will detect breaking changes early.

## Version Bumping

- Patch: non-breaking upstream additions
- Minor: new supported constructs or changed semantics
- Major: breaking changes in upstream that require pg_durable_ex changes

## Contact

Report compatibility issues at https://github.com/tlarevo/pg_durable_ex/issues
