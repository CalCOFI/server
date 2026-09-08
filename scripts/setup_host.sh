#!/usr/bin/env bash
# setup_host.sh — provision the HOST-level pieces that are not in Docker.
#
# Everything that serves traffic runs in a container from docker-compose.yml, so
# a rebuilt VM gets it back with `docker compose up`. A handful of things run on
# the host itself and are therefore invisible to that: they live here so a
# rebuild does not silently lose them.
#
# Idempotent and safe to re-run — re-running is also how you re-assert config
# after someone edits a file on the box instead of in git.
#
#   ssh calcofi
#   cd /share/github/CalCOFI/server && git pull
#   sudo ./scripts/setup_host.sh
#
# Host-level inventory (add to this list, and to this script, when it grows):
#   - fail2ban        this script
#   - root crontab    README "Database backups (current)" — not yet scripted
#   - user accounts   scripts/add_user.sh
#   - docker + git    README "Install docker & git" — one-time, at VM creation
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
say() { echo "[$(ts)] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0" >&2
  exit 1
fi

# ── fail2ban ────────────────────────────────────────────────────────────────
# Added 2026-09-08. sshd is key-only, so the constant brute-force traffic cannot
# succeed — this is about log noise, not exposure — and a port-22 source
# allowlist was rejected because collaborators connect from dynamic residential
# and field addresses. See README "Security posture" and fail2ban/README.md.
say "fail2ban: checking"

if ! dpkg -s fail2ban >/dev/null 2>&1; then
  say "fail2ban: installing"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban
else
  say "fail2ban: already installed ($(dpkg-query -W -f='${Version}' fail2ban))"
fi

src="$REPO/fail2ban/jail.local"
dst=/etc/fail2ban/jail.local
[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }

if ! cmp -s "$src" "$dst"; then
  say "fail2ban: config differs from git, installing $src -> $dst"
  install -m 0644 "$src" "$dst"
  changed=1
else
  say "fail2ban: config already matches git"
  changed=0
fi

# Validate BEFORE restarting: a bad jail that fails to start leaves the host with
# no protection, and a bad filter regex can ban legitimate users.
say "fail2ban: validating config"
fail2ban-client -t >/dev/null

systemctl enable --quiet fail2ban
if [ "$changed" = 1 ] || ! systemctl is-active --quiet fail2ban; then
  say "fail2ban: restarting"
  systemctl restart fail2ban
  sleep 3
fi

say "fail2ban: active=$(systemctl is-active fail2ban) enabled=$(systemctl is-enabled fail2ban)"
fail2ban-client status sshd | sed 's/^/    /'

say "done. If a user reports being locked out, check the banned list above and:"
say "  fail2ban-client set sshd unbanip <IP>"
