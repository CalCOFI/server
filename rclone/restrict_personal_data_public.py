#!/usr/bin/env python3
"""restrict_personal_data_public.py — make Ben's retired personal Drive folder
(My Drive/projects/calcofi/data-public, emptied by retire_personal_data_public.py)
read-only for everyone but its owner, so nobody drops a file in the wrong place.

- turns off inherited access on data-public (a "limited access" folder), so the
  writers of projects/calcofi no longer reach it;
- gives every user who could open it before a direct `reader` permission (no email);
- downgrades anyone-with-link from commenter to reader;
- moves the shortcuts still inside it (to folders and files their owners keep) into
  projects/calcofi/_archive/data-public_<date>/ at the same relative path;
- re-lists every folder below and reports any non-owner who can still write
  (a subfolder owned by someone else keeps its owner).

Uses the access token of the `gdrive-ecoquants` rclone remote.

usage: restrict_personal_data_public.py [--apply]   (default: dry run)
"""
import json, subprocess, sys, urllib.request, urllib.parse

APPLY   = "--apply" in sys.argv
API     = "https://www.googleapis.com/drive/v3"
PERSONAL = "gdrive-ecoquants:projects/calcofi/data-public"
ARCHIVE  = "gdrive-ecoquants:projects/calcofi/_archive/data-public_2026-10-06"
OWNER    = "ben@ecoquants.com"

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
    return {"error": e.code, "message": e.read().decode()[:300]}

def lsjson(remote, *flags):
  r = subprocess.run(["rclone", "lsjson", *flags, remote], capture_output=True, text=True, check=True)
  return json.loads(r.stdout)

def dir_id(remote, name):
  return next(x["ID"] for x in lsjson(remote, "--dirs-only") if x["Name"] == name)

PERM_FIELDS = "permissions(id,type,role,emailAddress,permissionDetails)"
dp = dir_id("gdrive-ecoquants:projects/calcofi", "data-public")
f = api("GET", f"files/{dp}", {"fields": f"inheritedPermissionsDisabled,{PERM_FIELDS}"})
users = [p for p in f["permissions"] if p["type"] == "user" and p["role"] != "owner"]
link  = [p for p in f["permissions"] if p["type"] == "anyone"]
print(f"data-public {dp}: inheritedPermissionsDisabled={f.get('inheritedPermissionsDisabled')}")
for p in users: print(f"  {p['emailAddress']:45s} {p['role']} -> reader")
for p in link:  print(f"  anyone with link {p['role']} -> reader")

# shortcuts still inside the personal folder (rclone lists them as "targetID\tshortcutID")
shortcuts = [x for x in lsjson(PERSONAL, "-R", "--max-depth", "4")
             if "\t" in x.get("ID", "") and not x["Path"].startswith("→")
             and "/→ " not in x["Path"] and not x["Name"].startswith("→")]
for s in shortcuts: print(f"  move shortcut {s['Path']} -> archive")
if not APPLY:
  sys.exit("dry run only; rerun with --apply")

# 1. limited access, then direct reader permissions ----
r = api("PATCH", f"files/{dp}", {"fields": "inheritedPermissionsDisabled"},
        {"inheritedPermissionsDisabled": True})
print("inheritedPermissionsDisabled ->", r)
for p in users:
  inherited_only = all(d.get("inherited") for d in p.get("permissionDetails", []))
  if inherited_only:
    r = api("POST", f"files/{dp}/permissions", {"sendNotificationEmail": "false"},
            {"type": "user", "role": "reader", "emailAddress": p["emailAddress"]})
  else:
    r = api("PATCH", f"files/{dp}/permissions/{p['id']}", None, {"role": "reader"})
  print(f"  {p['emailAddress']}: {r.get('role', r)}")
for p in link:
  print("  anyone with link:", api("PATCH", f"files/{dp}/permissions/{p['id']}", None, {"role": "reader"}).get("role"))

# 2. shortcuts into the archive, same relative path ----
for s in shortcuts:
  sid = s["ID"].split("\t")[1]
  parent = api("GET", f"files/{sid}", {"fields": "parents"})["parents"][0]
  rel = s["Path"].rsplit("/", 1)[0] if "/" in s["Path"] else ""
  subprocess.run(["rclone", "mkdir", f"{ARCHIVE}/{rel}"], check=True)
  up, name = (f"{ARCHIVE}/{rel}".rsplit("/", 1))
  dest = dir_id(up, name)
  r = api("PATCH", f"files/{sid}", {"addParents": dest, "removeParents": parent, "fields": "id,parents"}, {})
  print(f"  moved shortcut {s['Path']}: {r}")

# 3. who can still write anywhere below ----
dirs = [{"Path": "", "ID": dp}] + lsjson(PERSONAL, "-R", "--dirs-only", "--drive-skip-shortcuts")
left = []
for d in dirs:
  ps = api("GET", f"files/{d['ID']}", {"fields": PERM_FIELDS}).get("permissions", [])
  for p in ps:
    if p["role"] in ("writer", "fileOrganizer", "organizer") and p.get("emailAddress") != OWNER:
      left.append((d["Path"] or "(data-public)", p.get("emailAddress", p["type"]), p["role"]))
    if p["role"] == "owner" and p.get("emailAddress") != OWNER:
      left.append((d["Path"] or "(data-public)", p.get("emailAddress"), "owner"))
print(f"\n{len(dirs)} folders checked; non-owner write access left: {len(left)}")
for l in left: print("  ", *l)
