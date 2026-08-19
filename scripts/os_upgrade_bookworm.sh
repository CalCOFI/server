#!/bin/bash
# os_upgrade_bookworm.sh — in-place Debian 11 (bullseye) → 12 (bookworm) on shiny-server,
# plus Docker Engine / Compose plugin from Docker's repo. Run ONCE, as root, detached:
#   sudo nohup /share/github/CalCOFI/server/scripts/os_upgrade_bookworm.sh >/dev/null 2>&1 &
#   tail -f /share/logs/os_upgrade_bookworm.log      # ends with "== DONE"; then reboot
# Why: bullseye LTS ended 2026-08-31 and five new SSH accounts were about to be handed out
# (plan 2026-08-17, CTD team PostgreSQL, WS9). Disk snapshots shiny-server-pre-pg18-20260817 /
# ssd-pre-pg18-20260817 are the rollback.
# Non-interactive: keeps EXISTING config files on conflict (--force-confold) — in particular
# /etc/ssh/sshd_config, which the Google guest agent manages for OS Login.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
LOG=/share/logs/os_upgrade_bookworm.log
MARK=/share/logs/os_upgrade_bookworm.DONE
exec >>"$LOG" 2>&1
rm -f "$MARK"
step() { echo; echo "== [$(date -u +%FT%TZ)] $*"; }

step "phase 0: bring bullseye current"
apt-get update || echo "WARN: apt-get update returned $? (continuing)"
$APT upgrade        || { echo "FATAL phase0 upgrade"; exit 1; }
$APT full-upgrade   || { echo "FATAL phase0 full-upgrade"; exit 1; }
apt-get -y autoremove --purge

step "phase 1: point every source at bookworm"
cp -a /etc/apt/sources.list /etc/apt/sources.list.bullseye.bak
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
for f in docker.list gce_sdk.list google-cloud-ops-agent.list google-cloud.list; do
  [ -f /etc/apt/sources.list.d/$f ] && cp -a /etc/apt/sources.list.d/$f /etc/apt/sources.list.d/$f.bullseye.bak \
    && sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/$f
done
# .bak files must not be read by apt
mkdir -p /root/apt-bak && mv /etc/apt/sources.list.d/*.bullseye.bak /root/apt-bak/ 2>/dev/null || true
grep -h "^deb" /etc/apt/sources.list /etc/apt/sources.list.d/*.list
apt-get update || { echo "FATAL: apt-get update on bookworm sources failed"; exit 1; }

step "phase 2: minimal upgrade (no new packages)"
$APT upgrade --without-new-pkgs || { echo "FATAL phase2"; exit 1; }

step "phase 3: full upgrade"
$APT full-upgrade || { echo "FATAL phase3"; exit 1; }
apt-get -y autoremove --purge
apt-get clean

step "result"
cat /etc/os-release | head -3
dpkg -l | awk '/docker-ce |docker-compose-plugin|containerd.io|google-guest-agent|google-compute-engine-oslogin/ {print $2, $3}'
[ -f /var/run/reboot-required ] && echo "reboot-required: yes" || echo "reboot-required: (file absent — reboot anyway for the new kernel)"
echo "== DONE $(date -u +%FT%TZ)"
touch "$MARK"
