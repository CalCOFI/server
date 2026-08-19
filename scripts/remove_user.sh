#!/bin/bash
# remove_user.sh — OFFBOARD (lock, never delete data): host login locked + key removed,
# DB role NOLOGIN (objects they own stay), pgAdmin account deactivated, rstudio login locked.
#   sudo scripts/remove_user.sh <username>
set -euo pipefail
U=${1:?username}; CSV=/share/github/CalCOFI/server/users/users.csv
EMAIL=$(awk -F, -v u="$U" 'NR>1 && $1==u {print $4; exit}' "$CSV")
id "$U" >/dev/null 2>&1 && { usermod -L -s /usr/sbin/nologin "$U"; mv -f /home/$U/.ssh/authorized_keys /home/$U/.ssh/authorized_keys.revoked 2>/dev/null || true; echo "host: locked $U"; }
docker exec postgis psql -U admin -d postgres -qtAc "ALTER ROLE $U NOLOGIN" 2>/dev/null && echo "postgres: $U NOLOGIN" || true
[ -n "$EMAIL" ] && docker exec pgadmin /venv/bin/python3 /pgadmin4/setup.py update-user "$EMAIL" --inactive >/dev/null 2>&1 && echo "pgadmin: $EMAIL inactive" || true
docker exec rstudio id "$U" >/dev/null 2>&1 && docker exec rstudio usermod -L "$U" && echo "rstudio: locked $U" || true
echo "data kept: /home/$U, schema $U in calcofi, files in /share/data/ctd. Reverse with usermod -U / ALTER ROLE LOGIN / update-user --active."
