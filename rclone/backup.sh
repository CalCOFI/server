#!/bin/sh

set -e # exit on error
rclone sync /share/pg_backups remote:db_backups
