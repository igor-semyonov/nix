# billy — deployment TODO

Vultr VPS, target roles: Stalwart (mail) + Vaultwarden, outbound mail via AWS SES.
Config lives in `modules/hosts/billy/{config,disk}.nix`.
Deploy with `just billy-test` (reboot-recoverable) then `just billy`.

---

## Done

### IPv6 default route — fixed

Vultr has no `fe80::1`. The v6 gateway is a per-VM link-local derived from the
NIC MAC (`fe80::fc00:6ff:fe79:e305`), so it cannot be hardcoded. `config.nix`
now sets `IPv6AcceptRA = true` with `ipv6AcceptRAConfig.UseAutonomousPrefix =
false`, taking the default route from the RA while keeping the static address
the AAAA record points at, and adding no SLAAC/RFC-4941 addresses.

Unrelated second cause of the same symptom: `known_hosts` had entries for the
IP but not the hostname, so `ssh igor@ssh.nalgor.com` failed host key
verification after a long v6 timeout. Resolved by accepting the key once.

---

## Priority 1 — reproducibility

### Verify sops actually decrypts

Before the rekey, every activation logged `failed to decrypt default.yaml:
Error getting data key: 0 successful groups required, got 0` and
`Activation script snippet 'setupSecrets' failed (1)`. This does **not** abort
a rebuild, so it fails silently.

Billy's age key (derived from the ed25519 host key):
`age1g583g409lqgdl7280txta57vf295l8ynn66860253w2hdgdll5sqw6qyve`

Confirm on the box:

    ls -la /run/secrets/
    journalctl -b | grep -i sops

`/run/secrets` must exist and contain `igor-pw`.

### Uncomment `hashedPasswordFile`

`config.nix:21` is commented out, yet `passwd -S igor` shows a password is set —
it was set by hand and exists nowhere in this config. A from-scratch rebuild
produces an unusable account. This is the single biggest gap between the repo
and the running machine.

### `secrets.nix` uses the wrong sops backend

`sops.gnupg.sshKeyPaths` with an ed25519 host key cannot work — `ssh-to-pgp` is
RSA-only. The age path (auto-defaulted by sops-nix) is what actually runs.
Switch to an explicit `sops.age.sshKeyPaths` and drop the gnupg line.

### Add automatic garbage collection

The `nix.gc` block at `config.nix:31-35` is commented out, and its
`--delete-older-than` has an empty argument so it would not have parsed.
Root is 12G/32G used on a 32G disk.

---

## Priority 2 — security (internet-facing)

### Disable password auth

`sshd -T` currently reports:

    PasswordAuthentication yes
    KbdInteractiveAuthentication yes

Both must be off before this holds mail and a password vault. Set in
`modules/nixosModules/services/ssh.nix`.

### Drop X11 forwarding

`services/ssh.nix:6` sets `X11Forwarding = true` on a headless VPS.

### Add fail2ban or sshguard

Nothing is currently rate-limiting auth attempts.

### Stop enabling Docker unconditionally

`modules/nixosModules/common.nix` imports `docker`, which is enabled with no
gate — it is running now, injecting NAT chains and a `docker0` bridge on a
machine with no containers. `nas`, `ai`, and `virt` are at least behind enable
flags. Give docker the same treatment, or split a headless profile that omits
it.

### Trim irrelevant secrets and groups

- `secrets.nix` deploys `wifi-turtle-reef` to a VPS with no wifi.
- `users.nix` gives `igor-headless` the `networkmanager`, `i2c`, and `dialout`
  groups, none of which apply here.

---

## Priority 3 — backups (btrbk is currently non-functional)

### Path mismatch

`modules/nixosModules/services/btrbk.nix:57` hardcodes
`volume = "/mnt/btrfs-pool"`. disko actually mounts:

- `/mnt/btrfs-pool-root` — vda, subvolid 5
- `/mnt/btrfs-pool-data` — vdb, subvolid 5

The tmpfiles rule at `config.nix:115` creates `/mnt/btrfs-pool/btrbk-snapshots`,
a plain directory on the root filesystem that is not a pool at all.

### Module only supports one volume

The stated plan needs two: `/var/lib` on vdb, and everything-except-`@nix` on
vda. Parameterize the volume, or emit two instances.

### Notes

- Mounting subvolid 5 at `/mnt/btrfs-pool-*` is the right pattern for btrbk —
  keep it.
- Do not add `@swap` to any snapshot list; btrfs refuses to snapshot a subvolume
  holding an active swapfile.
- The vda backup is arguably optional, since everything outside `/var/lib`
  should be reproducible from this repo.

---

## Priority 4 — `/boot` sizing — RESOLVED in `disk.nix`

ESP resized 256MiB → 1GiB and the EF02 partition 1MiB → 2MiB, applied and
building. Takes effect on the next install; see `billy-reinstall-plan.md`.

The earlier recommendation below — move `/boot` onto btrfs and delete the ESP —
was **rejected**: the EFI binary must live on vfat, so dropping the ESP would
forfeit UEFI support. Keeping the ESP means one config boots both firmware
types, since `install-grub.pl:653` returns `"both"` and installs `i386-pc` to
EF02 and `x86_64-efi` to the ESP on the same run. `efiSupport = true` and
`efiInstallAsRemovable = true` are therefore **not** dead settings — they are
what makes the config portable across BIOS and UEFI instances. Leave them.

`configurationLimit = 10` is fine at 1GiB and needs no change.

Original analysis, retained for the reasoning:

ESP is 256MiB (`disk.nix:21`, 253MB usable), `configurationLimit = 10`.

`/boot` is vfat and a _different filesystem_ from `/nix/store`, so
`install-grub.pl:105-108` forces `copyKernels = 1`, overriding the `false` this
config evaluates to. Kernels are real copies, not symlinks — vfat has no symlink
support. Current cost is 13.6MB bzImage + 31.6MB initrd = 44MB.

Copies are named by store hash and dedupe, and `install-grub.pl:670` prunes sets
no longer referenced, so the ceiling is `configurationLimit` _distinct_ kernel
sets, not 10 unconditionally. Today: 2 generations, 1 kernel set. The initrd is
the heavy item and gets a new hash on every nixpkgs bump that moves the kernel;
config-only changes cost nothing. Ten generations spanning several kernel bumps
lands at roughly 220–350MB against 253MB.

Superseded options, kept for context: dropping `configurationLimit` to 4 was the
stopgap while the ESP was still 256MiB, and moving `/boot` to btrfs was the
no-copying option — ruled out by the UEFI requirement above, which also avoids
putting zstd decompression in GRUB's boot path.

---

## Priority 5 — stale / no-op settings

### tmpfiles no-CoW rules are all wrong (`config.nix:102-116`)

- `/var/lib/bitwarden_rs` — with `stateVersion = "26.11"` nixpkgs resolves
  vaultwarden to `/var/lib/vaultwarden`. The `bitwarden_rs` name only applies
  below stateVersion 24.11.
- Stalwart uses `/var/lib/stalwart` (`stalwart-mail` only below 26.05).
- `/var/vmail` and `/var/lib/postfix` are Dovecot/Postfix paths that will not
  exist under Stalwart — delete.
- `h` only sets attributes on an **existing** path; it will not create one, so
  these silently no-op before first service start. A `d` rule must come first.
- `+C` conflicts with the `compress-force=zstd:3` set on `/var/lib` in
  `disk.nix`. Decide which is actually wanted — NOCOW files are not compressed.

### Minor

- `noautodefrag` in `disk.nix` is the btrfs default — a no-op.
- `users.nix` sets `gitKeys.billy = "placeholder"`, which yields a broken git
  signing config if anything reads it.

---

## When adding the services

- Open firewall ports: 25/465/587/993 (Stalwart), 80/443 (ACME + Vaultwarden).
  Only port 22 is open today.
- Vultr blocks outbound port 25 by default — SES relay sidesteps this. Configure
  Stalwart to relay through SES on 587/465 with credentials from sops.
- SES handles outbound reputation, so no PTR record is needed on billy's IPs.
  Inbound 25 is still required if billy is to _receive_ mail directly.
- Both services store state under `/var/lib`, which is the vdb block device —
  matches the backup plan.
