#!/usr/bin/env python3
"""clear_personal_archive.py — remove My Drive/projects/calcofi/_archive from Ben's Drive,
the last step of retiring his personal data-public, so the CalCOFI Data Folder holds
the only copy he keeps.

Drive lets Ben trash only what he owns; a file someone else owns he can only take out
of his folders (it goes back to its owner's Drive, under "is:unorganized owner:me",
still counting against their storage). So, walking the archive with the Drive API
(shortcuts are not followed):
  0. every file someone else owns must be in the CalCOFI Data Folder at the same path
     and size; any that is not is copied there first (rclone copyto, server side);
  1. a file owned by someone else, sitting in one of Ben's folders, is moved into the
     folder its owner (or another non-Ben owner) has at the same path in
     _folders_owned_by_others (names compared without Drive's " 2" suffixes), so it
     goes back to them inside a folder, not loose;
  2. everything Ben owns that is not a folder (pointer READMEs, shortcuts, the copy of
     dic_field_descriptions) is trashed;
  3. each top folder owned by someone else, and each of their files left in Ben's
     folders, is taken out of the archive (returned to its owner);
  4. once a re-walk finds nothing but Ben's folders, _archive is trashed.

usage: clear_personal_archive.py [--apply]   (default: dry run)
"""
import json, re, subprocess, sys, time, collections, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

APPLY   = "--apply" in sys.argv
OWNER   = "ben@ecoquants.com"
API     = "https://www.googleapis.com/drive/v3"
FOLDER  = "application/vnd.google-apps.folder"
DATA    = "data-public_2026-10-06"
FOREIGN = f"{DATA}/_folders_owned_by_others"
ARCHIVE = f"gdrive-ecoquants:projects/calcofi/_archive/{DATA}"
SHARED  = "gdrive-ecoquants,root_folder_id=1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW:data-public"
RENAMED = {"ucsd_sio 2": "sio", "picoplankton-bacteria 2": "picoplankton-bacteria"}

def refresh():
  global TOKEN
  subprocess.run(["rclone", "lsd", "gdrive-ecoquants:projects"], capture_output=True)
  cfg = json.loads(subprocess.run(["rclone", "config", "dump"], capture_output=True, text=True).stdout)
  TOKEN = json.loads(cfg["gdrive-ecoquants"]["token"])["access_token"]
refresh()

def api(method, path, params=None, body=None, tries=6):
  params = dict(params or {}, supportsAllDrives="true")
  for i in range(tries):
    req = urllib.request.Request(f"{API}/{path}?" + urllib.parse.urlencode(params), method=method,
      data=json.dumps(body).encode() if body is not None else None,
      headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
      with urllib.request.urlopen(req) as r:
        t = r.read(); return json.loads(t) if t else {}
    except urllib.error.HTTPError as e:
      msg = e.read().decode()[:300]
      if e.code == 401: refresh(); continue
      if e.code in (403, 429, 500, 503) and ("ratelimit" in msg.lower() or e.code != 403): time.sleep(2 ** i); continue
      return {"error": e.code, "message": msg}
  return {"error": "retries", "message": path}

def children(fid):
  out, tok = [], None
  while True:
    r = api("GET", "files", {"q": f"'{fid}' in parents and trashed=false", "pageSize": 1000,
      "fields": "nextPageToken,files(id,name,mimeType,size,owners(emailAddress),parents)",
      **({"pageToken": tok} if tok else {})})
    out += r.get("files", []); tok = r.get("nextPageToken")
    if not tok: return out

def walk(fid, path=""):
  items = []
  for c in children(fid):
    c["path"] = f"{path}/{c['name']}".lstrip("/")
    c["owner"] = (c.get("owners") or [{}])[0].get("emailAddress")
    items.append(c)
    if c["mimeType"] == FOLDER: items += walk(c["id"], c["path"])
  return items

calcofi = next(c for c in children("root") if c["name"] == "projects")
calcofi = next(c for c in children(calcofi["id"]) if c["name"] == "calcofi")
archive = next(c for c in children(calcofi["id"]) if c["name"] == "_archive" and c["mimeType"] == FOLDER)
items   = walk(archive["id"])
by_id   = {x["id"]: x for x in items}
by_id[archive["id"]] = {"owner": OWNER, "path": ""}
pfolder = lambda x: by_id.get(x["parents"][0], {})
norm    = lambda p: "/".join(re.sub(r" \d+$", "", s) for s in p.split("/"))
size    = lambda x: int(x["size"]) if "size" in x else -1

# 0. others' files in the data tree have a same-size copy in the CalCOFI Data Folder ----
theirs = [x for x in items if x["mimeType"] != FOLDER and x["owner"] != OWNER
          and x["path"].startswith(DATA + "/") and not x["path"].startswith(FOREIGN + "/")]
r = subprocess.run(["rclone", "lsjson", "-R", "--files-only", "--drive-skip-shortcuts", SHARED],
                   capture_output=True, text=True, check=True)
s_size = {x["Path"]: x["Size"] for x in json.loads(r.stdout)}
s_path = lambda p: "/".join(RENAMED.get(s, s) for s in p.removeprefix(DATA + "/").split("/"))
# a Google Doc/Sheet has no extension in the API but one in rclone's listing, and size -1 there;
# three Sheets were renamed "<name> (sheet)" in the CalCOFI Data Folder (2026-10-06)
native  = lambda x: x["mimeType"].startswith("application/vnd.google-apps.")
unsheet = lambda p: re.sub(r"\s*\(sheet\)", "", p)
present = lambda x: (any(unsheet(p).startswith(s_path(x["path"]) + ".") and s_size[p] == -1 for p in s_size)
                     if native(x) else s_size.get(s_path(x["path"])) == size(x))
missing = [x for x in theirs if not present(x)]
print(f"files owned by others: {len(theirs)}; without a same-size copy in the CalCOFI Data Folder: {len(missing)}")
for x in missing[:30]: print("   copy", x["path"], size(x), "->", s_path(x["path"]), s_size.get(s_path(x["path"])))

# 1–3. plan ----
dest = collections.defaultdict(list)
for x in items:
  if x["mimeType"] == FOLDER and x["owner"] != OWNER and x["path"].startswith(FOREIGN + "/"):
    dest[norm(x["path"][len(FOREIGN) + 1:])].append(x)

moves, trash, orphan, ambiguous = [], [], [], []
for x in items:
  in_foreign_tree = pfolder(x).get("owner") != OWNER
  if x["mimeType"] == FOLDER:
    if x["owner"] != OWNER and not in_foreign_tree: orphan.append(x)       # top foreign folder
    continue
  if x["owner"] == OWNER: trash.append(x); continue
  if in_foreign_tree: continue                                              # leaves with its folder
  rel  = pfolder(x)["path"].removeprefix(DATA + "/")
  cand = dest.get(norm(rel), [])
  same = [d for d in cand if d["owner"] == x["owner"]] or cand
  if len(same) == 1: moves.append((x, same[0]))
  elif len(same) > 1: ambiguous.append(x); orphan.append(x)
  else: orphan.append(x)

ben_in_foreign = [x for x in items if x["mimeType"] == FOLDER and x["owner"] == OWNER and pfolder(x).get("owner") != OWNER]
person = lambda o: "Betty" if o in ("bthuang@ucsd.edu", "bhuang0022@gmail.com") else o
c = collections.Counter((person(x["owner"]), "into their folder") for x, _ in moves)
c.update((person(x["owner"]), "loose file" if x["mimeType"] != FOLDER else "their folder") for x in orphan)
print(f"walked {len(items)} items under _archive")
for k, v in sorted(c.items()): print(f"  return {v:5d} {k[1]:18s} to {k[0]}")
print(f"  trash  {len(trash):5d} items Ben owns:", dict(collections.Counter(x["mimeType"].split(".")[-1] for x in trash)))
print(f"  ambiguous destinations: {len(ambiguous)}; Ben folders inside others' folders: {len(ben_in_foreign)}")
for x in ben_in_foreign[:10]: print("    ", x["path"])
for x in [x for x in trash if x["name"] != "_MOVED_README.txt"]: print("  trash:", x["path"], x["mimeType"].split(".")[-1])
if ben_in_foreign: sys.exit("stop: a Ben folder inside someone else's folder would be stranded")
if not APPLY: sys.exit("dry run only; rerun with --apply")

for x in missing:
  subprocess.run(["rclone", "copyto", f"{ARCHIVE}/{x['path'].removeprefix(DATA + '/')}",
                  f"{SHARED}/{s_path(x['path'])}"], check=True)
  print("   copied", s_path(x["path"]))

def run(label, fn, xs):
  with ThreadPoolExecutor(8) as ex: rs = list(ex.map(fn, xs))
  errs = [(x, r) for x, r in zip(xs, rs) if "error" in r]
  print(f"{label}: {len(xs) - len(errs)} ok, {len(errs)} errors")
  for x, r in errs[:20]: print("   ", (x[0] if isinstance(x, tuple) else x)["path"], r)

run("moved into owners' folders", lambda m: api("PATCH", f"files/{m[0]['id']}",
    {"addParents": m[1]["id"], "removeParents": m[0]["parents"][0], "fields": "id"}, {}), moves)
run("trashed", lambda x: api("PATCH", f"files/{x['id']}", {"fields": "id"}, {"trashed": True}), trash)
run("returned to owners", lambda x: api("PATCH", f"files/{x['id']}",
    {"removeParents": x["parents"][0], "fields": "id"}, {}), orphan)

left = [x for x in walk(archive["id"]) if x["owner"] != OWNER or x["mimeType"] != FOLDER]
print(f"left under _archive besides Ben's folders: {len(left)}")
for x in left[:20]: print("   ", x["path"], x["owner"])
if left: sys.exit("stop: _archive not trashed")
print("trashed _archive:", api("PATCH", f"files/{archive['id']}", {"fields": "id,trashed"}, {"trashed": True}))
