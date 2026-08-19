One `<username>.pub` per person — the single line from their `~/.ssh/id_ed25519.pub`
(`ssh-ed25519 AAAA… comment`). `add_user.sh` installs it into `~/.ssh/authorized_keys`
(appending; re-running with a second key adds it). Ben's key is not here: `bebest` predates
this registry and keeps its existing authorized_keys.
