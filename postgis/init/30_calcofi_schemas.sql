-- 30_calcofi_schemas.sql — extensions, schemas and default privileges INSIDE `calcofi`.
--   docker exec -i postgis psql -U admin -d calcofi -f /share/github/CalCOFI/server/postgis/init/30_calcofi_schemas.sql
-- Idempotent. The CTD tables themselves (ctd.file/scan/cast/flag…) come in 40_ctd.sql (WS8).
--
--   ctd     curated: immutable originals + flag ledger + derived products; owner calcofi_admin
--   work    shared scratch: every writer may CREATE; objects readable by all readers
--   public  left empty (PG15+ already revokes CREATE from PUBLIC)
-- Personal schemas ("$user") are created per person by scripts/add_user.sh.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE SCHEMA IF NOT EXISTS ctd  AUTHORIZATION calcofi_admin;
CREATE SCHEMA IF NOT EXISTS work AUTHORIZATION calcofi_admin;

GRANT USAGE  ON SCHEMA ctd, work, public TO calcofi_reader;
GRANT CREATE ON SCHEMA work              TO calcofi_writer;

-- objects the admin role creates: readable by readers (ctd), read/write by writers (work)
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA ctd  GRANT SELECT ON TABLES    TO calcofi_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA ctd  GRANT SELECT ON SEQUENCES TO calcofi_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA ctd  GRANT EXECUTE ON FUNCTIONS TO calcofi_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA work GRANT SELECT ON TABLES    TO calcofi_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA work GRANT ALL    ON TABLES    TO calcofi_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE calcofi_admin IN SCHEMA work GRANT ALL    ON SEQUENCES TO calcofi_writer;
-- existing objects (re-runs)
GRANT SELECT ON ALL TABLES IN SCHEMA ctd TO calcofi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA work TO calcofi_reader;
GRANT ALL    ON ALL TABLES IN SCHEMA work TO calcofi_writer;
-- PostGIS tables in public
GRANT SELECT ON public.spatial_ref_sys, public.geometry_columns, public.geography_columns TO calcofi_reader;
