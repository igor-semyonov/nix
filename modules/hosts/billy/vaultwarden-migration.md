# Vaultwarden migration — fid (Postgres) → billy (SQLite)

Decision and rationale in `plan.md`. This is the execution detail.

## Version parity — no action needed

fid runs 1.37.0, nixpkgs ships 1.37.1. Their migration sets are **identical**:

    1.37.0  sqlite=56  postgresql=46
    1.37.1  sqlite=56  postgresql=46
    diff of migration names → identical

So the schemas already match. Do not downgrade billy to match fid, and do not
bother updating fid. If a gap ever does appear, upgrade the **source** forward —
diesel migrations are one-way, and loading into an older schema drops columns.

## Schema facts

27 tables. Type mapping that matters:

| Postgres    | SQLite     | count | handling                        |
| ----------- | ---------- | ----: | ------------------------------- |
| `UUID`      | `TEXT`     |   183 | direct string copy              |
| `TIMESTAMP` | `DATETIME` |    37 | **format-sensitive**, see below |
| `BOOLEAN`   | `BOOLEAN`  |    16 | `t`/`f` → `1`/`0`               |
| `BYTEA`     | `BLOB`     |     4 | **highest risk**, see below     |

The 4 `BYTEA` columns are `users.password_hash`, `users.salt`,
`sends.password_hash`, `sends.password_salt`. `users.password_hash` and
`users.salt` are the master-password verifier — corrupt them and nobody can log
in, with no error until first login attempt. Verify these explicitly.

**Foreign keys do not block the load.** SQLite defaults `foreign_keys` to OFF
per connection, so insert order will not cause failures. Order the load anyway
(below) and then _verify_ with `PRAGMA foreign_key_check`, which catches
orphaned rows that a permissive load would silently accept.

Dependency order, derived from `REFERENCES` in the migrations:

1. `users`, `organizations`, `invitations`, `sso_auth`, `twofactor_duo_ctx`
2. `ciphers`, `collections`, `folders`, `devices`, `twofactor`, `sso_users`,
   `auth_requests`, `emergency_access`, `groups`, `org_policies`,
   `organization_api_key`, `sends`, `twofactor_incomplete`
3. `attachments`, `users_organizations`, `ciphers_collections`,
   `folders_ciphers`, `users_collections`, `collections_groups`, `archives`,
   `favorites`
4. `event`, `groups_users`

## Keep the hostname — do not move to `vault.nalgor.com`

WebAuthn credentials are bound to the Relying Party ID, which Vaultwarden
derives from `DOMAIN` (`src/api/core/two_factor/webauthn.rs:36`):

```rust
let rp_id = Url::parse(&domain).map(|u| u.domain().map(str::to_owned))...
let webauthn = WebauthnBuilder::new(&rp_id, &rp_origin)
```

`https://vault.nalgor.net` yields `rp_id = vault.nalgor.net`. Move users to
`vault.nalgor.com` and every registered FIDO2 key and passkey stops working —
the credential is cryptographically scoped to the old RP ID. This is the
WebAuthn spec, not something Vaultwarden can be configured around.

Of the 2FA types (`two_factor.rs:29-38`) — `Authenticator`, `Email`, `Duo`,
`YubiKey`, `Webauthn`, `RecoveryCode`, `OrganizationDuo` — only **Webauthn** is
domain-bound. The rest are secrets in the `twofactor` table and survive intact.

`nalgor.net` is staying (it is on billy's mail-domain list), so **keep
`vault.nalgor.net` and repoint its DNS at billy**. Users then change nothing:
no server URL edit, no re-enrolling 2FA, no instructions to send.

Confirmed from fid's nginx — the vhost proxying to `127.0.0.1:7080` is
`server_name vault.nalgor.net`. So `DOMAIN` on billy must be exactly
`https://vault.nalgor.net`: same scheme, same host, port 443. The origin is
checked at assertion time as well as the RP ID.

Repointing DNS is **necessary but not sufficient**. It only removes the
unfixable failure mode. Still required:

- the `twofactor` rows must migrate intact — WebAuthn credentials are stored
  there as `atype = 7`; the right RP ID with missing rows still fails
- billy needs a valid cert for `vault.nalgor.net` before cutover
- everything else in this document, unchanged

For a parallel verification window, run billy on a throwaway name such as
`vault-new.nalgor.net`, confirm the data, then set `DOMAIN` to the real value
and cut DNS. Do not register WebAuthn against the throwaway name — those
credentials would be bound to the wrong RP ID and thrown away at cutover.

## Why JSON export/import is not an option

Ruled out on four independent counts, any one of which is disqualifying:

- **Other users will not do it.** It is a per-user manual step.
- **Organizations** do not survive — org keys, collections, and membership are
  not represented in a personal vault export.
- **MFA enrolments are lost.** TOTP secrets, YubiKey registrations, and recovery
  codes live in `twofactor`; an export does not carry them, so every user
  re-enrols.
- **Attachments** are absent from the export.

DB-level migration is the only path that preserves an identical experience.

## Pre-flight (on fid, read-only)

Scope the job:

    sudo ls /root/vaultwarden/vw-data/attachments | wc -l
    sudo du -sh /root/vaultwarden/vw-data

Capture baselines to compare against afterwards:

    sudo -u postgres psql -d <vwdb> -c "\dt"
    sudo -u postgres psql -d <vwdb> -tAc \
      "select relname, n_live_tup from pg_stat_user_tables order by relname;"

Record the DB name from fid's `/root/vaultwarden/.env` (`DATABASE_URL`). Do not
copy any other value out of that file — re-key the admin token into sops.

## Procedure

**1. Create the SQLite schema by letting Vaultwarden do it.** Do not hand-write
DDL — diesel must record its own migration state.

    # on billy, with services.vaultwarden enabled, dbBackend = "sqlite"
    systemctl start vaultwarden && sleep 5 && systemctl stop vaultwarden
    ls -la /var/lib/vaultwarden/db.sqlite3

**2. Quiesce the source.** `docker stop vaultwarden` on fid. Everything after
this is against a static database.

**3. Copy the data.** Prefer an explicit script over `pg_dump` text munging —
27 tables with 4 binary columns and 37 timestamps is exactly where `sed` on
dump output goes wrong silently. Roughly:

```python
import psycopg, sqlite3, datetime
ORDER = [...]  # the four tiers above, flattened
pg = psycopg.connect("postgresql://...")     # read-only role
lite = sqlite3.connect("/var/lib/vaultwarden/db.sqlite3")

def conv(v):
    if isinstance(v, bool):            return 1 if v else 0
    if isinstance(v, memoryview):      return sqlite3.Binary(bytes(v))
    if isinstance(v, bytes):           return sqlite3.Binary(v)
    if isinstance(v, datetime.datetime): return v.strftime("%Y-%m-%d %H:%M:%S%.f")
    return v

for t in ORDER:
    cur = pg.execute(f"SELECT * FROM {t}")
    cols = [d[0] for d in cur.description]
    rows = [[conv(v) for v in r] for r in cur.fetchall()]
    if rows:
        ph = ",".join("?" * len(cols))
        lite.executemany(f'INSERT INTO {t} ({",".join(cols)}) VALUES ({ph})', rows)
lite.commit()
```

**4. Confirm the timestamp format before trusting the bulk load.** Diesel's
SQLite backend stores `NaiveDateTime` as TEXT, and the exact format must match
what Vaultwarden writes or dates read back wrong. Verify empirically rather than
assuming: let the fresh instance create one record natively (register a throwaway
user), inspect it, and match that format exactly.

    sqlite3 /var/lib/vaultwarden/db.sqlite3 "select created_at from users limit 1;"

Delete the throwaway user before the real load.

**5. Copy `vw-data`.**

    rsync -av fid:/root/vaultwarden/vw-data/ /var/lib/vaultwarden/

Attachments are files on disk referenced by rows in `attachments`; both halves
must arrive or the vault shows entries that fail to download. `rsa_key.pem`
signs JWTs — losing it forces re-login but loses no data.

## Verification — before cutting DNS

    # structural
    sqlite3 /var/lib/vaultwarden/db.sqlite3 "PRAGMA foreign_key_check;"   # must be empty
    sqlite3 /var/lib/vaultwarden/db.sqlite3 "PRAGMA integrity_check;"     # must say ok

    # row parity against the baseline captured in pre-flight
    for t in $(sqlite3 /var/lib/vaultwarden/db.sqlite3 ".tables"); do
      printf "%-24s %s\n" "$t" "$(sqlite3 /var/lib/vaultwarden/db.sqlite3 "select count(*) from $t;")"
    done

    # the binary columns actually survived — every user must show non-zero
    sqlite3 /var/lib/vaultwarden/db.sqlite3 \
      "select email, length(password_hash), length(salt) from users;"

    # multi-user / org structure
    sqlite3 /var/lib/vaultwarden/db.sqlite3 "
      select 'users',        count(*) from users
      union all select 'orgs',         count(*) from organizations
      union all select 'memberships',  count(*) from users_organizations
      union all select 'collections',  count(*) from collections
      union all select 'user_colls',   count(*) from users_collections
      union all select 'ciphers',      count(*) from ciphers
      union all select 'attachments',  count(*) from attachments;"

    # 2FA enrolments, by type and user
    sqlite3 /var/lib/vaultwarden/db.sqlite3 "
      select u.email, t.atype, t.enabled from twofactor t
      join users u on u.uuid = t.user_uuid order by u.email, t.atype;"

`atype` maps to `two_factor.rs`: 0 Authenticator, 1 Email, 2 Duo, 3 YubiKey,
7 Webauthn, 8 RecoveryCode. Every row present on fid must be present here — a
missing row means that user silently loses their second factor at first login.

Non-zero, consistent lengths on `password_hash`/`salt` are the signal the BYTEA
transfer worked. Then functionally, and **not only as yourself** — the failure
modes are per-user and per-org:

- log in with the real master password (proves the verifier survived)
- complete a TOTP challenge, and a WebAuthn challenge if anyone uses one
- open an org-owned entry and confirm collection visibility is unchanged
- download an attachment
- have at least one other user do the same before cutover

## Cutover and rollback

Keep fid's container stopped but intact. Cutover is repointing
`vault.nalgor.net` at billy — not a URL change for users. Rollback is: revert
DNS, `docker start vaultwarden` on fid. Nothing on fid is destroyed by this
procedure, so rollback stays available until you choose to tear it down.

Because the hostname does not change, clients reconnect on their own and no
user action or announcement is required. If anything is wrong, reverting DNS
puts everyone back on fid with no client-side cleanup.

Enable `backupDir` (outside `dataDir`, e.g. `/var/lib/vaultwarden-backup`) once
migrated — `sqlite3 .backup` gives a consistent copy that btrbk then snapshots,
which is stronger than snapshotting the live WAL database.
