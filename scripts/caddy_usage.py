#!/usr/bin/env python3
"""Aggregate Caddy access logs into a small public usage summary.

WHY THIS EXISTS: erddap.calcofi.io and storage.calcofi.io are used mostly by
machines — curl, R, Python pulling .csv / .nc / parquet — which never execute
JavaScript, so the GA4 tag on their HTML pages counts only the humans browsing.
`calcofi4r::cc_get_db()` reads parquet straight from the bucket and would never
appear at all. Caddy sees every request; this turns those logs into the numbers
rendered beside the page views at calcofi.io/analytics.

PRIVACY: the raw logs hold client IPs and user agents. Neither is published.
Addresses are counted distinct per day and discarded; the user agent is reduced
to one of two buckets (a browser asks for text/html, a script does not). The
output is counts and top paths — no row-level record leaves the server.

OUTPUT: /share/public/_usage/requests.json, which Caddy already serves at
https://file.calcofi.io/_usage/requests.json — so the analytics workflow fetches
it in CI with no credentials. Deliberately not a GCS upload: the server's
compute service account has read-only storage scopes.

Pure stdlib (the host has no jq, and this should not need one), and must run as
root because Caddy writes its logs 0600 root-owned.

Usage:
    scripts/caddy_usage.py              # aggregate + write
    scripts/caddy_usage.py --dry-run    # print a summary, write nothing
"""

from __future__ import annotations

import collections
import datetime as dt
import glob
import gzip
import json
import os
import pathlib
import sys

LOG_DIR = os.environ.get("CADDY_LOG_DIR", "/share/logs/caddy")
OUT = pathlib.Path(os.environ.get("CADDY_USAGE_OUT", "/share/public/_usage/requests.json"))
DAYS = int(os.environ.get("CADDY_USAGE_DAYS", "90"))
TOP_PATHS = 10


def lines(path: str):
    op = gzip.open if path.endswith(".gz") else open
    try:
        with op(path, "rt", errors="replace") as f:
            yield from f
    except OSError as e:                      # unreadable roll, keep going
        print(f"! {path}: {e}", file=sys.stderr)


def main() -> int:
    cutoff = (dt.date.today() - dt.timedelta(days=DAYS)).isoformat()

    # (host, day) -> counters. `ips` is a set purely so it can be len()'d; it is
    # never written out.
    acc: dict[tuple, dict] = {}

    for path in sorted(glob.glob(f"{LOG_DIR}/*.log") + glob.glob(f"{LOG_DIR}/*.log.gz")):
        for ln in lines(path):
            ln = ln.strip()
            if not ln or not ln.startswith("{"):
                continue
            try:
                r = json.loads(ln)
            except json.JSONDecodeError:
                continue
            req = r.get("request")
            ts = r.get("ts")
            if not req or ts is None:
                continue

            day = dt.datetime.fromtimestamp(ts, dt.timezone.utc).date().isoformat()
            if day < cutoff:
                continue

            host = req.get("host", "unknown")
            k = (host, day)
            a = acc.get(k)
            if a is None:
                a = acc[k] = {"requests": 0, "bytes": 0, "browser": 0, "tool": 0,
                              "errors": 0, "ips": set(), "paths": collections.Counter()}

            a["requests"] += 1
            a["bytes"] += int(r.get("size") or 0)
            if int(r.get("status") or 0) >= 400:
                a["errors"] += 1

            ip = req.get("client_ip") or req.get("remote_ip") or ""
            if ip:
                a["ips"].add(ip)                       # counted, never emitted

            accept = " ".join((req.get("headers") or {}).get("Accept") or [])
            a["browser" if "text/html" in accept else "tool"] += 1

            a["paths"][(req.get("uri") or "/").split("?")[0]] += 1

    rows = [{
        "host": host, "date": day,
        "requests": a["requests"], "bytes": a["bytes"],
        "clients": len(a["ips"]),                      # distinct count only
        "browser": a["browser"], "tool": a["tool"], "errors": a["errors"],
        "top_paths": [{"path": p, "n": n} for p, n in a["paths"].most_common(TOP_PATHS)],
    } for (host, day), a in sorted(acc.items())]

    payload = {
        "generated": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "source": "caddy access logs",
        "window_days": DAYS,
        "rows": rows,
    }

    # the guarantee, enforced rather than promised
    blob = json.dumps(payload)
    assert "remote_ip" not in blob and "User-Agent" not in blob, "PII leaked into the summary"

    if "--dry-run" in sys.argv:
        hosts = sorted({r["host"] for r in rows})
        print(json.dumps({"n_rows": len(rows), "hosts": hosts,
                          "sample": rows[0] if rows else None}, indent=1))
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(blob)
    OUT.chmod(0o644)
    print(f"wrote {OUT} ({len(rows)} host-days, "
          f"{sum(r['requests'] for r in rows)} requests)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
