# billy — plan

Vultr VPS, 1 vCPU / 964 MiB, BIOS boot, `/dev/vda` 32G + `/dev/vdb` 10G.
Config in `modules/hosts/billy/{config,disk,checks}.nix`. Reinstall procedure in
`reinstall.md`. Deploy with `just billy-test` (reboot-recoverable) then `just billy`.

## Execution order

The ordering below is Igor's, reviewed and kept — it front-loads the lockout
risk while billy is still empty (a lockout today costs a 30-minute reinstall;
the same lockout after mail and the vault are live costs data), and it keeps
registrar, delegation, and service moves as separate reversible steps.

| #       | step                                        | rollback            |
| ------- | ------------------------------------------- | ------------------- |
| **0**   | SES production access + lower TTLs          | n/a — start now     |
| **1**   | WireGuard, then SSH restricted to `wg0`     | reboot (via `test`) |
| **2**   | Registrar → Porkbun (NS stays Linode)       | days                |
| **3**   | DNS management → Cloudflare                 | minutes             |
| **3.1** | Orange cloud, Full (strict) to origin       | one toggle          |
| **3.5** | billy fundamentals: proxy, ACME, monitoring | n/a                 |
| **4**   | Mail: new domains first, then `nalgor.net`  | dual-MX window      |
| **5**   | Vaultwarden migration + origin flip         | lossy after writes  |

Two additions to the original five: **step 0**, because SES sandbox exit is the
only item gated on a third party's review time and everything in step 4 depends
on it; and **step 3.5**, because both step 4 and step 5 need a reverse proxy and
ACME on billy and neither step listed it.

Sections below are grouped by topic, not sorted by step number — this table is
the canonical order.

### Standing rules across all steps

- **TTLs stay low** from step 0 until step 5 is signed off. Every cutover's
  rollback time is bounded below by the TTL that was in effect _before_ it.
- **Apply risky changes with `nixos-rebuild test` first** — it does not survive
  a reboot, which turns a lockout into a reboot instead of a reinstall.
- **Rehearse each rollback once** before you need it. "Revert the DNS record" is
  only a rollback if it has been tried.
- **Watch for hostnames serving two protocols.** Twice now this has been the
  hidden trap — the apex carrying both a website and the WireGuard endpoint, and
  `mail.*` carrying both MX and webmail. Any name that is both proxied and
  unproxied is a bug waiting to happen.
- **billy + boxy both lost = total loss** of mail and vault. btrbk covers
  billy→boxy only. Decide whether that is acceptable or whether a third copy is
  wanted; for a password vault it probably is.

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

## 0. Start immediately — these have lead time

**Request AWS SES production access now.** Sandbox only permits sending to
verified addresses, so step 4b cannot be meaningfully tested until this clears,
and AWS review can take from a day to several. It is the only item in the plan
gated on someone else's response time. Everything else can proceed in parallel.

**Lower DNS TTLs at Linode.** Every cutover in steps 3–5 is bounded below by the
TTL in effect _before_ the change. Drop `nalgor.net` and `semyonov.xyz` records
to 300s well ahead of the delegation change, and keep them low until step 5 is
signed off. Raise them afterwards.

**Decide the SES sending identity model.** Per-domain identities each need their
own DKIM CNAMEs — no wildcard. With five domains that is five verification sets,
so it is worth scripting against the Cloudflare API rather than clicking through.

### SES bootstrap — order of operations

1. **Set the region first.** It is the console header dropdown, not part of the
   wizard, and it is easy to miss. Identities are per-region **and so is
   production access** — switching later means re-verifying everything and a
   fresh review. `us-east-1` is the conventional default.
2. **Verify an email identity.** Any address you can receive at —
   `igor@nalgor.net` or a Gmail. It does _not_ need to be on a domain you intend
   to send from; that is a separate identity type. Verify a Gmail as well: in
   sandbox you may only send _to_ verified addresses, so an independent provider
   is what lets you check real cross-provider delivery and spam placement.
3. **Request production access.** Does not require any domain verified. This is
   the clock you do not control — start it before anything else.
4. **Add domain identities** (below), which is DNS work and independent of 1–3.

### `nalgor.com` first — DNS DONE, awaiting production access

Region: **us-east-2 (Ohio)**. Endpoints fixed by that choice:

```
SMTP        email-smtp.us-east-2.amazonaws.com:587 (STARTTLS)
MAIL FROM   feedback-smtp.us-east-2.amazonses.com
```

Do not change region later — identities **and production access** are both
per-region, so a move means re-verifying and re-queuing the review.

Scoped to `nalgor.com` deliberately, to avoid disturbing fid's working mail.
Not a blank slate: Porkbun forwarding is live (`MX 10 fwd1.porkbun.com`,
`SPF include:_spf.porkbun.com ~all`). Does not affect send-testing; does own
inbound.

MAIL FROM: **`mailfrom.nalgor.com`**. SES plan: **Essentials**, VDM on,
Optimized Shared Delivery on, open/click tracking **off**, Auto Validation
**off**, no dedicated IPs, no tenants.

**Published on Cloudflare (2026-08-15), all DNS-only, TTL 300, verified at both
authoritative nameservers:**

```
2rfho5hlf5uuatp7hhvqaocm6owfmslj._domainkey  CNAME  ...dkim.amazonses.com
dficovlzcymtgcvcvb6vn2zq5ybx76c6._domainkey  CNAME  ...dkim.amazonses.com
boztaykyiboweea3xotodbhflgrovafz._domainkey  CNAME  ...dkim.amazonses.com
mailfrom.nalgor.com   MX   10 feedback-smtp.us-east-2.amazonses.com
mailfrom.nalgor.com   TXT  "v=spf1 include:amazonses.com ~all"
_dmarc.nalgor.com     TXT  "v=DMARC1; p=none; rua=mailto:dmarc@nalgor.com"
```

`dmarc@nalgor.com` forwards via Porkbun for now; it becomes a Stalwart alias at
step 4a when the Porkbun MX comes down. Two stale `_acme-challenge` TXT records
were deleted at the same time.

**`nalgor.com` is three weeks old** (registry creation 2026-07-26) and that is a
deliverability factor in its own right. Domain age is a spam signal: receivers
apply extra scrutiny below ~30 days, and there is no sending history at all.

The risk this creates is **misdiagnosis** — early mail landing in spam will look
like an auth bug when it is reputation. DMARC aggregate reports separate the
two: authentication problems appear as SPF/DKIM `fail` in the XML, reputation
problems appear as everything passing while placement stays poor. Read
`nalgor.com` results as a floor, not a representative sample; `nalgor.net`
(2022) and `semyonov.xyz` (2020) carry years of history and will behave better.

Worth naming the tension: experimenting on the _new_ domains is right for
avoiding disruption and wrong for deliverability. Still the correct trade — do
not test on live mail — but calibrate expectations.

**Beware the proxied wildcard.** `*.nalgor.com CNAME uixie.porkbun.com` is
proxied, so any name without an explicit record resolves to Porkbun via
Cloudflare. Explicit records win, but public resolvers cache the wildcard
answer — new records look missing from `1.1.1.1` for a few minutes while being
correct at the authoritative servers. **Always validate against
`coco/tim.ns.cloudflare.com`, not a public resolver.**

Porkbun's own DNS panel still shows 7 records for this zone. They are **inert** —
NS points at Cloudflare — but they are a good way to lose an hour later.

**A proxied CNAME returns Cloudflare's IPs instead of resolving the chain**,
which breaks DKIM lookup outright. Cloudflare normally refuses to proxy
underscore-prefixed records, but verify rather than assume.

**The apex SPF probably needs no change.** SPF validates the _envelope_ sender,
and with a custom MAIL FROM the envelope domain is `mailfrom.nalgor.com` — so
SES is authorised by the subdomain's record, not the apex. Porkbun's existing
apex SPF can stay for the forwarding. Clean separation, one record per sender.

`nalgor.com` currently has **no** `_dmarc` record. Start at `p=none` with `rua`
reporting so alignment can be observed for a week before tightening — worth
doing _before_ touching `nalgor.net`, which already sits at `p=quarantine`.

**Do not set `aspf=s`.** Strict SPF alignment would reject
`mailfrom.nalgor.com` as unaligned with `nalgor.com` and fail every message.
Relaxed (the default) accepts the subdomain.

## 2. Registrar → Porkbun (NS stays at Linode)

Covered in detail below under "Registrar transfer to Porkbun". Key point: this
is deliberately separate from and _before_ the delegation change, and because NS
already points at a third party (Linode), moving the registration is invisible
to resolution.

The post-transfer 60-day ICANN lock blocks further **registrar** transfers only
— it does not block NS changes, so step 3 can follow immediately.

## 3. DNS management → Cloudflare

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

### BLOCKING: fid's certbot must move to `dns-cloudflare` in the same window

fid renews with:

```
authenticator            = dns-linode
dns_linode_credentials   = /root/.secrets/certbot/linode.ini
```

and its certificates are **wildcards** — `*.nalgor.net`, `*.semyonov.xyz`.

Both facts matter:

- **Wildcards can only be issued over DNS-01.** Let's Encrypt will not do
  HTTP-01 for a wildcard, so there is no fallback. The ACME authenticator must
  be able to write TXT records into whatever is authoritative.
- **The instant NS moves to Cloudflare, the Linode plugin writes challenge
  records into a zone nobody reads.** Renewal fails, and ~30 days later every
  TLS service on fid drops at once: `vault`, `abs`, `meet`, `gitea`, and both
  websites.

Timing is tight — `nalgor.net` expires **2026-09-16** and certbot renews at 30
days remaining, so attempts begin around 2026-08-17. `semyonov.xyz` expires
2026-10-25.

Required, in the same maintenance window as the NS change:

1. install `certbot-dns-cloudflare` on fid
2. write a CF token credentials file (scoped to these zones, `0600`)
3. set `authenticator = dns-cloudflare` + `dns_cloudflare_credentials` in
   **both** `/etc/letsencrypt/renewal/*.conf`
4. force a renewal to prove it works **before** the Linode zone goes away
5. afterwards, revoke the Linode API token at Linode — deleting
   `/root/.secrets/certbot/linode.ini` does not invalidate it

Note this corrects an earlier assumption in this plan that fid used HTTP-01 and
that moving it to DNS-01 was an optional improvement. It is already on DNS-01,
pointed at the provider being left, which makes the switch mandatory rather than
nice-to-have.

### Existing DKIM on fid

Selector is **`20250120792194`** (from `/etc/opendkim/key.table`; the
`dkim._domainkey.*` strings there are opendkim's internal labels, not the
selector). Published and valid for both `nalgor.net` and `semyonov.xyz`.

These TXT records must be carried across in the zone migration, and must stay
grey. They remain in use until Stalwart takes over signing for those domains at
step 4c — at which point SES's DKIM CNAMEs replace them for outbound.

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
actually moves to Cloudflare, so step 3 gates the Vaultwarden cutover. Either
sequence it that way, or use HTTP-01 for that one hostname in the interim —
which reintroduces the port-80 contention, so prefer the ordering.

While you have a Cloudflare token, consider moving **fid's** renewals to DNS-01
too. Once fid's hostnames are orange-clouded, HTTP-01 renewals start depending
on Cloudflare proxying `/.well-known/acme-challenge` correctly; DNS-01 removes
that dependency for a service that is going to keep running for a while.

## 3.5. billy fundamentals — prerequisite for steps 4 and 5

Neither the mail step nor the Vaultwarden step works without these, and neither
listed them.

**Reverse proxy — decided: nginx + `security.acme`.** Vaultwarden speaks plain
HTTP and Stalwart's admin UI is HTTP, so something must terminate TLS.

Reasoning, verified against nixpkgs rather than reputation:

- nginx is the _lighter_ of the two (~10–20 MiB vs Caddy's ~20–40). The "nginx is
  overkill" folklore is about config verbosity, not footprint.
- Caddy's headline advantage is built-in ACME, which NixOS largely neutralises —
  `security.acme` already makes certs declarative for nginx.
- With DNS-01, Caddy costs more. Its DNS providers are compile-time plugins:
  `caddy.withPlugins` (`pkgs/by-name/ca/caddy/plugins.nix`) is well-built, but it
  is a fixed-output derivation running `xcaddy` + `go mod vendor`, so plugins must
  be version-pinned (`assertMsg`, line 46), you supply a `hash` that starts as
  `fakeHash`, and `vendorHash = null` means **a source rebuild with no cache hit**
  on every bump. lego ships every provider in one binary, so nginx needs none of
  that.
- Existing fid vhosts port over, including the `vault.nalgor.net` proxy block.

Caddy's config is genuinely ~⅓ the size for pure reverse-proxy work. That is the
one real argument the other way, and it does not outweigh a source rebuild per
plugin bump plus the memory delta.

**ACME via DNS-01** with the Cloudflare token from step 3. The integration is
just two options (`security/acme/default.nix:730`, `:751`):

```nix
security.acme.certs."mail.nalgor.net" = {
  dnsProvider = "cloudflare";
  environmentFile = config.sops.secrets.cf-dns-token.path;
};
```

`credentialFiles` (`:763`) takes `*_FILE`-suffixed vars via systemd credentials
if preferred, and `dnsPropagationCheck` (`:781`) is the escape hatch if
propagation gets flaky. Certificates needed: the mail hostname (one cert covers
all five domains' SMTP/IMAP — clients connect to one name), `vault.nalgor.net`,
the Stalwart admin hostname, and any landing-page redirect names.

**Origin TLS must be valid before orange cloud.** Cloudflare Full (strict)
validates the origin certificate. If billy is behind an orange record with a
missing or mismatched cert, the failure is a 5xx from Cloudflare, not an obvious
local error.

**Monitoring — currently nothing.** Three things fail silently today or will:

- btrbk timers (already true — a failed pull is invisible)
- ACME renewals
- the mail queue backing up, and SES bounce/complaint rates, which if they
  breach AWS thresholds get sending suspended

Minimum viable: systemd `OnFailure=` on the relevant units pointing at something
that reaches you, plus SES bounce/complaint notifications via SNS. This should
land before mail goes live, not after.

**Capacity check.** `@stalwart`, `@vaultwarden`, and `@var-lib` all share the
10 GiB vdb. fid's `/var/vmail` is 907 MiB today and mail only grows. Vultr block
storage can be expanded online and btrfs resized to match, so this is a watch
item rather than a blocker — but know the procedure before you need it.

If everything is DNS-01, port 80 is not needed for ACME at all. It is still
worth opening for HTTP→HTTPS redirects; drop it from the firewall if you do not
want even that.

## 1. WireGuard billy ↔ boxy, then SSH on wg0 only

### boxy already has a WireGuard — do not collide with it

`boxy.nix` defines `wg-quick.interfaces.fidler`:

```nix
address     = ["10.0.0.10/32"];
listenPort  = 51820;
privateKeyFile = "/etc/wireguard/privatekey";
peers = [{ allowedIPs = ["10.0.0.0/24"]; endpoint = "nalgor.net:41883"; ... }];
```

Consequences for the new tunnel:

- **Port 51820 is taken on boxy.** Since boxy is the initiator and sits behind
  NAT, simply omit `listenPort` on its billy interface and let it pick an
  ephemeral port. billy can still listen on 51820 — different host, no conflict.
- **`10.0.0.0/24` is routed into `fidler`.** Keep the new tunnel off that range;
  `10.100.0.0/24` is clear.
- **Interface name** must not be `fidler`; use `billy`.
- `privateKeyFile = "/etc/wireguard/privatekey"` is manual state on boxy, not
  sops — the same reproducibility gap we closed on billy. Worth folding into
  sops while touching this area.

### The apex record is load-bearing — a trap for step 3.1

The existing tunnel's endpoint is **`nalgor.net:41883`**, i.e. the _apex_ A
record. Orange-clouding `nalgor.net` for the website would break the fid↔boxy
WireGuard, because UDP cannot be proxied — and the failure would present as
`abs.nalgor.net` dying, not as a DNS change.

Fix before step 3.1: give the endpoint its own grey hostname, update `boxy.nix`,
confirm the handshake, and only then consider orange on the apex.

### Naming: nest it, do not take `wg.<domain>` flat

Other WireGuard endpoints are planned outside this project. Do not burn the flat
`wg.<domain>` label on the fid endpoint — use a nested form such as
`fid.wg.<domain>` so siblings have somewhere to go.

The only rule billy's plan needs from that: **everything under `wg.` stays
grey.** WireGuard is UDP and can never be proxied, so that label is a permanent
no-orange zone, which is what makes grouping worthwhile.

### The tunnel itself

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

### Firewall — the second half of step 1

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

## 4. Mail — new domains first, then `nalgor.net` + `semyonov.xyz`

Order within the step, per Igor: (a) stand up Stalwart for `nalgor.com`,
`nalgor.dev`, `semyonov.dev`; (b) get SES sending fully working; (c) only then
migrate `nalgor.net` and `semyonov.xyz` across, recreating service accounts.
That is the right shape — it proves the whole stack on domains with no live
users before touching the one that matters.

Three things the original step 4 did not account for:

**`nalgor.com` is not a clean slate.** It currently has live Porkbun email
forwarding — `MX 10 fwd1.porkbun.com / 20 fwd2.porkbun.com`, SPF
`include:_spf.porkbun.com ~all`. That has to be torn down, and SPF _replaced_
rather than appended to, or you get two conflicting senders authorised.

**Every fid service that sends mail needs rehoming, not just Vaultwarden.**
Igor correctly flagged Vaultwarden's 2FA email codes. But `mailadmin`
(PostfixAdmin) and anything else wired to fid's local Postfix are in the same
position once MX moves. Enumerate before 4c rather than discovering it from a
user report. (`cloud.nalgor.net` is inactive and `gitea.nalgor.net` is unused —
out of scope.)

**The 2FA-email dependency is a hard gate, not a footnote.** Between 4c and
step 5, Vaultwarden is still on fid but mail lives on billy. If that path
breaks, users with email-based 2FA are locked out of the vault — that is other
people's lockout, not just yours. Two options:

- point fid's Vaultwarden at billy's submission port with a dedicated service
  account (what Igor means by "recreating the service accounts"), or
- point fid's Vaultwarden straight at SES SMTP, bypassing billy entirely

The second is simpler and removes a moving part during the window when billy's
mail is newest. It also means Vaultwarden never depends on Stalwart, which is
worth knowing generally: **if mail slips, step 5 is not blocked.**

**MX cutover needs a dual-MX window.** For 4c, keep fid as a lower-priority MX
while billy takes priority, so nothing bounces if billy rejects. Drop fid from
the record set only once billy has been accepting cleanly for a full day. TTLs
must already be low (step 0).

### Webmail — deferred, optional

Testing 4b with **Thunderbird** is better than webmail anyway: it exercises real
IMAP and SMTP submission rather than a server-side abstraction, so a broken
client config is distinguishable from a broken server.

If a webmail host is wanted later, it is the tightest addition to this box.
Rough steady-state budget on 964 MiB: base system ~150–250, Stalwart ~100–200,
Vaultwarden ~50–100, reverse proxy ~20–40. That leaves room for a small PHP
front end but not a careless one — `php-fpm` with `pm = ondemand` and a low
`pm.max_children` is the difference between fitting and swapping. SnappyMail is
the lightest credible option; Roundcube on SQLite is the mature middle. zram
plus the 5 GiB swapfile give headroom, but swapping a mail server is unpleasant.

**Do not reuse one hostname for both roles.** `mail.nalgor.net` is free today,
but it cannot simultaneously be the MX target (must be grey — SMTP is not HTTP)
and an orange-clouded webmail host. Same trap as the apex/WireGuard collision in
step 1: one name serving both a proxied and an unproxied protocol.

Putting the webmail host on **`.dev`** is a good call — Google preloaded the
entire TLD into the HSTS list, so browsers refuse plaintext to it outright, with
no reliance on a `Strict-Transport-Security` header arriving first. That kills
downgrade attacks on the login page for free.

The distinction to keep straight: **HSTS is HTTP-only and does nothing for mail
transport.** It is not a reason to make the _MX target_ a `.dev` name. The
equivalent guarantees for SMTP are **MTA-STS** (a policy file served over HTTPS
at `mta-sts.<domain>`, telling senders to require TLS) and optionally
**DANE/TLSA** (requires DNSSEC, which Cloudflare can sign). Worth adding for the
mail domains once Stalwart is stable — note MTA-STS is itself an HTTPS host, so
it needs a cert and can be orange.

Suggested split:

| host                         | cloud  | role                        |
| ---------------------------- | ------ | --------------------------- |
| `mail.nalgor.net`            | grey   | MX target, SMTP/IMAP        |
| `webmail.nalgor.dev`         | orange | webmail, HSTS-preloaded TLD |
| `mta-sts.<each mail domain>` | orange | MTA-STS policy              |

### Stalwart + AWS SES

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

## 5. Vaultwarden — install, migrate, flip the origin

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

## Reference — fid's current mail setup (input to step 4c)

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

## Later — low priority

### Landing page / portal

A static dark-mode index linking to `vault`, `abs`, and whatever else. Resource
cost is effectively zero — a file served by the reverse proxy, no process, no
database — so it does not compete with Stalwart for the 964 MiB.

Worth building as a **Nix derivation** rather than a mutable webroot: the HTML
lives in this repo, `pkgs.writeTextDir` or a small `runCommand` produces a store
path, and the proxy roots at it. That keeps it in the same reproducibility model
as everything else and means no state to back up.

Pick one canonical host and 301 the rest to it. `nalgor.dev` is the natural
choice given the HSTS-preloaded TLD. Note the redirecting names still need
certificates, so add them to the ACME cert list even though they serve nothing.

One consideration: a public portal is an index of your infrastructure. The links
are not secrets and the targets all require auth, so this is probably fine — but
if you would rather it not be enumerable, Cloudflare Access in front of the
landing page (not the services) is a light way to gate it.

### Webmail

Covered under step 4. Deferred — Thunderbird covers testing, and webmail is the
tightest fit on this box.

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
