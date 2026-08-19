# Server user accounts

`users.csv` is the registry; `keys/<username>.pub` holds each person's SSH **public** key
(public keys are safe in git — never commit a private key). `scripts/add_user.sh` turns a
row into: a host login (SSH/SFTP, key-only), membership of group `calcofi` (shared
`/share/data/ctd`), a PostgreSQL login role in the `calcofi` database with the group roles
listed in `pg_roles`, a personal schema, `~/.pgpass` on the server holding the generated DB
password, the same password on their pgAdmin account (until Google sign-in is enabled), and —
when `rstudio=yes` — the mirrored account inside the `rstudio` container so
rstudio.calcofi.io works with `host = "postgis"` and no tunnel.

| column | meaning |
|---|---|
| `username` | email local-part (Betty: `bhuang`, not `bhuang0022`); also the DB role name and the personal schema |
| `uid` | fixed, so host and container agree on file ownership under `/share` (1001–1003 are Marina/Ed/Ben from 2022; OS Login users have huge uids) |
| `pg_roles` | semicolon list of group roles: `calcofi_writer` (scratch + propose flags), `calcofi_curator` (+ accept/reject), `calcofi_admin` (Ben) |
| `rstudio` | `yes` = also create the account inside the rstudio container (remember to add the row to `rstudio/users.csv` so an image rebuild recreates it) |

```bash
# on the server (sudo):
sudo /share/github/CalCOFI/server/scripts/add_user.sh --dry-run rswalethorp
sudo /share/github/CalCOFI/server/scripts/add_user.sh rswalethorp
sudo /share/github/CalCOFI/server/scripts/add_user.sh --all          # every row, idempotent
sudo /share/github/CalCOFI/server/scripts/remove_user.sh kdvogel     # lock (never deletes data)
```

How the secret reaches the person without email: they SSH in and `cat ~/.pgpass` — the
last field is their database password. They copy that line into their laptop's `~/.pgpass`
(Windows: `%APPDATA%\postgresql\pgpass.conf`) and everything (psql, R, Python, DuckDB,
pgAdmin desktop) authenticates without ever typing it. `psql -c '\password'` rotates it.
User-facing instructions: https://calcofi.io/docs/server-access.html
