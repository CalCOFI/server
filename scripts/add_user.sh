#!/bin/bash
# add_user.sh — provision one person (or --all) from users/users.csv. Idempotent; re-run
# freely (adds a new key, re-grants roles, never overwrites an existing DB password).
#   sudo scripts/add_user.sh [--dry-run] [--no-rstudio] <username> | --all
# Creates / ensures:
#   host   : group calcofi (gid 1500); user <uid>, primary group calcofi, bash, home;
#            ~/.ssh/authorized_keys from users/keys/<username>.pub; ~/share ~/data ~/ctd links;
#            NO sudo, NO docker group (docker == root) — decision D12
#   postgres: LOGIN role <username> IN ROLE <pg_roles> (calcofi db); personal schema;
#            default privileges so what they create in work/ and their schema is shared;
#            generated password -> ~/.pgpass (localhost + postgis lines), mode 600
#   pgadmin : the pgAdmin account (email) gets the same password (internal auth);
#            irrelevant once Google sign-in is on
#   rstudio : (rstudio=yes) same uid/username inside the rstudio container, groups
#            staff+calcofi, RStudio password = same password, same links, ~/.pgpass
# Secrets never leave the server: the person reads ~/.pgpass after their first SSH login.
set -euo pipefail
REPO=/share/github/CalCOFI/server
CSV=$REPO/users/users.csv
KEYS=$REPO/users/keys
GROUP=calcofi; GID=1500
CTD_DIR=/share/data/ctd
DRY=false; RSTUDIO=true; TARGETS=()
for a in "$@"; do case "$a" in
  --dry-run) DRY=true;; --no-rstudio) RSTUDIO=false;;
  --all) TARGETS=($(tail -n +2 "$CSV" | cut -d, -f1));;
  -*) echo "unknown flag $a"; exit 2;; *) TARGETS+=("$a");; esac; done
[ ${#TARGETS[@]} -gt 0 ] || { echo "usage: $0 [--dry-run] [--no-rstudio] <username>|--all"; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 2; }
run() { if $DRY; then echo "  [dry] $*"; else eval "$@"; fi; }
psql_c() { docker exec -i postgis psql -U admin -d "$1" -v ON_ERROR_STOP=1 -qtA -c "$2"; }
genpw() { openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 24; }

# ---- shared prerequisites ------------------------------------------------------------------
getent group $GROUP >/dev/null || run "groupadd -g $GID $GROUP"
if [ ! -d $CTD_DIR ]; then
  run "mkdir -p $CTD_DIR/incoming $CTD_DIR/archive $CTD_DIR/exports"
  run "chown -R root:$GROUP $CTD_DIR && chmod 2775 $CTD_DIR $CTD_DIR/incoming $CTD_DIR/archive $CTD_DIR/exports"
fi
if [ ! -f /etc/profile.d/calcofi.sh ]; then
  run "printf '%s\n' '# members of calcofi share /share/data/ctd: make new files group-writable' 'if id -nG 2>/dev/null | grep -qw calcofi; then umask 002; fi' > /etc/profile.d/calcofi.sh"
fi

for U in "${TARGETS[@]}"; do
  row=$(awk -F, -v u="$U" 'NR>1 && $1==u {print; exit}' "$CSV")
  [ -n "$row" ] || { echo "!! $U not in $CSV"; continue; }
  IFS=, read -r _ UID_ FULL EMAIL PGROLES RS <<<"$row"
  echo "== $U (uid $UID_, $FULL <$EMAIL>, roles: $PGROLES, rstudio: $RS)"

  # ---- host account ------------------------------------------------------------------------
  if id "$U" >/dev/null 2>&1; then
    echo "  host user exists (uid $(id -u "$U")); ensuring group membership"
    run "usermod -aG $GROUP $U"
  else
    run "useradd -m -u $UID_ -g $GROUP -s /bin/bash -c \"$FULL\" $U"
  fi
  HOME_=/home/$U
  if [ -f "$KEYS/$U.pub" ]; then
    run "mkdir -p $HOME_/.ssh && chmod 700 $HOME_/.ssh && touch $HOME_/.ssh/authorized_keys"
    while read -r key; do
      [ -n "$key" ] || continue
      if ! $DRY && grep -qF "$key" $HOME_/.ssh/authorized_keys 2>/dev/null; then echo "  key already installed"; else run "echo '$key' >> $HOME_/.ssh/authorized_keys"; fi
    done < "$KEYS/$U.pub"
    run "chmod 600 $HOME_/.ssh/authorized_keys && chown -R $U:$GROUP $HOME_/.ssh"
  else
    echo "  !! no $KEYS/$U.pub yet — account created, SSH will not work until the key is added"
  fi
  for l in "share:/share" "data:/share/data" "ctd:$CTD_DIR"; do
    n=${l%%:*}; t=${l#*:}; [ -L $HOME_/$n ] || run "ln -s $t $HOME_/$n && chown -h $U:$GROUP $HOME_/$n"
  done

  # ---- postgres role + schema + .pgpass ----------------------------------------------------
  PW=""
  if [ -f $HOME_/.pgpass ] && grep -q ":$U:" $HOME_/.pgpass; then
    PW=$(grep ":$U:" $HOME_/.pgpass | head -1 | awk -F: '{print $5}')
    echo "  existing ~/.pgpass found — keeping that password"
  fi
  [ -n "$PW" ] || PW=$(genpw)
  IN_ROLE=$(echo "$PGROLES" | tr ';' ',')
  if [ "$(psql_c postgres "SELECT 1 FROM pg_roles WHERE rolname='$U'")" = "1" ]; then
    echo "  pg role exists; re-granting $IN_ROLE"
    for r in ${IN_ROLE//,/ }; do run "psql_c postgres \"GRANT $r TO $U\""; done
    # password only (re)set when we had to generate one (no .pgpass on disk)
    grep -q ":$U:" $HOME_/.pgpass 2>/dev/null || run "psql_c postgres \"ALTER ROLE $U PASSWORD '$PW'\""
  else
    run "psql_c postgres \"CREATE ROLE $U LOGIN PASSWORD '$PW' IN ROLE $IN_ROLE\""
  fi
  run "psql_c calcofi \"CREATE SCHEMA IF NOT EXISTS $U AUTHORIZATION $U\""
  run "psql_c calcofi \"GRANT USAGE ON SCHEMA $U TO calcofi_reader\""
  # what this person creates is shared: readable by all readers, writable by writers in work
  run "psql_c calcofi \"ALTER DEFAULT PRIVILEGES FOR ROLE $U IN SCHEMA $U GRANT SELECT ON TABLES TO calcofi_reader\""
  run "psql_c calcofi \"ALTER DEFAULT PRIVILEGES FOR ROLE $U IN SCHEMA work GRANT ALL ON TABLES TO calcofi_writer\""
  run "psql_c calcofi \"ALTER DEFAULT PRIVILEGES FOR ROLE $U IN SCHEMA work GRANT ALL ON SEQUENCES TO calcofi_writer\""
  run "psql_c calcofi \"ALTER DEFAULT PRIVILEGES FOR ROLE $U IN SCHEMA work GRANT SELECT ON TABLES TO calcofi_reader\""
  if ! grep -q ":$U:" $HOME_/.pgpass 2>/dev/null; then
    # append (a pre-existing .pgpass with other entries is kept), then lock it down
    [ -f $HOME_/.pgpass ] || run "printf '%s\n' '# host:port:database:user:password — the last field is your CalCOFI database password' > $HOME_/.pgpass"
    run "printf '%s\n' 'localhost:5432:*:$U:$PW' 'postgis:5432:*:$U:$PW' >> $HOME_/.pgpass && chmod 600 $HOME_/.pgpass && chown $U:$GROUP $HOME_/.pgpass"
  fi

  # ---- pgadmin (internal account; same password) -------------------------------------------
  if docker exec pgadmin /venv/bin/python3 /pgadmin4/setup.py get-users --json 2>/dev/null | grep -q "\"$EMAIL\""; then
    run "docker exec pgadmin /venv/bin/python3 /pgadmin4/setup.py update-user '$EMAIL' --password '$PW' >/dev/null"
  else
    run "docker exec pgadmin /venv/bin/python3 /pgadmin4/setup.py add-user '$EMAIL' '$PW' --role User >/dev/null"
  fi

  # ---- rstudio container mirror -------------------------------------------------------------
  if $RSTUDIO && [ "$RS" = "yes" ]; then
    R="docker exec rstudio"
    $R getent group $GROUP >/dev/null 2>&1 || run "$R groupadd -g $GID $GROUP"
    if $R id "$U" >/dev/null 2>&1; then
      echo "  rstudio user exists; ensuring groups"
    else
      run "$R useradd -m -u $UID_ -g staff -s /bin/bash -c \"$FULL\" $U"
      if ! $DRY; then
        docker exec rstudio mkdir -p /home/$U/.config/rstudio
        docker exec -i rstudio sh -c "cat > /home/$U/.config/rstudio/rstudio-prefs.json" <<'JSON'
{"save_workspace":"never","always_save_history":false,"posix_terminal_shell":"bash","initial_working_directory":"~","insert_native_pipe_operator":true,"rainbow_parentheses":true}
JSON
      fi
      for l in "share:/share" "data:/share/data" "ctd:$CTD_DIR" "github:/share/github" "shiny-apps:/srv/shiny-server"; do
        n=${l%%:*}; t=${l#*:}; run "$R ln -sfn $t /home/$U/$n"; done
    fi
    run "$R usermod -aG staff,$GROUP $U"
    run "$R sh -c \"echo '$U:$PW' | chpasswd\""
    run "$R sh -c \"printf '%s\n' 'postgis:5432:*:$U:$PW' 'localhost:5432:*:$U:$PW' > /home/$U/.pgpass && chmod 600 /home/$U/.pgpass\""
    run "$R chown -R $U:staff /home/$U"
  fi
  echo "  ok: $U  (DB role + ~/.pgpass on host$( [ "$RS" = yes ] && $RSTUDIO && echo ' + rstudio'); pgAdmin $EMAIL)"
done
echo "done. remind people: ssh in, 'cat ~/.pgpass' is their database password; docs: https://calcofi.io/docs/server-access.html"
