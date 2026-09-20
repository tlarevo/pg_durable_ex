ExUnit.start()

# Exclude integration tests by default; override with:
#   PG_DURABLE_INTEGRATION=1 mix test --include pg_durable_integration
ExUnit.configure(exclude: [:pg_durable_integration, :pg_durable_public_api_integration])
