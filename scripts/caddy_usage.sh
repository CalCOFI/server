#!/usr/bin/env bash
# Aggregate Caddy access logs into a small public summary.
#
# WHY THIS EXISTS: erddap.calcofi.io and storage.calcofi.io are used mostly by
# machines — curl, R, Python pulling .csv / .nc / parquet — which never execute
# JavaScript, so the GA4 tag on their HTML pages counts only the humans
# browsing. Caddy sees every request. This turns those logs into the numbers
# calcofi.io/analytics renders next to the page views.
#
# PRIVACY: raw logs hold client IPs and user agents. Nothing here publishes
# either. IPs are counted distinct per day and discarded; user agents are
# reduced to one bucket (browser vs tool). The output is counts only.
#
# OUTPUT: /share/public/_usage/requests.json — already served publicly by Caddy
# at https://file.calcofi.io/_usage/requests.json, so the analytics workflow can
# fetch it in CI with no credentials. That is why this does not upload to GCS:
# the server's compute service account has read-only storage scopes.
#
# Usage:  scripts/caddy_usage.sh            # aggregate + write
#         scripts/caddy_usage.sh --dry-run  # print, write nothing
set -euo pipefail

LOG_DIR=${CADDY_LOG_DIR:-/share/logs/caddy}
OUT=${CADDY_USAGE_OUT:-/share/public/_usage/requests.json}
DAYS=${CADDY_USAGE_DAYS:-90}
DRY=${1:-}

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

# One record per host per day. `logs` are JSON lines; a rolled file keeps the
# same shape, so glob them all and let the date filter do the windowing.
summary=$(
  for f in "$LOG_DIR"/*.log "$LOG_DIR"/*.log.gz; do
    [ -e "$f" ] || continue
    # an `if`, not a `case`: a case pattern's unbalanced `)` inside $( ... )
    # is a bash parse error here
    if [ "${f##*.}" = "gz" ]; then zcat "$f"; else cat "$f"; fi
  done | jq -c --argjson days "$DAYS" '
    select(.ts != null and .request != null)
    | {
        day:   (.ts | todate | .[0:10]),
        host:  (.request.host // "unknown"),
        # the ONLY use of the address: a distinct count per day, never emitted
        ip:    (.request.remote_ip // .request.remote_addr // ""),
        bytes: (.size // 0),
        status:(.status // 0),
        path:  (.request.uri // "/" | split("?")[0]),
        # a browser sends Accept: text/html; a script asking for data does not.
        # Two buckets is all this needs to be useful, and more would invite
        # over-reading a user-agent string.
        kind:  (if ((.request.headers.Accept // [""])[0] // "") | test("text/html")
                then "browser" else "tool" end)
      }
  ' | jq -s --argjson days "$DAYS" '
      (now - ($days * 86400) | todate | .[0:10]) as $cutoff
      | map(select(.day >= $cutoff))
      | group_by([.host, .day])
      | map({
          host:      .[0].host,
          date:      .[0].day,
          requests:  length,
          bytes:     (map(.bytes) | add),
          clients:   ([.[].ip] | unique | length),   # distinct count only
          browser:   (map(select(.kind == "browser")) | length),
          tool:      (map(select(.kind == "tool"))    | length),
          errors:    (map(select(.status >= 400)) | length),
          top_paths: (group_by(.path) | map({path: .[0].path, n: length})
                      | sort_by(-.n) | .[0:10])
        })
      | sort_by(.host, .date)
  '
)

payload=$(jq -n --argjson rows "$summary" \
  '{generated: (now | todate), source: "caddy access logs", rows: $rows}')

if [ "$DRY" = "--dry-run" ]; then
  echo "$payload" | jq '{generated, n_rows: (.rows | length),
                         hosts: ([.rows[].host] | unique),
                         sample: .rows[0]}'
  exit 0
fi

echo "$payload" > "$OUT"
chmod 644 "$OUT"
echo "wrote $OUT ($(jq '.rows | length' < "$OUT") host-days)"
