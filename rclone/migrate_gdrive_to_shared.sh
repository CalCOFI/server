#!/bin/bash
# migrate_gdrive_to_shared.sh
# one-time migration of CalCOFI *public* source data from Ben's personal Google
# Drive (~/My Drive/projects/calcofi/data-public) into the organization Shared
# Drive folder "CalCOFI Data Folder", which becomes the new GDrive data source
# consumed by the workflows (see README_PLAN.qmd).
#
# CTD: only the 244 original calcofi.org source .zip files in
# calcofi/ctd-cast/download/ are migrated. The 98 unzipped cruise folders
# (~111K files, ~44 GB) are a regenerable cache and are SKIPPED — the CTD
# ingest re-unzips from the zips. This keeps the Shared Drive lean (well under
# the 500K-item Shared-Drive cap) and shrinks the transfer from ~62 GB/112K
# files to ~18 GB/~few-hundred files.
#
# usage:
#   ./migrate_gdrive_to_shared.sh            # DRY RUN (default, no changes)
#   ./migrate_gdrive_to_shared.sh --pilot    # copy ONE small cruise zip, verify
#   ./migrate_gdrive_to_shared.sh --execute  # perform the full migration
#
# prerequisites:
#   - rclone with the 'gdrive-ecoquants' remote (verified read+write to dest)
#   - the personal Drive mounted at ~/My Drive (Google Drive for Desktop)

set -euo pipefail

# ─── configuration ────────────────────────────────────────────────────────────

SRC_LOCAL="${HOME}/My Drive/projects/calcofi/data-public"
DEST_REMOTE="gdrive-ecoquants"
DEST_FOLDER_ID="1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW"   # "CalCOFI Data Folder"
DEST_SUBPATH="data-public"                            # mirror personal-Drive layout
CTD_DL_REL="calcofi/ctd-cast/download"                # CTD raw download dir
PILOT_ZIP="19-9003JD_CTDTest.zip"                     # smallest cruise (~2.4 MB)

LOG_DIR="${HOME}/.calcofi/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
MODE="dry-run"

# ─── parse arguments ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) MODE="dry-run"; shift ;;
    --pilot)   MODE="pilot";   shift ;;
    --execute) MODE="execute"; shift ;;
    *) echo "Unknown option: $1"; echo "Usage: $0 [--dry-run|--pilot|--execute]"; exit 1 ;;
  esac
done

mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/migrate_${MODE}_${TIMESTAMP}.log"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }

# rclone flags shared by every copy below
DRY=()
[ "${MODE}" = "dry-run" ] && DRY=(--dry-run)

COMMON_OPTS=(
  --drive-root-folder-id "${DEST_FOLDER_ID}"
  --transfers 8 --checkers 16 --drive-chunk-size 64M
  --skip-links
  --log-file "${LOG_FILE}" --log-level INFO
  --stats 15s --stats-one-line
)

# op1 excludes — kept separate so they are never mixed with an --include/--filter
# (rclone parses include+exclude in indeterminate order); op1 uses only --exclude.
EXCLUDES=(
  --exclude ".DS_Store" --exclude "*.tmp" --exclude "~*"
  # Google-native files are local pointers (~172 B stubs), not real data — skip
  --exclude "*.gdoc" --exclude "*.gsheet" --exclude "*.gslides"
  --exclude "*.gdraw" --exclude "*.gform" --exclude "*.gmap"
  --exclude "*.gjam"  --exclude "*.glink"  --exclude "*.gsite"
)

# ─── preflight ────────────────────────────────────────────────────────────────

log "═══════════════════════════════════════════════════════════════════════"
log "CalCOFI migration: personal Drive → Shared Drive (CalCOFI Data Folder)"
log "  mode:   ${MODE}"
log "  source: ${SRC_LOCAL}"
log "  dest:   ${DEST_REMOTE}: (root folder ${DEST_FOLDER_ID}) / ${DEST_SUBPATH}"
log "═══════════════════════════════════════════════════════════════════════"

command -v rclone >/dev/null || { log "ERROR: rclone not installed"; exit 1; }
rclone listremotes | grep -q "^${DEST_REMOTE}:$" || { log "ERROR: remote '${DEST_REMOTE}' missing"; exit 1; }
[ -d "${SRC_LOCAL}" ] || { log "ERROR: source not found: ${SRC_LOCAL}"; exit 1; }
# confirm we can read the destination folder
rclone lsf "${DEST_REMOTE}:" --drive-root-folder-id "${DEST_FOLDER_ID}" >/dev/null \
  || { log "ERROR: cannot access dest folder ${DEST_FOLDER_ID}"; exit 1; }
log "preflight OK"

# ─── pilot: one small cruise zip, end-to-end ──────────────────────────────────

if [ "${MODE}" = "pilot" ]; then
  log "PILOT: copying ${PILOT_ZIP} → ${DEST_SUBPATH}/${CTD_DL_REL}/"
  rclone copy "${SRC_LOCAL}/${CTD_DL_REL}/${PILOT_ZIP}" \
    "${DEST_REMOTE}:${DEST_SUBPATH}/${CTD_DL_REL}" "${COMMON_OPTS[@]}"
  log "verify: listing dest ${DEST_SUBPATH}/${CTD_DL_REL}/${PILOT_ZIP}"
  rclone lsl "${DEST_REMOTE}:${DEST_SUBPATH}/${CTD_DL_REL}/${PILOT_ZIP}" \
    --drive-root-folder-id "${DEST_FOLDER_ID}" | tee -a "${LOG_FILE}"
  log "verify: checksum match (local vs dest)"
  rclone check "${SRC_LOCAL}/${CTD_DL_REL}" \
    "${DEST_REMOTE}:${DEST_SUBPATH}/${CTD_DL_REL}" \
    --include "/${PILOT_ZIP}" --max-depth 1 \
    --drive-root-folder-id "${DEST_FOLDER_ID}" 2>&1 | tee -a "${LOG_FILE}" || true
  log "PILOT complete."
  exit 0
fi

# ─── 1) everything EXCEPT the CTD download tree (and the .accdb) ───────────────
# small (~1.5 GB): bottle, dic, stations, zooplankton, swfsc, scripps,
# _projects, _spatial, euphausiids, _lookups, whales-seabirds-turtles, etc.,
# plus the non-download files in ctd-cast/ (README, etc. — .accdb excluded).

log "[1/3] copying all data-public EXCEPT ${CTD_DL_REL}/ and *.accdb ..."
rclone copy "${SRC_LOCAL}" "${DEST_REMOTE}:${DEST_SUBPATH}" "${DRY[@]}" "${COMMON_OPTS[@]}" "${EXCLUDES[@]}" \
  --exclude "${CTD_DL_REL}/**" \
  --exclude "calcofi/ctd-cast/*.accdb"

# ─── 2) CTD source zips only (top-level *.zip in download/) ────────────────────
# --max-depth 1 avoids walking the 111K-file unzip cache; the +/-filter pair
# selects only the 244 top-level zips deterministically (no include/exclude mix).

log "[2/3] copying CTD source zips (top-level *.zip in ${CTD_DL_REL}/) ..."
rclone copy "${SRC_LOCAL}/${CTD_DL_REL}" \
  "${DEST_REMOTE}:${DEST_SUBPATH}/${CTD_DL_REL}" "${DRY[@]}" "${COMMON_OPTS[@]}" \
  --max-depth 1 --filter "+ /*.zip" --filter "- *"

# ─── 3) create empty data-private/ shell (private data handled separately) ─────

log "[3/3] ensuring data-private/ shell exists on Shared Drive ..."
if [ "${MODE}" = "execute" ]; then
  rclone mkdir "${DEST_REMOTE}:data-private" --drive-root-folder-id "${DEST_FOLDER_ID}" || true
else
  log "DRY RUN: would 'rclone mkdir ${DEST_REMOTE}:data-private'"
fi

# ─── summary ──────────────────────────────────────────────────────────────────

log "═══════════════════════════════════════════════════════════════════════"
if [ "${MODE}" = "dry-run" ]; then
  log "DRY RUN complete — no changes made. Re-run with --execute to transfer."
else
  log "MIGRATION complete. Verifying dest tree top-level ..."
  rclone lsf "${DEST_REMOTE}:${DEST_SUBPATH}" --drive-root-folder-id "${DEST_FOLDER_ID}" \
    --dirs-only | tee -a "${LOG_FILE}"
  ndz=$(rclone lsf "${DEST_REMOTE}:${DEST_SUBPATH}/${CTD_DL_REL}" \
    --drive-root-folder-id "${DEST_FOLDER_ID}" 2>/dev/null | grep -c '\.zip$' || echo 0)
  log "CTD zips on Shared Drive: ${ndz} (expect 244)"
fi
log "log: ${LOG_FILE}"
log "═══════════════════════════════════════════════════════════════════════"
exit 0
