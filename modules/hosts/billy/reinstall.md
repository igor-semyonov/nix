# billy — reinstall plan (nixos-anywhere, 2-stage)

Target: Vultr VPS, 1GB RAM, BIOS-booting today, `/dev/vda` (32G) + `/dev/vdb` (10G).
Goal: hybrid BIOS+UEFI disk layout, `/boot` sized properly, sops identity preserved.

Everything below runs from boxy. Billy is never booted into a live environment —
nixos-anywhere kexecs it into the installer.

---

## 0. Pre-flight — save the SSH host key FIRST

**Do this before anything else.** A fresh install regenerates
`/etc/ssh/ssh_host_ed25519_key`, which changes billy's derived age identity and
invalidates the sops rekey. The running machine is currently the only place that
key exists.

```bash
# Durable backup — NOT /tmp, which is wiped on reboot.
mkdir -p ~/billy-hostkey-backup && chmod 700 ~/billy-hostkey-backup
scp root@ssh.nalgor.com:'/etc/ssh/ssh_host_*_key*' ~/billy-hostkey-backup/
```

Now stage it in the layout `--extra-files` expects (it mirrors the target root):

```bash
export BILLY_EXTRA=$(mktemp -d)
install -d -m755 "$BILLY_EXTRA/etc/ssh"
cp ~/billy-hostkey-backup/ssh_host_ed25519_key      "$BILLY_EXTRA/etc/ssh/"
cp ~/billy-hostkey-backup/ssh_host_ed25519_key.pub  "$BILLY_EXTRA/etc/ssh/"
cp ~/billy-hostkey-backup/ssh_host_rsa_key          "$BILLY_EXTRA/etc/ssh/"
cp ~/billy-hostkey-backup/ssh_host_rsa_key.pub      "$BILLY_EXTRA/etc/ssh/"

chmod 600 "$BILLY_EXTRA/etc/ssh/"*_key
chmod 644 "$BILLY_EXTRA/etc/ssh/"*_key.pub
```

Permissions matter and are preserved. nixos-anywhere transfers this with:

```bash
tar -C "$extraFiles" -cpf- . | runSsh "tar -C /mnt -xf- --no-same-owner"
```

`-p` keeps modes; `--no-same-owner` makes everything root-owned on extract. If
the private key is not `0600`, sshd refuses it and sops silently fails again.

### Verify the identity before you wipe anything

```bash
nix run nixpkgs#ssh-to-age -- -i "$BILLY_EXTRA/etc/ssh/ssh_host_ed25519_key.pub"
```

Must print exactly:

```
age1g583g409lqgdl7280txta57vf295l8ynn66860253w2hdgdll5sqw6qyve
```

If it does not match the recipient in your `nix-secrets` `.sops.yaml`, stop and
fix the rekey first — otherwise the new install comes up with broken secrets.

The RSA key is included only to avoid `known_hosts` churn; sops uses ed25519.

---

## 1. Disk layout changes (`modules/hosts/billy/disk.nix`)

Hybrid BIOS+UEFI on one config. `install-grub.pl:653` returns `"both"` when
`efiSupport = true` and a real `device` is set, so line 757 installs `i386-pc`
into the EF02 partition and line 774 installs `x86_64-efi` into the ESP on the
same run. Whichever firmware the instance has, it boots.

| Partition | Type | Size       | Purpose                               |
| --------- | ---- | ---------- | ------------------------------------- |
| `boot`    | EF02 | `2048K`    | GRUB `core.img` for BIOS/GPT          |
| `esp`     | EF00 | `1048576K` | vfat, mounted `/boot`; GRUB + kernels |
| `root`    | —    | `100%`     | btrfs, subvolumes as today            |

Sizes are written in explicit KiB (literal for the small partition, calculated
`${toString (1024 * 1024)}K` for the ESP) so there is no decimal-vs-binary
ambiguity in how the size string is parsed.

Subvolumes — `vda`: `@`, `@home`, `@root`, `@nix`, `@var-log`, `@tmp`,
`@var-tmp`, `@var-cache`, `@swap` (5 GiB swapfile, no mount options since btrfs
swapfiles reject compression), plus top-level at `/mnt/btrfs-pool-root`.
`vdb`: `@var-lib`, `@stalwart` → `/var/lib/stalwart`,
`@vaultwarden` → `/var/lib/vaultwarden`, plus top-level at `/mnt/btrfs-pool-data`.

`@tmp`/`@var-tmp`/`@var-cache` exist to keep transient and regenerable data out
of `@` snapshots. The two service subvolumes give independent snapshot and
rollback, and let `nodatacow` be set per-service later without migrating live
data. They are deliberately **not** `nodatacow` now: frequent snapshots largely
defeat it (the first write to each block after a snapshot is CoW regardless),
and it implies `nodatasum`, which forfeits corruption detection on a password
vault.

**Applied — `disk.nix` is already updated and building.** Verified by eval:
`boot` = `2048K`/EF02, `esp` = `1048576K`/EF00, `root` = `100%`.

Changes made:

- `boot`: `1024K` → `2048K`. 1 MiB suffices with `/boot` on vfat (core.img only
  needs `fat` + `part_gpt`), but 2 MiB is free headroom.
- `esp`: `256 MiB` → `1 GiB`. `/boot` is a different filesystem from `/nix/store`, so
  `install-grub.pl:105-108` forces `copyKernels = 1` regardless of the option —
  kernels are real copies, ~45M per distinct kernel+initrd set. Sets dedupe by
  store hash and are pruned at line 670, so the ceiling is `configurationLimit`
  distinct sets. 1G comfortably covers 10.
- `/dev/vdb` (`@var-lib`) is unchanged.

`config.nix` needs no bootloader changes — `efiSupport = true`,
`efiInstallAsRemovable = true`, `canTouchEfiVariables = false` are already the
correct trio. `--removable` writes `/EFI/BOOT/BOOTX64.EFI`, the firmware
fallback path, so a fresh UEFI instance boots with no NVRAM entries.

> Supersedes `todo-billy.md` P4, which recommended `/boot` on btrfs with no ESP.
> That is incompatible with UEFI — the EFI binary must live on vfat.

### Variant: ESP at `/boot/efi`

If you prefer the Gentoo-style split, set
`boot.loader.efi.efiSysMountPoint = "/boot/efi"` and add a third partition: a
small ESP (256M is ample — it holds only the EFI stub) plus a 1G ext4 `/boot`.
Mount nesting is handled automatically. Only worth it if you later want `/boot`
on btrfs to stop kernel copying, which reintroduces GRUB-reads-zstd-btrfs risk.

---

## 2. Stage 1 — kexec + partition

`--phases` resets **all** phases to 0 and enables only what you list:

```bash
--phases)
  phases[kexec]=0; phases[disko]=0; phases[install]=0; phases[reboot]=0
  IFS=, read -r -a phaseList <<<"$2"
  for phase in "${phaseList[@]}"; do phases[$phase]=1; done
```

So `--phases disko` alone **skips kexec** and would repartition the running
system's disk. Always include `kexec` in stage 1.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases kexec,disko \
  --flake .#billy \
  --extra-files "$BILLY_EXTRA" \
  root@ssh.nalgor.com
```

If kexec OOMs (upstream wants 1.5G excluding swap; billy has 1G but has done
this before), add `--no-disko-deps` — it selects the `NoDeps` disko variant that
expects partitioning tools already in the installer PATH instead of uploading
the full closure into the RAM-backed store.

---

## 3. Stage 2 — enable swap by hand

Required. disko creates the swapfile but never activates it: `swapon` lives in
`lib/types/swap.nix:97`, which only covers the standalone swap _content type_
(a whole partition). `lib/types/btrfs.nix` contains **zero** references to
`swapon` — subvolume swapfiles are only created, via
`btrfs filesystem mkswapfile --size 8G` (which handles NOCOW and mkswap).

**ssh is sufficient — no Vultr console needed.** The kexec'd installer runs
sshd, and disko leaves everything mounted under `/mnt`.

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@ssh.nalgor.com 'swapon /mnt/swap/swapfile && free -h && findmnt -R /mnt'
```

The `StrictHostKeyChecking` overrides are because the installer's host key
differs from billy's. Confirm `free -h` shows ~8G swap before continuing.

**Do not reboot between stages** — stage 3 depends on the `/mnt` mounts held by
this kexec environment.

---

## 4. Stage 3 — install + reboot

```bash
nix run github:nix-community/nixos-anywhere -- \
  --phases install,reboot \
  --flake .#billy \
  --extra-files "$BILLY_EXTRA" \
  root@ssh.nalgor.com
```

The closure goes to `/mnt/nix/store` on disk, not the RAM-backed installer
store, so disk space rather than RAM is the constraint here. Swap from stage 2
covers the nix daemon's working set.

---

## 5. Post-install verification

```bash
ssh root@ssh.nalgor.com '
  echo "== host key preserved =="; ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
  echo "== sops =="; ls -la /run/secrets/ && journalctl -b | grep -i sops
  echo "== boot mode =="; ls /sys/firmware/efi >/dev/null 2>&1 && echo UEFI || echo BIOS
  echo "== boot usage =="; df -h /boot; du -sh /boot/kernels
  echo "== efi stub present =="; find /boot/EFI -name "*.EFI" -o -name "*.efi"
  echo "== mounts =="; findmnt -t btrfs,vfat -o TARGET,SOURCE,FSTYPE --noheadings
  echo "== ipv6 =="; ip -6 route show default; ping -6 -c2 2606:4700:4700::1111
  echo "== failed =="; systemctl --failed --no-legend
'
```

Expected: host key fingerprint unchanged from before the reinstall,
`/run/secrets/igor-pw` present, `/boot` ~1G with ~45M used, `EFI/BOOT/BOOTX64.EFI`
present even under BIOS, v6 default route learned from RA.

Then clean up `known_hosts`, since the host key was preserved and should still
match:

```bash
ssh-keygen -R ssh.nalgor.com && ssh -o StrictHostKeyChecking=accept-new igor@ssh.nalgor.com true
```

---

## 6. Recovery

If billy does not come back: Vultr's web console is the fallback — the EF02 +
ESP hybrid means a firmware mismatch is not a failure mode, but a bad GRUB
install still is. `nix run github:nix-community/nixos-anywhere -- --phases kexec`
against a booted rescue image re-enters the installer to retry from stage 1.

Keep `~/billy-hostkey-backup/` until the install is verified. It is the only
copy of the sops identity.

---

## 7. Fold in afterwards

Items from `todo-billy.md` that this reinstall does not address and should
follow immediately, since the box will be internet-facing:

- Uncomment `hashedPasswordFile` (`config.nix:21`) — otherwise the manually-set
  password is still absent from the config and the install is not reproducible.
- Disable `PasswordAuthentication` and `KbdInteractiveAuthentication`.
- Add `nix.gc` — root was 12G/32G before the wipe.
- Fix the btrbk volume paths (`/mnt/btrfs-pool` does not exist).
- Correct the tmpfiles no-CoW paths (`/var/lib/vaultwarden`, `/var/lib/stalwart`).
