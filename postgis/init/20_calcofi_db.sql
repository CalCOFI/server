-- 20_calcofi_db.sql — create the `calcofi` database (run against `postgres`, as admin).
-- Idempotent. Schemas/privileges live in 30_calcofi_schemas.sql (run INSIDE calcofi).
SELECT 'CREATE DATABASE calcofi OWNER calcofi_admin ENCODING ''UTF8'''
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'calcofi') \gexec
REVOKE ALL ON DATABASE calcofi FROM PUBLIC;
GRANT CONNECT, TEMP ON DATABASE calcofi TO calcofi_reader;
ALTER DATABASE calcofi SET search_path = "$user", work, ctd, public;
ALTER DATABASE calcofi SET timezone = 'UTC';
