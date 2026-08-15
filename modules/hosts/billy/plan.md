# billy — plan

Vultr VPS, 1 vCPU / 964 MiB, BIOS boot, `/dev/vda` 32G + `/dev/vdb` 10G.
Config in `modules/hosts/billy/{config,disk,checks}.nix`. Reinstall procedure in
`reinstall.md`. Deploy with `just billy-test` (reboot-recoverable) then `just billy`.

## Goals

1. Stalwart mail server
2. AWS SES for outbound delivery
3. Vaultwarden on billy
4. Migrate the existing Vaultwarden off `fid` (Gentoo, Docker + host Postgres)
5. _Optional:_ migrate mail off `fid`
6. WireGuard between billy and boxy, with preshared keys
7. Tighten the firewall — SSH only over WireGuard
8. Consolidate all DNS onto Cloudflare (`nalgor.net`, `semyonov.xyz`,
   `semyonov.dev` still elsewhere), proxied where appropriate

Sections below are ordered by dependency, not by goal number.

---

## Done

**Reinstalled from scratch** via nixos-anywhere from a Vultr NixOS ISO. kexec
OOM'd twice on 964 MiB (425 MB initrd + ~286 MB running system); the live-env
route sidesteps it entirely. SSH host keys carried across with `--extra-files`,
so billy's age identity — and therefore sops — survived the wipe.

**Disks** — hybrid BIOS+UEFI: 2 MiB EF02 + 1 GiB vfat ESP at `/boot` + 31 GiB
btrfs. `/dev/vdb` renamed `data` → `storage` so `main` sorts first and disko's
test harness assigns it `/dev/vda` as on Vultr. Subvolumes: `@ @home @root @nix
@var-log @tmp @var-tmp @var-cache @swap` (5 GiB swapfile) on vda;
`@var-lib @stalwart @vaultwarden` on vdb. `compress=zstd:3` (not
`compress-force`) on both pools.

**`checks.nix`** — `billy-uefi` and `billy-bios` wrap disko's `installTest`,
which runs the real disko script, a full `nixos-install`, and a reboot in a VM.
Both pass. This caught the disk-ordering bug before it reached hardware.

**IPv6** — Vultr has no `fe80::1`; the gateway is a per-VM link-local derived
from the NIC MAC. Now `IPv6AcceptRA = true` with `UseAutonomousPrefix = false`,
so the route comes from the RA and the static address the AAAA record points at
is the only v6 address.

**sops** — verified decrypting, both `/run/secrets/wifi-turtle-reef` and
`/run/secrets-for-users/igor-pw`, zero errors. `boxy.yaml` added, scoped to
`admin_igor_boxy` + `server_boxy` only.

**btrbk** — module rewritten: `snapshots.volumes` (attrset, multi-pool),
`sshAccess`, and `pull`. billy snapshots both pools every 15 min; boxy pulls
every 4 h into `/mnt/8tb/billy-backups/<sanitised-pool>/`, separate
subdirectories so same-named subvolumes across pools cannot collide. billy's
`sshAccess` key is restricted to `--info --source --send`. Verified working.

**Hardening / cleanup** — `PasswordAuthentication`, `KbdInteractiveAuthentication`,
`X11Forwarding` off (billy only; boxy unchanged). Docker disabled — it was
unconditional in `common.nix` and its ~380 MB was what pushed kexec into OOM.
`nix.gc` enabled, weekly, `--delete-older-than 30d`. `cores`/`max-jobs` 2 → 1.
Stale tmpfiles rules removed. `grub.device` dropped — disko sets `grub.devices`
from the EF02 partition.

---

## Sequencing — read before starting

**WireGuard must be up, verified, and surviving a reboot before SSH is
restricted to it.** Do goal 6 fully, reboot, confirm SSH over the tunnel, and
only then do goal 7.

**Console recovery is weaker than it looks — check before relying on it.**
`passwd -S` on billy today:

    root  L          <- locked, no password
    igor  P          <- set, but by hand

Root cannot log in at the Vultr console at all. `igor` can, and is in `wheel`
with `wheelNeedsPassword = true`, so `igor` → `sudo` is the working recovery
path. But that password came from somewhere outside this repo —
`hashedPasswordFile` (`config.nix:21`) is still commented out — so it would not
survive a reinstall. **Uncomment it before goal 7** to make the escape hatch
reproducible rather than accidental.

**Apply goal 7 with `test`, not `switch`.** `nixos-rebuild test` does not
persist across reboot, so a firewall mistake is undone by a console-triggered
reboot instead of requiring a reinstall. `just billy-test`, verify SSH over WG
from a _second_ terminal while the first stays open, then `just billy`.

**Locking SSH to WireGuard breaks two things, not one.**

- boxy's btrbk pull targets `ssh.nalgor.com:22` (`boxy.nix`,
  `igix.btrbk.pull.billy.host`). btrbk timers do not alert, so this fails
  silently.
- `.justfile` — `billy` and `billy-test` both target `root@ssh.nalgor.com`.
  Every deploy recipe breaks.

Both must change to billy's WireGuard address in the same commit as goal 7.

**Migrate DNS before any service cutover, never during** — see goal 8. A
failure during a combined move is ambiguous, and NS changes roll back on
registrar timescales while record changes are near-instant.

**Capacity is the standing risk.** Stalwart + Vaultwarden on 964 MiB / 1 vCPU is
tight (Postgres is ruled out — see goal 3–4). zram is at 50% with `zstd` and PSI
is currently flat at zero, so there is headroom, but watch
`/proc/pressure/memory` once mail is flowing. Resizing the Vultr plan is the
escape hatch — note a plan change also resizes the disk, so re-check `disk.nix`.

---

## 8. DNS consolidation to Cloudflare

Current state:

| domain         | nameservers  | registrar   |
| -------------- | ------------ | ----------- |
| `nalgor.com`   | Cloudflare ✓ |             |
| `nalgor.dev`   | Cloudflare ✓ |             |
| `nalgor.net`   | Linode       | Squarespace |
| `semyonov.xyz` | Linode       |             |
| `semyonov.dev` | Porkbun      |             |

`nalgor.net` today: `@`, `vault`, `mail`, `cloud` all → `66.175.214.66` (fid),
`MX 10 mail.nalgor.net`, `TXT "v=spf1 mx -all"`,
`_dmarc TXT "v=DMARC1;p=quarantine;sp=quarantine;adkim=r;aspf=r"`. No DKIM at
`default._domainkey` or `mail._domainkey`, so outbound currently leans on SPF
alone. The DMARC record has a stray trailing tab (`\009`) — worth cleaning up
during the move, since stricter parsers dislike it.

**`nalgor.com` is not free either.** It currently has
`MX 10 fwd1.porkbun.com / 20 fwd2.porkbun.com` and
`TXT "v=spf1 include:_spf.porkbun.com ~all"` — Porkbun email forwarding is live
on it, and no `_dmarc` record exists. That forwarding has to be torn down as
part of standing Stalwart up on `nalgor.com`, and SPF replaced rather than
appended to.

**Migrate DNS before any service cutover, not during.** Moving nameservers and
moving a service at the same time means a failure could be either, and rollback
is slow because NS changes propagate on registrar timescales while record
changes are near-instant. Order:

1. Recreate every existing record in Cloudflare, all **grey** (DNS-only), still
   pointing at fid.
2. Verify by querying Cloudflare's nameservers directly before delegating.
3. Change NS at the registrar. Nothing has moved — the zone should behave
   identically.
4. Only then do service cutovers, which become single record edits.

Doing it in this order also makes the Vaultwarden cutover a one-record change
with instant rollback, which is what `vaultwarden-migration.md` assumes.

### Registrar transfer to Porkbun — separate from the DNS move

`nalgor.net` and `semyonov.xyz` are both registered at **Squarespace**;
`nalgor.net` expires **2026-12-02**, `semyonov.xyz` 2027-07-30. Both carry
`clientTransferProhibited`, which is just the standard lock to clear before
initiating.

**Registration and delegation are independent, and that is useful here.** NS
already points at Linode — a third party — so moving the registration
Squarespace → Porkbun does not touch DNS resolution at all. Sequence them:

1. **DNS first** (Linode → Cloudflare). Fast to verify, fast to roll back.
2. **Registrar second** (Squarespace → Porkbun). With NS already on Cloudflare,
   the transfer is invisible to resolution.

Together, any breakage is ambiguous and one half rolls back in minutes while
the other takes days.

Two timing facts worth planning around: a gTLD transfer **adds a year** to the
registration (so it doubles as the renewal), and ICANN imposes a **60-day
transfer lock afterwards**. With `nalgor.net` expiring 2026-12-02, that expiry
is what should set the schedule for goal 8 — leave margin rather than starting
in late November.

### API access

- **Cloudflare** — one token, `Zone:DNS:Edit` on the relevant zones. Serves
  double duty: bulk record creation during the move, and ACME DNS-01 afterwards.
  Into sops, in a file billy can decrypt.
- **Porkbun** — API key + secret, enabled per-domain in their panel. Useful for
  registrar-side scripting and transfer status. billy never needs it at runtime,
  so it belongs in admin secrets, not on the box.

For the bulk move, prefer **Linode zone export → Cloudflare zone import** over
hand-recreating records; hand-copying is where records get silently dropped.

**Audit proxy status immediately after import.** Do not assume imported records
land grey — verify every one against the orange/grey rules below before changing
NS. An orange-clouded `mail` record breaks SMTP, and it presents as a mail
outage rather than a DNS mistake.

### `-all` on SPF is a live hazard for SES

`v=spf1 mx -all` authorises only the MX and hard-fails everything else. The
moment SES starts sending for a domain, that record must become
`v=spf1 mx include:amazonses.com -all` — or every outbound message is rejected
by the receiver, not deferred. Update SPF for each domain **before** pointing
its outbound at SES, and re-check the ones already on Cloudflare.

The `mx` mechanism is a trap during migration: it authorises whatever the MX
currently points at, so its meaning flips from fid to billy the instant MX
moves. If both are sending during a parallel window, whichever is not the MX
fails SPF. Pin both explicitly for the duration:

    v=spf1 ip4:66.175.214.66 ip4:207.246.88.247 include:amazonses.com -all

then trim back to `mx include:amazonses.com -all` once fid is out of the path.

DMARC on `nalgor.net` is `p=quarantine` with relaxed alignment (`adkim=r`,
`aspf=r`). Relaxed is forgiving, and SES domain identities sign with the
sending domain, so alignment should hold — but a misconfiguration quarantines
rather than bounces, which is harder to notice. Watch DMARC aggregate reports
during cutover rather than assuming silence means success.

### Orange cloud — what can and cannot be proxied

Cloudflare's proxy only handles HTTP/HTTPS. These must stay **grey**:

- `mail.*` A/AAAA — the MX target. SMTP is not HTTP; proxying it breaks mail.
  MX records themselves are never proxied, but the host they point at must
  resolve to the real IP.
- the WireGuard endpoint — UDP, cannot be proxied. This is the record that
  matters most after goal 7; it is the only way in.
- `ssh.nalgor.com` — SSH is not HTTP. Note this stops being the deploy path
  once goal 7 lands and SSH moves to wg0; keep the record for the pre-goal-7
  window and for emergency use if the firewall is ever relaxed.
- anything used for ACME DNS-01 delegation.

`vault.nalgor.net` _can_ be orange, with three caveats worth deciding on:

- **100 MB upload cap** on Free and Pro plans, which becomes the effective
  Vaultwarden attachment ceiling.
- **Cloudflare terminates TLS**, so it sees the client-derived
  `masterPasswordHash` used for authentication. Vault contents stay encrypted
  end-to-end and CF cannot decrypt them, but that hash is an auth credential.
  A reasonable call either way; worth making deliberately for a password
  manager rather than by default.
- **Client IP becomes Cloudflare's** unless `CF-Connecting-IP` is honoured at
  the proxy, which affects rate limiting and logs.

### ACME

With DNS on Cloudflare, use **DNS-01** for everything. It sidesteps the
port-80 contention between Caddy and Stalwart entirely, works for all mail
hostnames, and supports wildcards. Needs a Cloudflare API token scoped to
`Zone:DNS:Edit` for the relevant zones — into sops, in a file billy can
decrypt (a new `billy.yaml`, not `boxy.yaml`).

**Dependency:** DNS-01 for `vault.nalgor.net` is blocked until `nalgor.net`
actually moves to Cloudflare, so goal 8 gates the Vaultwarden cutover. Either
sequence it that way, or use HTTP-01 for that one hostname in the interim —
which reintroduces the port-80 contention, so prefer the ordering.

If everything is DNS-01, port 80 is not needed for ACME at all. It is still
worth opening for HTTP→HTTPS redirects; drop it from the firewall if you do not
want even that.

## 6. WireGuard billy ↔ boxy (required, do first)

billy has a static public IP and is the listening side; boxy is behind NAT and
initiates with `PersistentKeepalive`.

Keys — one private key per host plus one shared PSK:

    wg genkey | tee priv | wg pubkey > pub    # per host
    wg genpsk                                 # one, shared

Storage: private keys and the PSK go in sops. `boxy.yaml` already exists and is
scoped correctly. Add a `billy.yaml` scoped to `admin_igor_boxy` + `server_billy`
following the same pattern, with a new `creation_rules` entry **above** the
general one — `^[^.]*\.(yaml|json|env|ini)$` matches it otherwise and sops takes
the first match. The PSK is encrypted separately into both files.

Public keys are not secret; keep them beside their private halves in
`nix-secrets` as `.pub` files and `builtins.readFile` them, as billy already does
for `btrbk-boxy-to-billy.pub`. That makes rotation a single commit.

Suggested addressing: `10.100.0.1/32` billy, `10.100.0.2/32` boxy. Open UDP
51820 on billy only.

Reachable via `wg` requires the interface up before `sshd` accepts on it — bind
sshd to the WG address or filter in nftables, not both.

## 7. Firewall tightening (required, do last)

Currently only 22 is open. Target state:

| port     | proto | scope        | for                                    |
| -------- | ----- | ------------ | -------------------------------------- |
| 51820    | udp   | public       | WireGuard                              |
| 22       | tcp   | **wg0 only** | SSH                                    |
| 25       | tcp   | public       | inbound SMTP                           |
| 465, 587 | tcp   | public       | submission                             |
| 993      | tcp   | public       | IMAPS                                  |
| 80, 443  | tcp   | public       | Vaultwarden, Stalwart admin, redirects |

Vultr blocks **outbound** 25, which is why SES is the relay; **inbound** 25 is
unaffected and still required to receive. Consider restricting the Stalwart
admin UI to wg0 as well.

Add fail2ban or sshguard — still nothing rate-limiting auth. Less urgent once
SSH is WG-only, but 25/587 remain exposed.

## 1–2. Stalwart + AWS SES

State dir is `/var/lib/stalwart` (nixpkgs `stalwart.nix:13`; `stalwart-mail` only
below stateVersion 26.05) — already its own subvolume on vdb, so it is covered by
the btrbk pull.

- Relay outbound through SES on 587/465, credentials from sops.
- SES owns outbound reputation, so no PTR needed on billy's IPs.
- SES requires a move out of the sandbox before it will send to unverified
  recipients.

### Domains

Planned: `nalgor.com`, `semyonov.dev`, `nalgor.dev`, `nalgor.net`,
`semyonov.xyz` — and more later.

Trivial on the Stalwart side: domains are directory entries, so adding one is
config plus DNS. **The per-domain cost is in SES and DNS, not Stalwart.** Each
domain is a separate SES identity needing its own verification and its own set
of DKIM CNAMEs; there is no wildcard. Per domain you need MX → billy's mail
host, SPF authorising SES, DMARC, and the SES DKIM records. Budget that as
mechanical-but-repeated work, and script it if the list keeps growing.

TLS does **not** multiply: SMTP/IMAP clients connect to one hostname (e.g.
`mail.nalgor.com`), so a single ACME cert covers all domains' mail. You only
need per-domain certs if you also want MTA-STS policy hosts or autodiscover
per domain.

`nalgor.net` is the exception — fid serves its mail today, so it belongs to
goal 5 (migration), not day-one setup. Stand the other four up first on a
domain billy already owns, prove the stack, then move `nalgor.net`.

## 3–4. Vaultwarden, and migrating off fid

Target state dir `/var/lib/vaultwarden` (nixpkgs `vaultwarden/default.nix:14`;
`bitwarden_rs` only below stateVersion 24.11) — already its own subvolume.

**What is on fid today**

- `vaultwarden/server:latest` in Docker, published `0.0.0.0:7080 -> 80`
- data volume `/root/vaultwarden/vw-data` → `/data`
- config via mounted `/root/vaultwarden/.env` (not docker env vars)
- database in **host** PostgreSQL 18.4 on 5432
- nginx terminates TLS for `cloud/gitea/mail/mailadmin/meet.nalgor.net`,
  `nalgor.net`, `kaladin1.com`

**Decided: SQLite.** This trades a harder one-time migration for a much easier
steady state.

What it buys:

- `dbBackend` default is already `"sqlite"` (`default.nix:85`) — no Postgres on a
  964 MiB box that also has to run Stalwart, saving ~100–200 MiB resident.
- The module's `backup-vaultwarden` service and timer (`:324`, `:343`) are
  **sqlite-only** — `assertion = cfg.backupDir != null -> cfg.dbBackend ==
"sqlite"` (`:212`). Postgres would mean writing our own backup job.
- The whole vault becomes a file under `/var/lib/vaultwarden`, which is already
  its own subvolume in the btrbk pull. With Postgres the real data would sit in
  `/var/lib/postgresql`, and snapshotting a live cluster is crash-consistent at
  best.

Set `backupDir` outside `dataDir` — `:216` asserts they cannot nest. Something
like `/var/lib/vaultwarden-backup` keeps it on `@var-lib`, still covered by
btrbk. `sqlite3 .backup` gives a consistent copy that the snapshot then
captures, which is stronger than snapshotting the live DB alone.

**Migration cost.** There is no official Postgres → SQLite path, and `pgloader`
goes the wrong direction (sqlite → pg). Full procedure in
`vaultwarden-migration.md`; summary:

1. Stop the container on fid so the DB is quiescent.
2. Start Vaultwarden once on billy against an empty SQLite file so diesel runs
   its migrations and creates the schema.
3. `pg_dump --data-only --inserts --column-inserts` from fid, then transform
   before loading: booleans `t`/`f` → `1`/`0`, and insert in foreign-key order.
   This is the fiddly part — budget real time for it.
4. `rsync` `vw-data` — attachments, icon cache, `rsa_key.pem`. Attachments are
   files on disk referenced by the DB, so both halves must arrive. Losing
   `rsa_key.pem` invalidates existing sessions (forces re-login) but loses no
   data.
5. Verify — and **not only as yourself**. Row parity, per-user 2FA enrolments,
   org membership and collection visibility, one attachment download. At least
   one other user must confirm before cutover.
6. Keep fid running until verified; roll back by reverting DNS.

**Do not move the hostname.** WebAuthn credentials bind to the Relying Party ID,
which Vaultwarden derives from `DOMAIN` (`webauthn.rs:36`). Serving the vault at
`vault.nalgor.com` would invalidate every registered passkey and FIDO2 key, no
matter how clean the DB migration is. Keep `vault.nalgor.net` and repoint its
DNS at billy — users then change nothing at all. Of the 2FA types, only WebAuthn
is domain-bound; TOTP, Email, YubiKey and recovery codes travel in the
`twofactor` table.

JSON export/import is **not** a fallback here: it is per-user manual work, drops
organisations, loses every MFA enrolment, and omits attachments. DB-level
migration is the only path. See `vaultwarden-migration.md`.

`.env` on fid holds the admin token and DB credentials — deliberately not read
during this survey. Re-key rather than copy: put fresh values in sops.

## 5. Mail migration off fid (optional)

- 907 MiB in `/var/vmail`, single domain `nalgor.net`, maildir layout
  `maildir:/var/vmail/%d/%n/`.
- Postfix virtual domains and mailboxes are **Postgres-backed**
  (`pgsql:/etc/postfix/pgsql/*.cf`); Dovecot passdb/userdb also `sql` via
  `/etc/dovecot/dovecot-sql.conf.ext`. Account definitions live in the database,
  not in flat files — enumerate them before planning a cutover.
- Stalwart uses its own store, so migration is an IMAP-level sync (`imapsync`)
  rather than a file copy. 907 MiB is small enough that this is hours, not days.
- fid also serves Nextcloud, Gitea, and Jitsi on `nalgor.net`, so moving MX
  affects a host that is not going away. Lowest-risk order: stand up Stalwart on
  a billy-owned domain first, prove it, then migrate `nalgor.net` mail.

---

## Leftovers

- `secrets.nix` — `sops.gnupg.sshKeyPaths` with an ed25519 key cannot work
  (`ssh-to-pgp` is RSA-only). Confirmed by the install log: `failed to parse
private ssh key: only RSA keys are supported`. Non-fatal since the age path
  runs; drop the line.
- `secrets.nix` deploys `wifi-turtle-reef` to a VPS with no wifi.
- `users.nix` gives `igor-headless` `networkmanager`, `i2c`, `dialout` — none
  apply. `gitKeys.billy = "placeholder"` yields a broken signing config if read.
- `hashedPasswordFile` (`config.nix:21`) stays commented; `igor-pw` does decrypt,
  so uncommenting is a one-liner if sudo is ever wanted. Root-by-key works today.
- `download-buffer-size` is 2 GiB on a 964 MiB box — a leftover from the Hetzner
  node. Nix default is 64 MiB.
- 12 files under `modules/homeModules/ai/` and `modules/stylix/module.nix` have
  never been through treefmt; they resurface in every `nix fmt`. Worth one
  dedicated formatting commit.
- `noautodefrag` in `disk.nix` is btrfs's default — a no-op.
