# pg_flag_snapshot.R — called by pg_flag_snapshot.sh inside the rstudio container.
# Exports the CTD QC ledger from PostgreSQL to Parquet under /share/data/ctd/exports/qc/.
suppressPackageStartupMessages(library(DBI))
out <- "/share/data/ctd/exports/qc"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(duckdb::duckdb())
dbExecute(con, "INSTALL postgres; LOAD postgres;")
dbExecute(con, "ATTACH 'dbname=calcofi host=postgis port=5432 user=bebest' AS pg (TYPE postgres, READ_ONLY)")
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
dbExecute(con, sprintf(
  "COPY (%s WHERE f.status = 'accepted' ORDER BY f.flag_id) TO '%s/flag_accepted.parquet' (FORMAT parquet, COMPRESSION zstd)", sel, out))
dbExecute(con, sprintf(
  "COPY (%s ORDER BY f.flag_id) TO '%s/flag_ledger.parquet' (FORMAT parquet, COMPRESSION zstd)", sel, out))
n <- dbGetQuery(con, "SELECT count(*) FILTER (WHERE status = 'accepted') AS accepted, count(*) AS total FROM pg.ctd.flag")
writeLines(sprintf('{"exported_at":"%s","accepted":%d,"total":%d}',
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), n$accepted, n$total),
  file.path(out, "flag_meta.json"))
cat("accepted:", n$accepted, " total:", n$total, "\n")
