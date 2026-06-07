# rclone — GDrive ⇄ GCS sync

This `rclone` container (busybox `crond` + `rclone`) runs scheduled syncs:

| script | crontab | what |
|---|---|---|
| `backup.sh` | `30 0 * * *` | server `pg_backups/` → Google Drive `remote:db_backups` (existing) |
| `gdrive_to_gcs.sh public` | `0 2 * * *` | org Shared Drive **"CalCOFI Data Folder"** → `gs://calcofi-files-public/` with archive snapshots + manifest |

```
Shared Drive (CalCOFI org)              GCS data lake (ucsd-sio-calcofi)
data-public/                  ──►  gs://calcofi-files-public/_sync/
  calcofi/ctd-cast/download/*.zip        + archive/<ts>/  (changed/deleted files)
  bottle/ dic/ swfsc/ …                  + manifests/manifest_latest.json
        gdrive-calcofi:               gcs-calcofi-sa:
        (calcofi-admin SA — folder shared with its email; SA key mounted RO)
```

The sync authenticates as the **`calcofi-admin`** service account via a key file
— a headless server can't do interactive rclone OAuth, and the key also bypasses
the VM's default-SA `devstorage.read_only` scope, so GCS writes work with no VM
restart.

## Files

- `Dockerfile`, `crontab` — container build + schedule
- `backup.sh` — existing pg_backups → Drive (unchanged)
- `gdrive_to_gcs.sh` — Shared Drive → GCS sync (POSIX sh, container-native)
- `rclone.conf.example` — remotes to add to the live `/share/rclone/rclone.conf`
- `setup_service_account.sh` — **run on laptop**: create SA key + grant bucket IAM
- `migrate_gdrive_to_shared.sh` — **run on laptop, one-time**: personal Drive → Shared Drive

## One-time setup (on your laptop)

```bash
# 1. SA key + grant Storage Object Admin on the buckets.
#    already created a key (e.g. in the Cloud Console)? point the script at it —
#    step [1] then SKIPS creation, step [2] still grants bucket IAM:
#      export CALCOFI_SA_KEY="/path/to/<project>_<id>_calcofi-admin-sa.json"
#    otherwise it creates one at ~/.config/gcloud/calcofi-admin-sa.json
./setup_service_account.sh --apply

# 2. share the Drive folder with the SA (Drive UI → Share, Content Manager):
#    calcofi-admin@ucsd-sio-calcofi.iam.gserviceaccount.com
#    https://drive.google.com/drive/folders/1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW

# 3. migrate the data into the Shared Drive (~18 GiB / 629 files; CTD = zips only)
./migrate_gdrive_to_shared.sh --dry-run
./migrate_gdrive_to_shared.sh --execute
```

## Deploy on the server (`shiny-server`)

```bash
# A. put the SA key on the host BEFORE compose up (else Docker makes an empty dir).
#    use your key path (the on-VM filename stays calcofi-admin-sa.json regardless):
gcloud compute scp "${CALCOFI_SA_KEY:-$HOME/.config/gcloud/calcofi-admin-sa.json}" \
  shiny-server:/tmp/sa.json --zone us-central1-a --project ucsd-sio-calcofi
# on the VM:
sudo install -m600 -D /tmp/sa.json /etc/rclone/calcofi-admin-sa.json && rm -f /tmp/sa.json

# B. add the two remotes to the live config (keep the existing [remote] block)
sudo sh -c 'cat /share/github/CalCOFI/server/rclone/rclone.conf.example >> /share/rclone/rclone.conf'
sudo $EDITOR /share/rclone/rclone.conf      # sanity-check, dedupe

# C. rebuild + restart just the rclone container
cd /share/github/CalCOFI/server && git pull
docker compose up -d --build rclone

# D. verify remotes + do a dry run from inside the container
docker exec rclone rclone lsf gdrive-calcofi:data-public --max-depth 1
docker exec rclone rclone lsf gcs-calcofi-sa:calcofi-files-public --max-depth 1
docker exec rclone sh -c 'rclone sync gdrive-calcofi:data-public gcs-calcofi-sa:calcofi-files-public/_sync --dry-run -v'

# E. run the real sync once now (cron will then run it daily at 02:00)
docker exec rclone /gdrive_to_gcs.sh public
docker exec rclone tail -n 40 /share/logs/gdrive_to_gcs
```

The volume mount `/etc/rclone/calcofi-admin-sa.json:/config/rclone/calcofi-admin-sa.json:ro`
(in `docker-compose.yml`) is what makes the key available to the container.

## Notes

- `rclone.conf` and the SA key are **never** committed (kept on the host under
  `/share/rclone/` and `/etc/rclone/`).
- The SA key is a long-lived credential to **GCS *and* Drive** — keep it out of
  cloud-synced storage (prefer local `~/.config/gcloud/`, `chmod 600`) and rotate
  it periodically (`gcloud iam service-accounts keys list/delete`).
- `data-private/` is empty for now; its crontab line is commented out — enable it
  once the private bucket source exists.
- The CTD ingest auto-sources its zips from
  `gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/` once this sync
  populates it (chunk `prime_zips_from_gcs` in `workflows/ingest_calcofi_ctd-cast.qmd`).
