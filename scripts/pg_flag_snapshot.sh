#!/bin/bash
# pg_flag_snapshot.sh — publish the CTD QC ledger as Parquet on GCS, nightly.
# Host root cron (see README "Database backups" cron block):
#   20 1 * * * /share/github/CalCOFI/server/scripts/pg_flag_snapshot.sh >> /share/logs/pg_flag_snapshot.log 2>&1
#
# This is the PG -> DuckDB half of the round trip (plan 2026-08-17, WS7): the team flags and
# fixes in PostgreSQL (ctd.flag); this exports
#   flag_accepted.parquet  ACCEPTED flags joined to their file/scan identity (archive, path,
#                          row_num, cast_id, depth, datetime, cruise_key) — everything
#                          ingest_calcofi_ctd-cast.qmd needs to apply them as measurement_qual
#                          WITHOUT a live PG connection during a pipeline run
#   flag_ledger.parquet    the whole ledger (all statuses), for transparency/analysis
#   flag_meta.json         counts + export time
# to gs://calcofi-db/qc/ctd/ (public bucket — the flags are as public as the data they grade).
# Runs the export inside the rstudio container (R + duckdb + postgres ext; reaches postgis by
# name, auth via /home/bebest/.pgpass), ships with the rclone container's SA remote.
set -euo pipefail
OUT=/share/data/ctd/exports/qc
DST=gcs-calcofi-sa:calcofi-db/qc/ctd
mkdir -p "$OUT"

docker exec -u bebest rstudio Rscript /share/github/CalCOFI/server/scripts/pg_flag_snapshot.R
docker exec rclone rclone copy /share/data/ctd/exports/qc "$DST" --checksum -q
echo "[$(date -u +%FT%TZ)] flag snapshot -> $DST ($(cat $OUT/flag_meta.json))"
