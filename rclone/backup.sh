#!/bin/sh
# backup.sh — ship the local Postgres dump rotation to GCS.
#
# Runs INSIDE the rclone container (alpine/busybox + rclone) from /etc/crontabs/root
# at 00:30 UTC, after the pg_backups container has written the night's dump
# (SCHEDULE=@daily = 00:00 UTC; a 1 GB gz takes ~3 min).
#
# Source : /share/pg_backups/{daily,weekly,monthly,manual}   (postgres-backup-local rotation)
# Target : gs://calcofi-backups/postgres/...                 (private bucket, Object Versioning on,
#          noncurrent versions deleted after 90 d by lifecycle — so a `sync` delete here is
#          not a loss for three months; see scripts/setup_backup_bucket.sh)
# Auth   : the calcofi-admin service-account key mounted read-only at
#          /config/rclone/calcofi-admin-sa.json, via the [gcs-calcofi-sa] remote.
#
# History: until 2026-08-19 this synced to Google Drive (`remote:db_backups`), which had
# been failing every night since 2025-02-02 with "Drive storage quota has been exceeded"
# — the database had no off-site copy for 18 months. Do not point this back at Drive.
#
# What is deliberately NOT mirrored (the sync is an allow-list of daily/weekly/monthly):
#   last/**            hard links to the newest dump (BACKUP_KEEP_MINS) — a duplicate
#   *-latest.sql.gz    symlinks (rclone can't follow them without -L, which would upload
#                      a second full copy of each latest file)
#   _drill/**          the restore drill's scratch space
#   _status/**         written below, then copied up explicitly
#   manual/**          COPIED (step 2), not synced — deleting it locally must not delete it off-site
set -eu

SRC="/share/pg_backups"
DST="${BACKUP_GCS_REMOTE:-gcs-calcofi-sa:calcofi-backups/postgres}"
STATUS_DIR="$SRC/_status"
STATUS="$STATUS_DIR/last_success.json"
HOST="$(hostname 2>/dev/null || echo unknown)"

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
mkdir -p "$STATUS_DIR"

echo "[$(ts)] pg_backups: $SRC -> $DST"

# 1. MIRROR the rotation dirs only. Filter rules apply to both sides, so anything in the
#    bucket outside daily/weekly/monthly (manual/, legacy-*/, _status/) is invisible to
#    this sync and can never be deleted by it. (The first run, 2026-08-19, synced the whole
#    prefix and deleted legacy-2022/ and legacy-2024/ — recovered from noncurrent versions.
#    That is what the versioning is for, and why this is now an allow-list.)
rclone sync "$SRC" "$DST" \
  --exclude "*-latest.sql.gz" \
  --include "daily/**" --include "weekly/**" --include "monthly/**" \
  --exclude "*" \
  --skip-links --checksum --transfers 4 --checkers 8 \
  --stats 60s --stats-one-line -v

# 2. COPY (never delete) manual dumps: the local copy is deleted once it is off-site, to
#    keep the 200 GB disk free, and the bucket keeps it.
if [ -d "$SRC/manual" ]; then
  rclone copy "$SRC/manual" "$DST/manual" --skip-links --checksum --transfers 4 -v --stats-one-line
fi

# 3. pgAdmin's config db (users, shared servers) — small; bucket versioning keeps history
if [ -f /share/pgadmin/pgadmin4.db ]; then
  rclone copyto /share/pgadmin/pgadmin4.db "${DST%/postgres}/pgadmin/pgadmin4.db" -q && echo "[$(ts)] pgadmin4.db copied"
fi

# newest daily object per database, from the DESTINATION (what we actually have off-site)
latest="$(rclone lsf "$DST/daily/" --files-only 2>/dev/null | grep -v -- '-latest' | sort | tail -n 5 | tr '\n' ' ')"
size="$(rclone size "$DST" --json 2>/dev/null || echo '{"count":-1,"bytes":-1}')"

# one-line status record, also copied up so the off-site side is self-describing
printf '{"ok":true,"finished_at":"%s","host":"%s","dst":"%s","newest_daily":"%s","size":%s}\n' \
  "$(ts)" "$HOST" "$DST" "$latest" "$size" > "$STATUS"
rclone copyto "$STATUS" "$DST/_status/last_success.json" -q

echo "[$(ts)] done — $size ; newest daily: $latest"

# optional dead-man's switch (healthchecks.io or similar): set HEALTHCHECKS_URL in .env
if [ -n "${HEALTHCHECKS_URL:-}" ]; then
  wget -q -T 10 -O /dev/null "$HEALTHCHECKS_URL" 2>/dev/null || echo "[$(ts)] WARN heartbeat ping failed"
fi
