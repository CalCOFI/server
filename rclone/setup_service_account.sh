#!/bin/bash
# setup_service_account.sh
# Configure the existing `calcofi-admin` service account to drive the automated
# GDrive → GCS sync (sync_gdrive_to_gcs.sh) from the server, unattended.
#
# A GCP service account can read a Google Drive *folder* simply by SHARING that
# folder with the SA's email — no Workspace domain-wide delegation required.
#
# usage:
#   ./setup_service_account.sh           # PLAN only: print steps, change nothing
#   ./setup_service_account.sh --apply   # create key, grant bucket IAM, add rclone remotes
#
# After running, you MUST manually share the Shared Drive folder with the SA
# email (step 3 below) — that is the one step gcloud cannot perform.

set -euo pipefail

# ─── configuration ────────────────────────────────────────────────────────────

PROJECT="ucsd-sio-calcofi"
SA_EMAIL="calcofi-admin@${PROJECT}.iam.gserviceaccount.com"
BUCKETS=(calcofi-files-public calcofi-files-private calcofi-db)
DRIVE_FOLDER_ID="1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW"   # "CalCOFI Data Folder"

# where to store the SA key (chmod 600). On a Linux server prefer /etc/rclone/.
KEY_FILE="${CALCOFI_SA_KEY:-${HOME}/.config/gcloud/calcofi-admin-sa.json}"
# expand a leading ~ (a quoted "~/..." is NOT expanded by the shell) and require
# an absolute path — otherwise a relative/tilde value makes mkdir + keys create
# write a stray "~/..." dir and MINT A NEW KEY under the current directory.
case "${KEY_FILE}" in "~/"*) KEY_FILE="${HOME}/${KEY_FILE#\~/}" ;; esac
case "${KEY_FILE}" in
  /*) : ;;
  *) echo "ERROR: CALCOFI_SA_KEY must be an absolute path (got: ${KEY_FILE})"; exit 1 ;;
esac

# rclone remotes this script will create (SA-based, for server automation)
GDRIVE_SA_REMOTE="gdrive-calcofi"     # Drive, scoped to the Shared Drive folder
GCS_SA_REMOTE="gcs-calcofi-sa"        # GCS, SA-authenticated

APPLY=false
[ "${1:-}" = "--apply" ] && APPLY=true

run() {  # echo, then run only with --apply
  echo "  \$ $*"
  if $APPLY; then "$@"; fi
}

echo "═══════════════════════════════════════════════════════════════════════"
echo "CalCOFI service-account setup  (mode: $([ $APPLY = true ] && echo APPLY || echo PLAN))"
echo "  project:    ${PROJECT}"
echo "  SA:         ${SA_EMAIL}"
echo "  key file:   ${KEY_FILE}"
echo "  drive folder: ${DRIVE_FOLDER_ID}"
echo "═══════════════════════════════════════════════════════════════════════"

command -v gcloud >/dev/null || { echo "ERROR: gcloud not installed"; exit 1; }
command -v rclone >/dev/null || { echo "ERROR: rclone not installed"; exit 1; }

# confirm the SA exists / is reachable
if $APPLY; then
  gcloud iam service-accounts describe "${SA_EMAIL}" --project "${PROJECT}" >/dev/null \
    || { echo "ERROR: cannot access SA ${SA_EMAIL} (need IAM rights in ${PROJECT})"; exit 1; }
fi

# ─── 1) create + download a JSON key ──────────────────────────────────────────
echo
echo "[1] create JSON key → ${KEY_FILE}"
if [ -f "${KEY_FILE}" ]; then
  echo "  key already exists at ${KEY_FILE} — skipping create (delete it to rotate)"
else
  echo "  will create a NEW key at ${KEY_FILE}"
  if $APPLY; then mkdir -p "$(dirname "${KEY_FILE}")"; fi
  run gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account "${SA_EMAIL}" --project "${PROJECT}"
  if $APPLY; then chmod 600 "${KEY_FILE}"; fi
fi

# ─── 2) grant Storage Object Admin on the three buckets ───────────────────────
echo
echo "[2] grant roles/storage.objectAdmin on buckets (idempotent)"
for b in "${BUCKETS[@]}"; do
  run gcloud storage buckets add-iam-policy-binding "gs://${b}" \
    --member "serviceAccount:${SA_EMAIL}" \
    --role "roles/storage.objectAdmin" \
    --project "${PROJECT}"
done

# ─── 3) MANUAL: share the Drive folder with the SA email ──────────────────────
cat <<EOF

[3] MANUAL STEP (gcloud cannot do this) — share the Shared Drive folder with the SA:
    open: https://drive.google.com/drive/folders/${DRIVE_FOLDER_ID}
    → Share → add:  ${SA_EMAIL}
    → role: "Content Manager" (write) for sync, or "Viewer" if GCS sync is read-only
    The SA then reads/writes the folder via rclone with no domain-wide delegation.
EOF

# ─── 4) create rclone remotes that use the SA key ─────────────────────────────
echo
echo "[4] create rclone remotes using the SA key"
echo "  - ${GDRIVE_SA_REMOTE}: Drive, scoped to the Shared Drive folder"
run rclone config create "${GDRIVE_SA_REMOTE}" drive \
  scope=drive \
  service_account_file="${KEY_FILE}" \
  root_folder_id="${DRIVE_FOLDER_ID}"
echo "  - ${GCS_SA_REMOTE}: GCS, SA-authenticated"
run rclone config create "${GCS_SA_REMOTE}" "google cloud storage" \
  project_number="${PROJECT}" \
  service_account_file="${KEY_FILE}" \
  bucket_policy_only=true

# ─── 5) verification ──────────────────────────────────────────────────────────
cat <<EOF

[5] VERIFY the SA key locally (after step 3 sharing has propagated, ~1 min):
    rclone lsf ${GDRIVE_SA_REMOTE}:data-public --max-depth 1
    rclone lsf ${GCS_SA_REMOTE}:calcofi-files-public --max-depth 1
    (steps 4-5 just confirm the key works; the scheduled sync runs in the
     rclone container on the server)

[6] DEPLOY on the server: copy this key to the VM and bring up the container —
    see rclone/README.md ("Deploy on the server"):
      gcloud compute scp ${KEY_FILE} \\
        shiny-server:/tmp/sa.json --zone us-central1-a --project ${PROJECT}
      # on VM: sudo install -m600 -D /tmp/sa.json /etc/rclone/calcofi-admin-sa.json

EOF

if $APPLY; then
  echo "APPLY done. Don't forget the MANUAL share in step 3."
else
  echo "PLAN only — nothing changed. Re-run with --apply to execute steps 1,2,4."
fi
