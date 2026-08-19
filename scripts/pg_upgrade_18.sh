#!/bin/bash
# pg_upgrade_18.sh — PostgreSQL 17.1/PostGIS 3.5 → 18/PostGIS 3.6 by dump/restore, fixing the
# anonymous-volume layout on the way. Ran 2026-08-19 (plan "CTD team PostgreSQL", WS2).
# Detached, from the server repo checkout, by a user in the docker group:
#   nohup /share/github/CalCOFI/server/scripts/pg_upgrade_18.sh >/dev/null 2>&1 &
#   tail -f /share/logs/pg_upgrade_18.log        # ends with "== DONE" or "FATAL"
#
# Phases (each echoes; FATAL stops before anything destructive happens):
#   0 preflight   old server up, new images pulled, compose file already on the 18 image
#   1 dump        FRESH dumps with the NEW pg_dump (18) against the OLD server (17):
#                 globals.sql + gis.dump (-Fc) + table/row baseline → /share/pg_backups/manual/<date>-pre18/
#                 → copied to gs://calcofi-backups/postgres/manual/ and verified BEFORE step 2
#   2 swap        stop dependents, REMOVE the old postgis container (its anonymous PGDATA volume
#                 is kept, name recorded in the log), `compose up -d postgis` on the 18 image
#                 → initdb into the NAMED volume (PGDATA /var/lib/postgresql/18/docker)
#   3 restore     globals, then gis from the -Fc dump (pg_restore -j4); compare against baseline
#   4 calcofi     roles + database + schemas from postgis/init/*.sql
#   5 dependents  pg_backups (18 image), pg_tileserv, plumber, pgadmin back up; endpoint checks
# Rollback (any phase ≥2): `docker compose stop postgis`, edit compose back to 17-3.5, recreate
# the container with `-v <anon-volume>:/var/lib/postgresql/data` — or restore the -Fc dump into
# any 17/18 server. The disk snapshots from earlier today are the last resort.
set -uo pipefail
REPO=/share/github/CalCOFI/server
LOG=/share/logs/pg_upgrade_18.log
MARK=/share/logs/pg_upgrade_18.DONE
NEW_IMG=postgis/postgis:18-3.6
STAMP=$(date -u +%Y-%m-%d)-pre18
DUMP_DIR=/share/pg_backups/manual/$STAMP
REMOTE=gcs-calcofi-sa:calcofi-backups/postgres/manual/$STAMP
NET=server_default
PGPASS=$(sudo grep -E '^PASSWORD=' $REPO/.env | cut -d= -f2-)
exec >>"$LOG" 2>&1
rm -f "$MARK"
step()  { echo; echo "== [$(date -u +%FT%TZ)] $*"; }
fatal() { echo "FATAL: $*"; exit 1; }
psql_old() { docker exec postgis psql -U admin -d "$1" -tAc "$2"; }

step "phase 0: preflight"
cd $REPO || fatal "repo missing"
docker ps --format '{{.Names}} {{.Image}}' | grep -q '^postgis postgis/postgis:17-3.5$' || fatal "old postgis container not running on 17-3.5"
grep -q "image: $NEW_IMG" docker-compose.yml || fatal "compose does not reference $NEW_IMG (git pull?)"
[ -n "$PGPASS" ] || fatal "PASSWORD not readable from .env"
docker pull -q $NEW_IMG && docker pull -q prodrigestivill/postgres-backup-local:18 || fatal "image pull"
docker network inspect $NET >/dev/null || fatal "network $NET missing"
ANON=$(docker inspect postgis --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')
echo "old PGDATA anonymous volume: ${ANON:-<none>}"
df -h /ssd | tail -1
sudo mkdir -p "$DUMP_DIR"

step "phase 1: fresh dumps with pg_dump 18 against the 17 server + baseline"
docker run --rm --network $NET -e PGPASSWORD="$PGPASS" $NEW_IMG pg_dumpall -h postgis -U admin --globals-only \
  | sudo tee "$DUMP_DIR/globals.sql" >/dev/null || fatal "globals dump"
docker run --rm --network $NET -e PGPASSWORD="$PGPASS" $NEW_IMG pg_dump -h postgis -U admin -Fc gis \
  | sudo tee "$DUMP_DIR/gis.dump" >/dev/null || fatal "gis dump"
# baseline: table list + exact row counts of the 20 largest tables, postgis version
psql_old gis "SELECT table_schema||'.'||table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema') ORDER BY 1" | sudo tee "$DUMP_DIR/tables.txt" >/dev/null
for rel in $(psql_old gis "SELECT schemaname||'.'||relname FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 20"); do
  echo "$rel $(psql_old gis "SELECT count(*) FROM $rel")"; done | sudo tee "$DUMP_DIR/rowcounts.txt" >/dev/null
psql_old gis "SELECT postgis_full_version()" | sudo tee "$DUMP_DIR/postgis_version_old.txt" >/dev/null
sudo sh -c "cd $DUMP_DIR && md5sum globals.sql gis.dump > MD5SUMS.txt && chmod -R a+r ."
ls -la "$DUMP_DIR"
docker exec rclone rclone copy "$DUMP_DIR" "$REMOTE" --checksum -q || fatal "off-site copy"
docker exec rclone rclone check "$DUMP_DIR" "$REMOTE" 2>&1 | grep -q "0 differences" || fatal "off-site copy differs"
echo "off-site copy verified at $REMOTE"
[ -s "$DUMP_DIR/gis.dump" ] && [ $(stat -c %s "$DUMP_DIR/gis.dump") -gt 500000000 ] || fatal "gis.dump suspiciously small"

step "phase 2: swap the server"
docker compose stop pg_backups pg_tileserv plumber pgadmin postgis || fatal "stop"
docker compose rm -f postgis || fatal "rm old container"     # anonymous volume $ANON survives
docker volume inspect "$ANON" >/dev/null 2>&1 && echo "anonymous volume $ANON still present (good)" || echo "WARN: anonymous volume not found"
docker compose up -d postgis || fatal "up postgis"
for i in $(seq 1 60); do docker exec postgis pg_isready -U admin -d gis >/dev/null 2>&1 && break; sleep 3; done
docker exec postgis pg_isready -U admin -d gis || fatal "new server not ready"
docker exec postgis psql -U admin -d gis -tAc "SELECT version()"
docker exec postgis psql -U admin -d gis -tAc "SHOW data_directory"
docker inspect postgis --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{println}}{{end}}'

step "phase 3: restore globals + gis"
docker exec postgis psql -U admin -d postgres -q -f "$DUMP_DIR/globals.sql" 2>&1 | grep -v "already exists" | head -20
docker exec postgis psql -U admin -d postgres -c "DROP DATABASE IF EXISTS gis;" && docker exec postgis psql -U admin -d postgres -c "CREATE DATABASE gis OWNER admin;" || fatal "recreate gis"
docker exec postgis pg_restore -U admin -d gis -j 4 "$DUMP_DIR/gis.dump" > /tmp/pg_restore_gis.log 2>&1 || true
docker exec postgis sh -c 'true'
sudo cp /tmp/pg_restore_gis.log "$DUMP_DIR/pg_restore_gis.log" 2>/dev/null || true
n_err=$(grep -c "pg_restore: error" /tmp/pg_restore_gis.log || true); echo "pg_restore errors: $n_err"; grep "pg_restore: error" /tmp/pg_restore_gis.log | head -20
docker exec postgis psql -U admin -d gis -c "ANALYZE;" >/dev/null
docker exec postgis psql -U admin -d gis -tAc "SELECT table_schema||'.'||table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema') ORDER BY 1" > /tmp/tables_new.txt
diff <(sudo cat "$DUMP_DIR/tables.txt") /tmp/tables_new.txt && echo "table list: identical ($(wc -l < /tmp/tables_new.txt))" || echo "WARN: table list differs (see above)"
bad=0
while read rel n; do m=$(docker exec postgis psql -U admin -d gis -tAc "SELECT count(*) FROM $rel" 2>/dev/null || echo -1); [ "$n" = "$m" ] || { echo "ROWCOUNT MISMATCH $rel old=$n new=$m"; bad=1; }; done < <(sudo cat "$DUMP_DIR/rowcounts.txt")
[ $bad -eq 0 ] && echo "row counts: all 20 largest tables match" || echo "WARN: row count mismatches above"
docker exec postgis psql -U admin -d gis -tAc "SELECT postgis_full_version()"
docker exec postgis psql -U admin -d gis -tAc "SELECT extname||' '||extversion FROM pg_extension ORDER BY 1"
docker exec postgis psql -U admin -d postgres -tAc "SELECT rolname||' super='||rolsuper||' login='||rolcanlogin FROM pg_roles WHERE rolname NOT LIKE 'pg\_%' ORDER BY 1"

step "phase 4: calcofi database, roles, schemas"
docker exec postgis psql -U admin -d postgres -v ON_ERROR_STOP=1 -f $REPO/postgis/init/10_roles.sql || fatal "roles"
docker exec postgis psql -U admin -d postgres -v ON_ERROR_STOP=1 -f $REPO/postgis/init/20_calcofi_db.sql || fatal "calcofi db"
docker exec postgis psql -U admin -d calcofi  -v ON_ERROR_STOP=1 -f $REPO/postgis/init/30_calcofi_schemas.sql || fatal "calcofi schemas"
docker exec postgis psql -U admin -d calcofi -tAc "SELECT nspname FROM pg_namespace WHERE nspname IN ('ctd','work')"
docker exec postgis psql -U admin -d postgres -tAc "SELECT datname||' '||pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY 1"

step "phase 5: dependents back up"
docker compose up -d pg_backups pg_tileserv plumber pgadmin || fatal "dependents"
sleep 15
docker ps --format '{{.Names}} {{.Image}} {{.Status}}' | grep -E "postgis|pg_backups|tileserv|plumber|pgadmin"
for u in https://tile.calcofi.io/ https://api.calcofi.io/ https://pgadmin.calcofi.io/login; do printf "%-40s %s\n" $u "$(curl -s -o /dev/null -m 30 -w '%{http_code}' $u)"; done
docker exec postgis psql -U admin -d gis -tAc "SHOW shared_buffers" | sed 's/^/shared_buffers=/'
# the empty 'data' dir the 17-era mount left inside the named volume — remove so nobody wonders
docker exec postgis sh -c '[ -d /var/lib/postgresql/data ] && [ -z "$(ls -A /var/lib/postgresql/data)" ] && rmdir /var/lib/postgresql/data && echo "removed stale empty /var/lib/postgresql/data" || true'
echo "old anonymous volume kept for rollback: ${ANON:-<none>}  (remove later: docker volume rm $ANON)"
echo "== DONE $(date -u +%FT%TZ)"
touch "$MARK"
