-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- pg_cron is enabled at the database level, not via migration
-- CREATE EXTENSION IF NOT EXISTS "pg_cron";
