# Incidents

Post-mortems for `shiny-server` outages, newest first. One section per incident:
what broke, the evidence that proved it, what changed so it cannot recur silently.

Operational how-to lives in [README.md](README.md); this file is the record of
what went wrong and why the guards exist. When you add a guard because of an
outage, write the outage down here and point at it from the code comment — a
rule whose reason is only in someone's memory gets removed by the next person.

---

## 2026-09-08 — one HTTP request wedged the whole VM for 5 h 40 m

**Impact.** Every service on `shiny-server` was unreachable 03:35–09:17 UTC:
all Shiny apps, ERDDAP, `storage.calcofi.io`, `file.calcofi.io`, pgAdmin, the
tile server. 13 Upptime issues (#93–#106). No data was lost or corrupted.

### What happened

At 03:27:03 UTC a crawler asked for a whole table with no query string:

```
03:27:03   status=0   dur=24.9s   bytes=0   client 57.141.4.40
           /erddap/tabledap/calcofi_ctd-cast_full.json
```

`tabledap/{dataset}.json` with no query string means "serialise the entire
dataset", and `calcofi_ctd-cast_full` is the largest one we publish. The client
disconnected after 24.9 s — that is what Caddy's `status=0, 0 bytes` records —
but **ERDDAP does not cancel the underlying query when the client goes away**,
so it kept building the response for nobody.

It was not a flood: 12 requests reached ERDDAP in the 25 minutes around it. The
same crawler (Meta range `57.141.4.x`, presenting a spoofed Mac-browser
User-Agent) had been walking the catalogue pulling progressively larger bare
`.json` dumps — `cce-lter_zooscan.json`, `cce-lter_picoplankton-bacteria.json`,
`swfsc_cufes.json` (5.6 MB in 4.7 s) — and then reached the big one.

### Why the machine never recovered on its own

| | 03:24 UTC | 03:34 → 09:16 (5 h 40 m) |
|---|---|---|
| Disk read  | 0.1 MB/s | **251.7 MB/s, perfectly flat** |
| Disk write | 0.4 MB/s | **0.0 MB/s** |
| CPU        | 6.8 %    | 42 % → **99.7 %** |

A dead-flat 251.7 MB/s is not a workload, it is a ceiling — the n2-standard-4
read cap. The box read roughly 5 TB off a 200 GB disk, i.e. the same data over
and over, while writing nothing.

There was **no OOM kill and no kernel panic**, which is the counter-intuitive
part and the reason it could not self-heal. The working set was file-backed
(mmap'd) rather than anonymous memory. File-backed pages are *reclaimable*, so
the kernel never declared out-of-memory — it evicted and re-read them forever.
That is page-cache thrashing without swap: a stable, self-sustaining state that
the OOM killer, by design, will never break. Only a reset clears it.

Userspace was starved so completely that `dockerd` was flushing log lines two
hours late and `journald` stopped writing at 03:27:03 — the exact second of the
request.

**The symptom to recognise:** TCP connected on 22/80/443 (the kernel was
healthy and answering SYNs) while `ssh` timed out "during banner exchange" and
TLS never completed. *Ports open but nothing answers* means a wedged host, not
a down host and not a firewall problem.

### Diagnosing a repeat

In this order — each step is off-box until the last, so it works while the
server is unreachable:

1. `nc -G 10 -vz <ip> 22 443` — if TCP connects but `ssh` hangs at the banner,
   the host is wedged, not down. Skip firewall theories.
2. Upptime issues in [`CalCOFI/uptime`](https://github.com/CalCOFI/uptime/issues)
   pin the cascade start to the minute, and the order tells you which service
   noticed first (not necessarily which one broke).
3. `gs://calcofi-backups/postgres/_status/last_success.json` and the newest
   `gs://calcofi-db/qc/ctd/flag_meta.json` prove how late the box was healthy —
   these are written by cron jobs from the box itself, so their timestamps
   bracket the failure without touching it.
4. Cloud Monitoring `compute.googleapis.com/instance/disk/read_bytes_count`
   (`ALIGN_RATE`, 600 s) — a flat line at a round number is a throttle ceiling,
   which means "stuck", not "busy".
5. `gcloud compute instances get-serial-port-output shiny-server` — the
   10-minute `OSConfigAgent` heartbeat stopping is the clearest marker of when
   userspace died. **Grab this before the reset.**
6. After recovery, `/share/logs/caddy/erddap.log` (JSON, one object per line)
   names the request. A `status: 0` with a long `duration` is a client that
   gave up on something the server is still doing.

`calcofi-admin` has **no `compute.*` permissions**, so the serial console and
the reset need a user account: `gcloud auth login bebest@ucsd.edu`, then
`gcloud compute instances reset shiny-server --zone=us-central1-a`. Set the
account back to `calcofi-admin@…` afterwards (see README, "Google instance").
The external IP is the reserved static `shiny-server-ip`, so it survives both a
reset and a stop/start.

### Fixes applied 2026-09-08

- **Enforced guard in [`caddy/Caddyfile`](caddy/Caddyfile)** — the `@bulk_data`
  matcher refuses `tabledap`/`griddap` data-format requests that carry no query
  string, with a 403 explaining how to constrain the query and pointing at the
  release Parquet. Anchored with `$` so the metadata siblings (`.das`, `.dds`,
  `.fgdc`, `.iso19115`, `.html`, `.graph`, `.subset`, `.ncHeader`,
  `.nccsvMetadata`) still pass. **Deliberately no User-Agent exemption**: the
  agent that took the server down was a spoofed browser, so any UA-based carve-out
  would have let it straight through. No CalCOFI consumer requests a bare dump —
  they all link the `.html` pages — so nothing of ours is affected.
- **`robots.txt` now names the bulk scrapers and AI-training crawlers** with
  `Disallow: /`, while search engines keep falling through to the wildcard rules
  so the catalogue stays findable. This only reduces well-behaved noise:
  robots.txt is advisory and already disallowed `*.json*` before the outage, and
  this crawler ignored it. **The Caddy matcher is the control that actually
  holds; robots.txt is a courtesy.**

### Known gaps (not fixed by the above)

- A **constrained but still enormous** query (`.json?depth_m>=0`) can reproduce
  this. The guard raises the bar, it does not close the class. The real fix is a
  server-side cap on response size or duration inside ERDDAP, plus request
  concurrency limits — Caddy cannot cancel work ERDDAP has already started.
- **A bigger VM would not have prevented it**, only delayed it: the request is
  unbounded, so more RAM means a longer fall. Resizing was considered and
  deliberately not done.
- Stock `caddy:latest` has no rate-limiting module. Per-IP limits would need a
  custom image (`caddy-ratelimit`), which is a heavier change than this warranted.
