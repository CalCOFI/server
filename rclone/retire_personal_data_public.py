#!/usr/bin/env python3
"""retire_personal_data_public.py — finish the move of CalCOFI source files from Ben's
personal Drive folder (My Drive/projects/calcofi/data-public) to the CalCOFI Data
Folder (the UCSD Shared Drive folder 1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW, data-public/).

Runs on a machine with the `gdrive-ecoquants` rclone remote (Ben's own OAuth client),
after migrate_gdrive_to_shared.sh and the 2026-10-05 copy of everything else.

The personal folders stay where they are, with the same ids and sharing, so a
provider who opens one from an old link or bookmark finds it. Each one is emptied and gets
  - `_MOVED_README.txt`: where its files went and where new files go, and
  - a Drive shortcut, `→ CalCOFI Data Folder (new location)`, to its counterpart.
The files are moved (not deleted) to My Drive/projects/calcofi/_archive/data-public_<date>.
Shortcuts inside the personal folder (folders and files their owners keep) are left
in place.

usage:
  retire_personal_data_public.py            # dry run: verify + print the plan
  retire_personal_data_public.py --apply    # verify, move, write pointers, re-verify
"""
import json, subprocess, sys, collections, datetime

APPLY    = "--apply" in sys.argv
DATE     = "2026-10-06"
SHARED_ID = "1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW"
PERSONAL = "gdrive-ecoquants:projects/calcofi/data-public"
ARCHIVE  = f"gdrive-ecoquants:projects/calcofi/_archive/data-public_{DATE}"
SHARED_ROOT = f"gdrive-ecoquants,root_folder_id={SHARED_ID}:"
SHARED   = SHARED_ROOT + "data-public"
README   = "_MOVED_README.txt"
SHORTCUT = "→ CalCOFI Data Folder (new location)"
POINTERS = {README, SHORTCUT}

# personal files deliberately not copied: Drive conflict copies whose original is
# already in the CalCOFI Data Folder (checked by size, 2026-10-05)
KNOWN_DUPLICATES = {
  "_spatial/CA_watershed-boundaries/wbd-hu8_ca 2.gpkg",
  "_spatial/NOAA_IEA-CA-Current/lme-ca-current_usa-eez 2.geojson",
}
DUPLICATE_DIRS = ("cce-lter/picoplankton-bacteria 2/", "ucsd_sio 2/")
# personal folder name -> CalCOFI Data Folder name, where they differ
RENAMED = {"ucsd_sio 2": "sio", "picoplankton-bacteria 2": "picoplankton-bacteria"}

def rclone(*args, check=True):
  r = subprocess.run(["rclone", *args], capture_output=True, text=True)
  if check and r.returncode != 0:
    sys.exit(f"rclone {' '.join(args[:2])} failed:\n{r.stderr[-2000:]}")
  return r

def lsjson(remote, *flags):
  return json.loads(rclone("lsjson", "-R", "--drive-skip-shortcuts", *flags, remote).stdout)

def is_known_dup(p):
  return p in KNOWN_DUPLICATES or p.startswith(DUPLICATE_DIRS)

# 1. verify every personal file is in the CalCOFI Data Folder ----
print(f"listing {PERSONAL} and {SHARED} …")
p_files = [x for x in lsjson(PERSONAL, "--files-only") if x["Name"] not in POINTERS]
s_size  = {x["Path"]: x["Size"] for x in lsjson(SHARED, "--files-only")}
missing = [x["Path"] for x in p_files
           if s_size.get(x["Path"]) != x["Size"] and not is_known_dup(x["Path"])]
# Google Docs/Sheets list with size -1 on both sides, so size equality covers them
print(f"personal: {len(p_files)} files (shortcuts excluded); "
      f"not in the CalCOFI Data Folder at the same size: {len(missing)}")
if missing:
  for m in missing[:30]: print("  MISSING", m)
  sys.exit("stop: copy these first (rclone copy --ignore-existing) and rerun")

# 2. plan the pointers ----
p_dirs = [x["Path"] for x in lsjson(PERSONAL, "--dirs-only")] + [""]
s_dirs = {x["Path"]: x["ID"] for x in lsjson(SHARED, "--dirs-only")}
s_dirs[""] = json.loads(rclone("lsjson", "--dirs-only", SHARED_ROOT).stdout)
s_dirs[""] = next(x["ID"] for x in s_dirs[""] if x["Name"] == "data-public")

def counterpart(d):
  """nearest folder in the CalCOFI Data Folder for personal folder d"""
  parts = [RENAMED.get(p, p) for p in d.split("/")] if d else []
  while parts and "/".join(parts) not in s_dirs:
    parts.pop()
  return "/".join(parts)

plan = [(d, counterpart(d)) for d in sorted(p_dirs)]
n_by_owner = collections.Counter(x.get("Metadata", {}).get("owner", "?") for x in p_files)
print(f"move {len(p_files)} files to {ARCHIVE}")
print(f"pointers in {len(plan)} folders; folders without an exact counterpart:")
for d, c in plan:
  if d and c != d: print(f"  {d!r} -> {c or '(data-public)'!r}")

def readme(d, c):
  url = f"https://drive.google.com/drive/folders/{s_dirs[c]}"
  where = "CalCOFI Data Folder / data-public" + (f" / {c}" if c else "")
  return f"""MOVED: this folder is retired ({DATE})

Everything that was in this folder now lives in the CalCOFI Data Folder, the
UCSD-managed shared folder that the CalCOFI database reads its source files from:

  {where}
  {url}

Please put new or updated files there, not here. Files put in this folder are not
read by any CalCOFI ingest and are not copied to the public storage bucket.

If you cannot open the link, ask Ben Best (ben@ecoquants.com) for access.
The old copies are kept by Ben Best in case anything needs to be recovered.
"""

if not APPLY:
  d, c = plan[0]
  print("\nexample README for data-public/:\n" + readme(d, c))
  print("dry run only; rerun with --apply")
  sys.exit(0)

# 3. move the files (folders stay, with their ids and sharing) ----
print(f"\nmoving files → {ARCHIVE} …")
r = rclone("move", PERSONAL, ARCHIVE, "--drive-skip-shortcuts",
           "--exclude", README, "--exclude", SHORTCUT,
           "--transfers", "8", "--checkers", "16", "--stats-one-line", "-v", check=False)
errs = [l for l in r.stderr.splitlines() if "ERROR" in l]
print(f"rclone move exit {r.returncode}; {len(errs)} error lines")
for l in errs[:30]: print("  ", l)

# 4. write the pointers ----
s_have = {x["Path"] for x in json.loads(rclone(
  "lsjson", "-R", PERSONAL, "--include", README, "--include", SHORTCUT).stdout)}
for d, c in plan:
  sub = f"{d}/" if d else ""
  subprocess.run(["rclone", "rcat", f"{PERSONAL}/{sub}{README}"],
                 input=readme(d, c), text=True, check=True)
  if f"{sub}{SHORTCUT}" not in s_have:
    rclone("backend", "shortcut", SHARED, c, "-o", f"target={PERSONAL}", f"{sub}{SHORTCUT}")
  print("  pointer", d or "(data-public)", "->", c or "(data-public)")

# 5. re-verify: only pointers remain ----
left = [x["Path"] for x in lsjson(PERSONAL, "--files-only") if x["Name"] not in POINTERS]
print(f"\nfiles left in the personal folder besides pointers (shortcuts excluded): {len(left)}")
for p in left[:30]: print("  ", p)
