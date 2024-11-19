#!/bin/sh

set -e # exit on error
rclone sync --dry-run /share/pg_backups remote:db_backups
