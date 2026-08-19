#!/bin/bash
# setup_backup_bucket.sh — create/verify the PRIVATE backup bucket gs://calcofi-backups.
# Run from a laptop with gcloud auth (bebest@ucsd.edu). Idempotent; prints and re-applies.
# Done once on 2026-08-19; kept so the configuration is reproducible and reviewable.
#
# Layout (written by rclone/backup.sh, scripts/pg_restore_drill.sh, scripts/pg_upgrade_18.sh):
#   postgres/daily|weekly|monthly/   mirror of /share/pg_backups rotation (sync: deletes follow)
#   postgres/manual/<date>/          pre-upgrade and ad-hoc dumps (globals.sql + <db>.dump -Fc)
#   postgres/legacy-2022/            the two 2022 .sql dumps that used to sit in PUBLIC gs://calcofi-db/
#   postgres/legacy-2024/            /share/pg_backups/_old (four 2024 .dump files)
#   postgres/_status/                last_success.json, last_drill.json
#   pgadmin/                         pgadmin4.db copies (users, shared servers)
#   server-config/                   .env + rclone.conf, age-encrypted (TODO when WS2 lands)
#
# Safety properties:
#   - public access prevention ENFORCED + uniform bucket-level access (no per-object ACLs)
#   - Object Versioning ON, lifecycle deletes NONCURRENT versions after 90 days → an `rclone
#     sync` delete or an overwrite is recoverable for 3 months
#   - monthly/manual/legacy objects move to NEARLINE at 30 days (they are rarely read)
#   - the calcofi-admin SA (used by the rclone container) has objectAdmin on THIS bucket only;
#     it cannot list buckets project-wide, which is fine
set -euo pipefail
PROJECT=ucsd-sio-calcofi
BUCKET=gs://calcofi-backups
SA=calcofi-admin@${PROJECT}.iam.gserviceaccount.com
LIFECYCLE=$(mktemp)
cat > "$LIFECYCLE" <<'JSON'
{
  "rule": [
    {"action": {"type": "Delete"}, "condition": {"daysSinceNoncurrentTime": 90}},
    {"action": {"type": "AbortIncompleteMultipartUpload"}, "condition": {"age": 7}},
    {"action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
     "condition": {"age": 30, "matchesPrefix": ["postgres/monthly/", "postgres/manual/", "postgres/legacy-2022/", "postgres/legacy-2024/"]}}
  ]
}
JSON

if ! gcloud storage buckets describe "$BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
  gcloud storage buckets create "$BUCKET" --project "$PROJECT" --location us-central1 \
    --default-storage-class STANDARD --uniform-bucket-level-access --public-access-prevention
fi
gcloud storage buckets update "$BUCKET" --project "$PROJECT" --versioning --lifecycle-file="$LIFECYCLE"
gcloud storage buckets add-iam-policy-binding "$BUCKET" --project "$PROJECT" \
  --member "serviceAccount:${SA}" --role roles/storage.objectAdmin >/dev/null
gcloud storage buckets describe "$BUCKET" --project "$PROJECT" \
  --format="yaml(name,location,public_access_prevention,uniform_bucket_level_access,versioning_enabled,lifecycle_config)"
rm -f "$LIFECYCLE"
echo "ok: $BUCKET"
