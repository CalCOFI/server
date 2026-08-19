#!/bin/bash
# backup_status.sh — turn the backup + drill status records into something a monitor can
# watch. Hourly from root's crontab on the host:
#   7 * * * *  /share/github/CalCOFI/server/scripts/backup_status.sh
#
# Writes /share/public/status/pg_backup.json (always) and creates/removes
# /share/public/status/pg_backup.ok, which Caddy serves at
#   https://file.calcofi.io/status/pg_backup.ok   -> 200 healthy / 404 stale
# so the CalCOFI/uptime (upptime) check `db-backup` goes red when the nightly GCS ship
# is > MAX_BACKUP_AGE_H old or the weekly restore drill is > MAX_DRILL_AGE_D old (or failed).
# No secrets in either file. This is the checker that has to exist independently of the
# backup job — if the job never runs, nothing else would remove the ok file.
set -u
MAX_BACKUP_AGE_H="${MAX_BACKUP_AGE_H:-36}"
MAX_DRILL_AGE_D="${MAX_DRILL_AGE_D:-10}"
S=/share/pg_backups/_status
OUT=/share/public/status
mkdir -p "$OUT"
now=$(date +%s)
age_h() { [ -f "$1" ] && echo $(( (now - $(stat -c %Y "$1")) / 3600 )) || echo 999999; }
ok_field() { [ -f "$1" ] && grep -q '"ok":true' "$1" && echo true || echo false; }

b_age=$(age_h "$S/last_success.json"); b_ok=$(ok_field "$S/last_success.json")
d_age=$(age_h "$S/last_drill.json");   d_ok=$(ok_field "$S/last_drill.json")
d_age_d=$(( d_age / 24 ))

healthy=true; reason=""
[ "$b_ok" = true ] && [ "$b_age" -le "$MAX_BACKUP_AGE_H" ] || { healthy=false; reason="backup age ${b_age}h ok=$b_ok; "; }
# the drill counts once it has ever run; before the first run only the backup gates health
if [ -f "$S/last_drill.json" ]; then
  [ "$d_ok" = true ] && [ "$d_age_d" -le "$MAX_DRILL_AGE_D" ] || { healthy=false; reason="${reason}drill age ${d_age_d}d ok=$d_ok"; }
fi

printf '{"healthy":%s,"checked_at":"%s","backup":{"ok":%s,"age_hours":%s,"max_hours":%s},"drill":{"ok":%s,"age_days":%s,"max_days":%s},"reason":"%s","detail":"https://github.com/CalCOFI/server/blob/main/scripts/backup_status.sh"}\n' \
  "$healthy" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$b_ok" "$b_age" "$MAX_BACKUP_AGE_H" "$d_ok" "$d_age_d" "$MAX_DRILL_AGE_D" "$reason" > "$OUT/pg_backup.json"
if $healthy; then printf 'ok %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OUT/pg_backup.ok"; else rm -f "$OUT/pg_backup.ok"; fi
chmod 644 "$OUT"/pg_backup.*
