-- pg_durable extension is pre-installed in the official Docker image.
-- This script only needs to grant usage if a non-superuser test role is used.
-- The official image uses the postgres superuser, so grant_usage is optional
-- for superuser connections but included for completeness.

-- Uncomment if using a non-superuser role:
-- SELECT df.grant_usage('your_app_role');
