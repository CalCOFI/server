-- 50_release_views.sql — the public DuckDB release, readable from inside PostgreSQL via pg_duckdb.
--   docker exec -i postgis psql -U admin -d calcofi -v ON_ERROR_STOP=1 -f /share/github/CalCOFI/server/postgis/init/50_release_views.sql
-- Requires the calcofi-postgis:18-3.6-duckdb image, shared_preload_libraries=…,pg_duckdb and
-- duckdb.postgres_role=calcofi_reader (compose). read_parquet() over https needs no credentials
-- (the bucket is public). The release VERSION is pinned below — re-run after a new release is
-- promoted (scripts/deploy_consumers.sh in CalCOFI/workflows does this as its release-views step). Views are small tables only; for the big ones
-- (obs, sample) query read_parquet() directly with a WHERE on the hive partition, or use DuckDB
-- on your laptop (calcofi4r::cc_get_db() + cc_pg_attach()).
CREATE EXTENSION IF NOT EXISTS pg_duckdb;
SELECT duckdb.install_extension('httpfs');

CREATE SCHEMA IF NOT EXISTS release AUTHORIZATION calcofi_admin;
GRANT USAGE ON SCHEMA release TO calcofi_reader;
SET ROLE calcofi_admin;

DROP VIEW IF EXISTS release.cruise;
CREATE VIEW release.cruise AS
  SELECT r['cruise_key']::text AS cruise_key, r['date_ym']::date AS date_ym, r['ship_key']::text AS ship_key,
         r['ship_name']::text AS ship_name, r['ship_nodc']::text AS ship_nodc, r['year']::int AS year, r['month']::int AS month,
         r['ichthyo']::bigint AS ichthyo, r['bottle']::bigint AS bottle, r['ctd_cast']::bigint AS ctd_cast, r['dic']::bigint AS dic
  FROM read_parquet('https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.14/parquet/cruise.parquet') r;
COMMENT ON VIEW release.cruise IS 'Release v2026.08.14 cruise table, read live from the public Parquet via pg_duckdb.';

DROP VIEW IF EXISTS release.ship;
CREATE VIEW release.ship AS
  SELECT r['ship_key']::text AS ship_key, r['ship_name']::text AS ship_name, r['ship_nodc']::text AS ship_nodc
  FROM read_parquet('https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.14/parquet/ship.parquet') r;

DROP VIEW IF EXISTS release.dataset;
CREATE VIEW release.dataset AS
  SELECT r['dataset_key']::text AS dataset_key, r['dataset_name']::text AS dataset_name, r['provider']::text AS provider,
         r['category']::text AS category, r['coverage_temporal']::text AS coverage_temporal,
         r['coverage_spatial']::text AS coverage_spatial, r['link_calcofi_org']::text AS link_calcofi_org
  FROM read_parquet('https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.14/parquet/dataset.parquet') r;

GRANT SELECT ON ALL TABLES IN SCHEMA release TO calcofi_reader;
RESET ROLE;
