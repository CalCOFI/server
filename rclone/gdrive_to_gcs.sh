#!/bin/sh
# gdrive_to_gcs.sh — sync the org Shared Drive ("CalCOFI Data Folder") to the GCS
# data lake with timestamped archive snapshots + a manifest. Runs INSIDE the
# rclone container (alpine/busybox + rclone), scheduled from /etc/crontabs/root.
#
# remotes (in /config/rclone/rclone.conf, authed via the calcofi-admin SA key
# mounted at /config/rclone/calcofi-admin-sa.json — see rclone.conf.example):
#   gdrive-calcofi : drive, root_folder_id = CalCOFI Data Folder
#   gcs-calcofi-sa : google cloud storage
#
# usage: gdrive_to_gcs.sh [public|private]   (default: public)

set -e

BUCKET_TYPE="${1:-public}"
GDRIVE_REMOTE="gdrive-calcofi"
GCS_REMOTE="gcs-calcofi-sa"

case "$BUCKET_TYPE" in
  public)  GDRIVE_PATH="data-public";  GCS_BUCKET="calcofi-files-public"  ;;
  private) GDRIVE_PATH="data-private"; GCS_BUCKET="calcofi-files-private" ;;
  *) echo "usage: $0 [public|private]"; exit 1 ;;
esac

TS=$(date +%Y-%m-%d_%H%M%S)
SRC="${GDRIVE_REMOTE}:${GDRIVE_PATH}"
SYNC="${GCS_REMOTE}:${GCS_BUCKET}/_sync"
ARCHIVE="${GCS_REMOTE}:${GCS_BUCKET}/archive/${TS}"
MANIFESTS="${GCS_REMOTE}:${GCS_BUCKET}/manifests"

echo "[$(date '+%F %T')] gdrive->gcs ${BUCKET_TYPE}: ${SRC} -> ${SYNC} (archive ${TS})"

# sync; overwritten/deleted files are moved into the timestamped archive dir
# (immutable versioning), --checksum compares by hash not mtime/size.
rclone sync "${SRC}" "${SYNC}" \
  --checksum \
  --backup-dir "${ARCHIVE}" \
  --drive-export-formats csv \
  --exclude ".DS_Store" --exclude "*.tmp" --exclude "~*" \
  --transfers 8 --checkers 16 --drive-chunk-size 64M \
  --stats 30s --stats-one-line -v

# manifest of the current _sync state (raw rclone lsjson; no jq in container)
TMP="/tmp/manifest_${TS}.json"
rclone lsjson "${SYNC}" --recursive > "${TMP}"
rclone copyto "${TMP}" "${MANIFESTS}/manifest_${TS}.json"
rclone copyto "${TMP}" "${MANIFESTS}/manifest_latest.json"
rm -f "${TMP}"

# drop the archive dir if this run changed nothing (kept lean)
if rclone lsf "${ARCHIVE}" 2>/dev/null | grep -q .; then
  echo "[$(date '+%F %T')] done — changes archived at archive/${TS}"
else
  rclone rmdir "${ARCHIVE}" 2>/dev/null || true
  echo "[$(date '+%F %T')] done — no changes"
fi
