-- Create a read-only user for Grafana
CREATE USER grafana_reader WITH PASSWORD 'grafana_readonly_pass';

-- Grant connect permission to the database
GRANT CONNECT ON DATABASE main TO grafana_reader;

-- Grant usage on the public schema
GRANT USAGE ON SCHEMA public TO grafana_reader;

-- Grant select permissions on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_reader;

-- Grant select permissions on all future tables (for when new tables are created)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana_reader;

-- Grant usage on all sequences (needed for some queries)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO grafana_reader; 