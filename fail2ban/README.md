# fail2ban

`jail.local` is the deployed config. It is **not** bind-mounted — fail2ban runs on
the host, not in a container — so a change here has to be copied and the service
restarted:

```bash
ssh calcofi
cd /share/github/CalCOFI/server && git pull
sudo cp fail2ban/jail.local /etc/fail2ban/jail.local
sudo fail2ban-client -t            # ALWAYS test before restarting
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

Installed 2026-09-08 (`fail2ban 1.0.2-2`, Debian bookworm). It banned two
scanners within seconds of first start.

## Why fail2ban and not a firewall rule

sshd is key-only (`PasswordAuthentication no`, `PermitRootLogin no`), so the
constant brute-force traffic in the journal **cannot succeed** — it is log noise,
not exposure. Restricting port 22 by source range was considered and rejected:
collaborators SSH/SFTP in from dynamic residential and field addresses, so an
allowlist locks out the people who need access, and IAP tunnelling would break
their SFTP. See README "Security posture".

## Unbanning someone

Legitimate users authenticate by key and generate no auth failures, so they
should never be banned. A user with a missing or wrong key can trip it — the ban
is 1 h and self-heals, or lift it now:

```bash
sudo fail2ban-client set sshd unbanip <IP>
sudo fail2ban-client get sshd banned      # current list
```

If someone reports being locked out, check that list **before** assuming the
outage is something else.
