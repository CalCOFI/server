#!/bin/bash
# pg_restore_drill.sh — prove that the OFF-SITE backup restores. Weekly, from root's crontab
# on the host (see README "Database backups"):
#   15 3 * * 0  /share/github/CalCOFI/server/scripts/pg_restore_drill.sh >> /share/logs/pg_restore_drill.log 2>&1
#
# For each database in DRILL_DBS it
#   1. fetches the NEWEST daily dump from GCS (not from the local rotation — the point is to
#      prove the copy we would actually reach for after losing the disk),
#   2. restores it into <db>_drill on the live server (`gunzip | psql`, the documented path),
#   3. compares table count + the three biggest tables' row counts with the live database,
#   4. drops <db>_drill and writes _status/last_drill.json (copied up to the bucket too).
# Disk: one restored copy of the largest DB + its gz (gis ≈ 6.5 GB + 1 GB); see D6 in the plan.
# Exit non-zero on any failure so the log line is loud; scripts/backup_status.sh turns the
# json into the status file upptime watches.
set -uo pipefail

REMOTE="${BACKUP_GCS_REMOTE:-gcs-calcofi-sa:calcofi-backups/postgres}"
DRILL_DBS="${DRILL_DBS:-gis}"          # space-separated; add calcofi once WS2 lands
WORK=/share/pg_backups/_drill
STATUS_DIR=/share/pg_backups/_status
STATUS="$STATUS_DIR/last_drill.json"
PGUSER=admin

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
psql_live()  { docker exec postgis psql -U "$PGUSER" -d "$1" -tAc "$2"; }
rc() { docker exec rclone rclone "$@"; }

mkdir -p "$WORK" "$STATUS_DIR"
overall_ok=true
results=""

for db in $DRILL_DBS; do
  t0=$(date +%s)
  echo "[$(ts)] drill $db: locate newest daily dump on $REMOTE/daily/"
  f=$(rc lsf "$REMOTE/daily/" --files-only 2>/dev/null | grep "^${db}-[0-9]\{8\}\.sql\.gz$" | sort | tail -1)
  if [ -z "$f" ]; then
    echo "[$(ts)] drill $db: FAIL no daily dump found off-site"; overall_ok=false
    results="$results{\"db\":\"$db\",\"ok\":false,\"error\":\"no off-site daily dump\"},"; continue
  fi
  rm -f "$WORK"/"${db}"-*.sql.gz
  rc copyto "$REMOTE/daily/$f" "$WORK/$f" -q || { echo "[$(ts)] drill $db: FAIL fetch $f"; overall_ok=false; results="$results{\"db\":\"$db\",\"ok\":false,\"error\":\"fetch failed\",\"file\":\"$f\"},"; continue; }
  bytes=$(stat -c %s "$WORK/$f")

  echo "[$(ts)] drill $db: restore $f ($bytes bytes) into ${db}_drill"
  psql_live postgres "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db}_drill' AND pid<>pg_backend_pid();" >/dev/null 2>&1
  psql_live postgres "DROP DATABASE IF EXISTS ${db}_drill;" >/dev/null
  psql_live postgres "CREATE DATABASE ${db}_drill;" >/dev/null
  gunzip -c "$WORK/$f" | docker exec -i postgis psql -U "$PGUSER" -d "${db}_drill" -q -v ON_ERROR_STOP=0 > "$WORK/$db.restore.log" 2>&1
  n_err=$(grep -c "^ERROR" "$WORK/$db.restore.log" || true)

  # compare: table counts + row counts of the three largest live tables
  q_tables="SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')"
  nt_live=$(psql_live "$db" "$q_tables"); nt_drill=$(psql_live "${db}_drill" "$q_tables")
  cmp=""; rows_ok=true
  for rel in $(psql_live "$db" "SELECT schemaname||'.'||relname FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 3"); do
    a=$(psql_live "$db" "SELECT count(*) FROM $rel"); b=$(psql_live "${db}_drill" "SELECT count(*) FROM $rel" 2>/dev/null || echo -1)
    [ "$a" = "$b" ] || rows_ok=false
    cmp="$cmp{\"table\":\"$rel\",\"live\":$a,\"drill\":$b},"
  done
  size_drill=$(psql_live postgres "SELECT pg_database_size('${db}_drill')")
  psql_live postgres "DROP DATABASE IF EXISTS ${db}_drill;" >/dev/null
  rm -f "$WORK/$f"

  ok=true; [ "$n_err" -eq 0 ] && [ "$nt_live" = "$nt_drill" ] || ok=false
  # row counts can legitimately drift between last night's dump and now; report, don't fail
  $ok || overall_ok=false
  secs=$(( $(date +%s) - t0 ))
  echo "[$(ts)] drill $db: ok=$ok errors=$n_err tables live=$nt_live drill=$nt_drill rows_match=$rows_ok size=$size_drill ${secs}s"
  results="$results{\"db\":\"$db\",\"ok\":$ok,\"file\":\"$f\",\"bytes\":$bytes,\"restore_errors\":$n_err,\"tables_live\":$nt_live,\"tables_drill\":$nt_drill,\"rows_match\":$rows_ok,\"rows\":[${cmp%,}],\"restored_size\":$size_drill,\"seconds\":$secs},"
done

printf '{"ok":%s,"finished_at":"%s","remote":"%s","databases":[%s]}\n' "$overall_ok" "$(ts)" "$REMOTE" "${results%,}" > "$STATUS"
rc copyto "$STATUS" "$REMOTE/_status/last_drill.json" -q || true
echo "[$(ts)] drill overall ok=$overall_ok -> $STATUS"
$overall_ok
