#!/usr/bin/env python3
"""replace_foreign_folders.py — last step of retiring Ben's personal data-public:
a folder inside it that someone else owns keeps its owner's write access (Drive
never demotes an owner), so each one is moved, as it is, into
projects/calcofi/_archive/data-public_<date>/_folders_owned_by_others/<path>, and a
folder of the same name owned by Ben takes its place, with the same pointers
(`_MOVED_README.txt` + shortcut to the CalCOFI Data Folder counterpart) in it and
in each recreated subfolder. The new folders inherit data-public's read-only
sharing. Drive conflict-copy folders ("… 2") are only archived, not recreated.

The folders hold only pointers by now (retire_personal_data_public.py moved
their files), so no data moves. Run after restrict_personal_data_public.py.

usage: replace_foreign_folders.py [--apply]   (default: dry run)
"""
import json, subprocess, sys, urllib.request, urllib.parse

APPLY    = "--apply" in sys.argv
DATE     = "2026-10-06"
API      = "https://www.googleapis.com/drive/v3"
OWNER    = "ben@ecoquants.com"
PERSONAL = "gdrive-ecoquants:projects/calcofi/data-public"
FOREIGN  = f"gdrive-ecoquants:projects/calcofi/_archive/data-public_{DATE}/_folders_owned_by_others"
SHARED_ROOT = "gdrive-ecoquants,root_folder_id=1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW:"
SHARED   = SHARED_ROOT + "data-public"
README   = "_MOVED_README.txt"
SHORTCUT = "→ CalCOFI Data Folder (new location)"
DUPLICATES = {"ucsd_sio 2", "cce-lter/picoplankton-bacteria 2"}
RENAMED  = {"ucsd_sio 2": "sio", "picoplankton-bacteria 2": "picoplankton-bacteria"}

subprocess.run(["rclone", "lsd", "gdrive-ecoquants:projects/calcofi"], capture_output=True)  # refresh token
cfg = json.loads(subprocess.run(["rclone", "config", "dump"], capture_output=True, text=True).stdout)
TOKEN = json.loads(cfg["gdrive-ecoquants"]["token"])["access_token"]

def api(method, path, params=None, body=None):
  url = f"{API}/{path}" + ("?" + urllib.parse.urlencode(params) if params else "")
  req = urllib.request.Request(url, method=method,
    data=json.dumps(body).encode() if body is not None else None,
    headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
  try:
    with urllib.request.urlopen(req) as r:
      t = r.read(); return json.loads(t) if t else {}
  except urllib.error.HTTPError as e:
    sys.exit(f"{method} {path}: {e.code} {e.read().decode()[:300]}")

def lsjson(remote, *flags):
  r = subprocess.run(["rclone", "lsjson", *flags, remote], capture_output=True, text=True, check=True)
  return json.loads(r.stdout)

def rclone(*a):
  subprocess.run(["rclone", *a], check=True, capture_output=True, text=True)

def dir_id(path):
  up, name = path.rsplit("/", 1)
  return next(x["ID"] for x in lsjson(up, "--dirs-only") if x["Name"] == name)

parent = lambda p: p.rsplit("/", 1)[0] if "/" in p else ""

# folders and their owners ----
dirs  = {x["Path"]: x for x in lsjson(PERSONAL, "-R", "--dirs-only", "-M", "--drive-skip-shortcuts")}
owner = {p: x.get("Metadata", {}).get("owner") for p, x in dirs.items()}
roots = sorted(p for p in dirs if owner[p] != OWNER and (parent(p) == "" or owner.get(parent(p)) == OWNER))
s_dirs = {x["Path"]: x["ID"] for x in lsjson(SHARED, "-R", "--dirs-only", "--drive-skip-shortcuts")}
s_dirs[""] = next(x["ID"] for x in lsjson(SHARED_ROOT, "--dirs-only") if x["Name"] == "data-public")

def counterpart(d):
  parts = [RENAMED.get(p, p) for p in d.split("/")]
  while parts and "/".join(parts) not in s_dirs: parts.pop()
  return "/".join(parts)

def readme(c):
  where = "CalCOFI Data Folder / data-public" + (f" / {c}" if c else "")
  return f"""MOVED: this folder is retired ({DATE})

Everything that was in this folder now lives in the CalCOFI Data Folder, the
UCSD-managed shared folder that the CalCOFI database reads its source files from:

  {where}
  https://drive.google.com/drive/folders/{s_dirs[c]}

Please put new or updated files there, not here. Files put in this folder are not
read by any CalCOFI ingest and are not copied to the public storage bucket.

If you cannot open the link, ask Ben Best (ben@ecoquants.com) for access.
The old copies are kept by Ben Best in case anything needs to be recovered.
"""

plan = []
for r in roots:
  sub = sorted(p for p in dirs if p == r or p.startswith(r + "/"))
  plan.append((r, sub, r not in DUPLICATES))
  print(f"{'replace' if r not in DUPLICATES else 'archive'} {r!r} (owner {owner[r]}; {len(sub)} folders)")
print(f"{len(roots)} folders owned by others; "
      f"{sum(len(s) for _, s, k in plan if k)} folders to recreate, owned by {OWNER}")
if not APPLY:
  sys.exit("dry run only; rerun with --apply")

for r, sub, recreate in plan:
  # move the foreign folder (only pointers inside) into the archive
  dest_parent = f"{FOREIGN}/{parent(r)}".rstrip("/")
  rclone("mkdir", dest_parent)
  fid = dirs[r]["ID"]
  cur = api("GET", f"files/{fid}", {"fields": "parents"})["parents"][0]
  api("PATCH", f"files/{fid}", {"addParents": dir_id(dest_parent), "removeParents": cur, "fields": "id"}, {})
  print(f"archived {r}")
  if not recreate: continue
  # recreate the folder tree, owned by Ben, with pointers in each folder
  for d in sub:
    rclone("mkdir", f"{PERSONAL}/{d}")
    c = counterpart(d)
    subprocess.run(["rclone", "rcat", f"{PERSONAL}/{d}/{README}"], input=readme(c), text=True, check=True)
    rclone("backend", "shortcut", SHARED, c, "-o", f"target={PERSONAL}", f"{d}/{SHORTCUT}")
  print(f"recreated {r} ({len(sub)} folders) with pointers")

# check: every folder below is Ben's, and holds no files besides READMEs ----
after   = lsjson(PERSONAL, "-R", "-M", "--drive-skip-shortcuts")
foreign = [x["Path"] for x in after if x["IsDir"] and x.get("Metadata", {}).get("owner") != OWNER]
files   = [x["Path"] for x in after if not x["IsDir"] and x["Name"] != README]
print(f"\nfolders not owned by {OWNER}: {len(foreign)}; files besides READMEs: {len(files)}")
for p in foreign + files: print("  ", p)
