-- Check if pg_durable background worker is ready
-- Returns true if the worker is initialized
SELECT * FROM pg_stat_activity WHERE backend_type = 'pg_durable worker';
