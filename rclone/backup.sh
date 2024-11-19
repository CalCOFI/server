#!/bin/sh

set -e # exit on error

# sync database backups to google drive
rclone sync -v /share/pg_backups remote:db_backups
