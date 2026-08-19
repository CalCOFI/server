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

docker exec -u bebest rstudio Rscript -e '
  suppressPackageStartupMessages(library(DBI))
  con <- dbConnect(duckdb::duckdb())
  dbExecute(con, "INSTALL postgres; LOAD postgres;")
  dbExecute(con, "ATTACH \"dbname=calcofi host=postgis port=5432 user=bebest\" AS pg (TYPE postgres, READ_ONLY)")
  sel <- "
    SELECT f.flag_id, fi.archive, fi.path, fi.study, fi.cruise_key, fi.data_stage, fi.cast_dir,
           s.row_num, s.cast_id, s.depth, s.date_time_utc,
           f.variable, f.qual_code, q.label AS qual_label, q.is_bad,
           f.proposed_value, f.rule_key, f.reason, f.status,
           f.created_by, f.created_at, f.reviewed_by, f.reviewed_at, f.review_note
    FROM pg.ctd.flag f
    JOIN pg.ctd.qual_code q USING (qual_code)
    JOIN pg.ctd.file fi ON fi.file_id = f.file_id
    LEFT JOIN pg.ctd.scan s ON s.scan_id = f.scan_id"
  dbExecute(con, sprintf("COPY (%s WHERE f.status = \"accepted\" ORDER BY f.flag_id) TO \"/share/data/ctd/exports/qc/flag_accepted.parquet\" (FORMAT parquet, COMPRESSION zstd)", sel))
  dbExecute(con, sprintf("COPY (%s ORDER BY f.flag_id) TO \"/share/data/ctd/exports/qc/flag_ledger.parquet\" (FORMAT parquet, COMPRESSION zstd)", sel))
  n <- dbGetQuery(con, "SELECT count(*) FILTER (WHERE status = \"accepted\") AS accepted, count(*) AS total FROM pg.ctd.flag")
  writeLines(sprintf("{\"exported_at\":\"%s\",\"accepted\":%d,\"total\":%d}",
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), n$accepted, n$total),
    "/share/data/ctd/exports/qc/flag_meta.json")
  cat("accepted:", n$accepted, " total:", n$total, "\n")
'
docker exec rclone rclone copy /share/data/ctd/exports/qc "$DST" --checksum -q
echo "[$(date -u +%FT%TZ)] flag snapshot -> $DST ($(cat $OUT/flag_meta.json))"
