#!/usr/bin/env python3
"""trash_archived_originals.py — free Ben's Drive storage after retiring his personal
data-public: moves to the Drive trash (recoverable for 30 days) the files in
My Drive/projects/calcofi/_archive/data-public_<date> that
  - Ben owns (files owned by others count against their owners, so they stay), and
  - are in the CalCOFI Data Folder at the same path and size (or are a known Drive
    conflict copy whose original is there).
Shortcuts and the pointer READMEs are left alone. Run after retire_personal_data_public.py.

usage: trash_archived_originals.py [--apply]   (default: dry run)
"""
import json, subprocess, sys, collections, os, tempfile

APPLY    = "--apply" in sys.argv
DATE     = "2026-10-06"
OWNER    = "ben@ecoquants.com"
ARCHIVE  = f"gdrive-ecoquants:projects/calcofi/_archive/data-public_{DATE}"
SHARED   = "gdrive-ecoquants,root_folder_id=1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW:data-public"
README   = "_MOVED_README.txt"
KNOWN_DUPLICATES = {
  "_spatial/CA_watershed-boundaries/wbd-hu8_ca 2.gpkg",
  "_spatial/NOAA_IEA-CA-Current/lme-ca-current_usa-eez 2.geojson",
}
RENAMED  = {"ucsd_sio 2": "sio", "picoplankton-bacteria 2": "picoplankton-bacteria"}

def lsjson(remote, *flags):
  r = subprocess.run(["rclone", "lsjson", "-R", "--files-only", "--drive-skip-shortcuts", *flags, remote],
                     capture_output=True, text=True, check=True)
  return json.loads(r.stdout)

def shared_path(p):
  return "/".join(RENAMED.get(x, x) for x in p.split("/"))

a_files = [x for x in lsjson(ARCHIVE, "-M")
           if x["Name"] != README and not x["Path"].startswith("_folders_owned_by_others/")]
s_size  = {x["Path"]: x["Size"] for x in lsjson(SHARED)}
mine    = [x for x in a_files if x.get("Metadata", {}).get("owner") == OWNER]
ok      = [x for x in mine if x["Path"] in KNOWN_DUPLICATES or s_size.get(shared_path(x["Path"])) == x["Size"]]
keep    = [x for x in mine if x not in ok]

by_owner = collections.defaultdict(lambda: [0, 0])
for x in a_files:
  o = x.get("Metadata", {}).get("owner", "?"); by_owner[o][0] += 1; by_owner[o][1] += max(x["Size"], 0)
for o, (n, b) in sorted(by_owner.items(), key=lambda kv: -kv[1][1]):
  print(f"  {o:40s} {n:5d} files {b/1e9:7.2f} GB")
print(f"{OWNER}: {len(ok)} files ({sum(max(x['Size'], 0) for x in ok)/1e9:.2f} GB) to trash; "
      f"{len(keep)} kept (no same-size copy in the CalCOFI Data Folder)")
for x in keep[:30]: print("  KEEP", x["Path"], x["Size"])
if not APPLY:
  sys.exit("dry run only; rerun with --apply")

# rclone delete moves Drive files to the trash (use_trash defaults to true)
with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
  f.write("\n".join(x["Path"] for x in ok) + "\n")
r = subprocess.run(["rclone", "delete", ARCHIVE, "--files-from-raw", f.name, "--drive-use-trash",
                    "--drive-skip-shortcuts", "--checkers", "16", "-v"], capture_output=True, text=True)
os.unlink(f.name)
errs = [l for l in r.stderr.splitlines() if "ERROR" in l]
print(f"rclone delete exit {r.returncode}; {len(errs)} error lines")
for l in errs[:30]: print("  ", l)

left = [x for x in lsjson(ARCHIVE, "-M") if x.get("Metadata", {}).get("owner") == OWNER
        and x["Name"] != README and not x["Path"].startswith("_folders_owned_by_others/")]
print(f"files owned by {OWNER} left in the archive: {len(left)}")
