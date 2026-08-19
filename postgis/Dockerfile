# calcofi-postgis: postgis/postgis:18-3.6 + pg_duckdb (DuckDB inside PostgreSQL), so the
# calcofi database can read the public release Parquet with read_parquet('https://…') and
# join it to ctd.* without leaving SQL (plan 2026-08-17 WS7 phase 2).
#
# pg_duckdb ships prebuilt in pgduckdb/pgduckdb:18-v1.1.1 (FROM postgres:18-bookworm). The
# postgis 18-3.6 image is trixie-based, so the extension's .so files (built against bookworm
# glibc 2.36 / the PG 18 ABI) are copied in — an older-glibc binary runs on a newer glibc, and
# the PostgreSQL extension ABI is stable within a major. Fallback if a future pair disagrees:
# build pg_duckdb from source in a builder stage on top of this base.
#
#   docker build -t calcofi-postgis:18-3.6-duckdb ./postgis
# Enable with `-c shared_preload_libraries=pg_stat_statements,pg_duckdb` (compose command:)
# and `CREATE EXTENSION pg_duckdb;` in the database. Roll back: image postgis/postgis:18-3.6
# and drop pg_duckdb from shared_preload_libraries (the extension objects stay inert).
FROM pgduckdb/pgduckdb:18-v1.1.1 AS pgduckdb
FROM postgis/postgis:18-3.6
RUN apt-get update -qq && apt-get install -y --no-install-recommends libcurl4 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=pgduckdb /usr/lib/postgresql/18/lib/pg_duckdb.so  /usr/lib/postgresql/18/lib/
COPY --from=pgduckdb /usr/lib/postgresql/18/lib/libduckdb.so  /usr/lib/postgresql/18/lib/
COPY --from=pgduckdb /usr/share/postgresql/18/extension/pg_duckdb* /usr/share/postgresql/18/extension/
