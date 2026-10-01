# Media pipeline notes

Operational knowledge for `media-ripping.nix` and `jellyfin.nix`
that is not obvious from the code. Mostly things that went wrong once.

## Shape of the pipeline

Nothing is automatic. `autoRip.enable = false` on boxy — discs are ripped by
hand.

```
rip-movie / rip-tv          you run these; they scan the disc, show a title
  (CLI, runs as you)        table, and write a JSON job
        |
        v  /var/lib/media-ripping/rip-queue/*.json
media-rip.path -> media-rip.service   (media-rip-worker: makemkvcon)
        |                              writes /mnt/8tb/media-rips/<stamp>-<name>/title-NNN.mkv
        v  /var/lib/media-ripping/encode-queue/*.json
media-encode.path -> media-encode.service  (media-encode-worker: SVT-AV1)
        |
        v  /mnt/8tb/@media/{tv,movies}/...   then pokes Jellyfin to rescan
```

`media-rip.service` is the **worker**, not the autoripper. A path unit does not
retrigger while its service is running, which is what keeps rips (contending
for the one drive) and encodes (for the CPU) strictly serial.

The two services are independent, so they **pipeline**: each title is queued
for encoding as soon as it is ripped, and the encoder (CPU-bound) runs
alongside the ripper (bound by the drive at ~8.5 MiB/s). On a five-episode
disc that saves roughly a whole rip-pass.

The consequence is that a disc failing on a later title leaves the earlier
episodes already in the library — correctly numbered, just incomplete. Check
`rip-queue/failed/` when a disc comes up short rather than assuming nothing
landed.

## Episode ordering: the thing that keeps biting

**A disc exposes three orderings and they disagree. None is authoritative.**

| ordering                             | what it is                                                | observed                         |
| ------------------------------------ | --------------------------------------------------------- | -------------------------------- |
| MakeMKV title index                  | its own numbering, reshuffled by its main-title heuristic | wrong on Dollhouse S1D1          |
| playlist (`.mpls`, TINFO 16)         | authoring order                                           | right on S1D1, **wrong** on S1D3 |
| clip (`.m2ts`, TINFO 26 segment map) | physical layout                                           | right on S1D3                    |

Dollhouse S1D1: MakeMKV enumerated `00785 00786 00788 00787 00789` as titles
0–4. Playlist order was correct; the title index silently swapped E03/E04.

Dollhouse S1D3: playlists `00800 00801 00799 00802` map to clips
`00390 00391 00392 00393`. Playlist order puts 00799 first, but 00799 is
_Epitaph One_ — the last episode of the season. Clip order gets it right.

`media-guess-titles` now sorts by **first clip in the segment map**, falling
back to the playlist name when MakeMKV reports no segment map. `rip-tv` prints
a loud warning when the two orderings disagree for the selected titles.

The warning is the point. Do not trust the default ordering on a disc that
warns — verify.

### Verifying: `rip-frames`

```sh
rip-frames /mnt/8tb/media-rips/<stamp>-<name>/        # whole rip dir
rip-frames -n 12 -c 4 some.mkv                        # denser sheet
```

Writes `./rip-frames/<name>.jpg`, a contact sheet of frames sampled across the
middle 80% of the runtime. Six frames is usually enough to name an episode.
This is the only check that cannot be fooled by a disc lying about its own
ordering, and it takes about ten seconds per title.

**Never verify an episode number by reading back the `.nfo` Jellyfin wrote.**
Jellyfin looked the episode up _by the number in the filename_; the NFO
agreeing with the filename proves nothing. This produced a confident, wrong
"verified" once already.

### Cross-checking against published runtimes

Disc review sites list per-item HD runtimes and they match the rip to the
second. This identified two Dollhouse S1D3 titles outright:

- 49:51 → _Epitaph One_
- 45:47 → unaired pilot _Echo_

High-Def Digest and Blu-ray.com both publish these. Worth a look before
guessing.

### Dollhouse S1 disc map (verified by frames)

| disc | titles                  | episodes                                         |
| ---- | ----------------------- | ------------------------------------------------ |
| 1    | playlists 00785–00789   | E01–E05, **in playlist order**                   |
| 2    | playlists 00785–00789   | E06–E10, in playlist order (= title index order) |
| 3    | 00800/00801/00799/00802 | E11, E12, E13, unaired pilot — **clip order**    |

Disc 3 also carries the unaired pilot _Echo_ (45:47, playlist 00802). It is a
different version of the first episode, not a duplicate; file it as
`Season 00`/`S00E01` so Jellyfin treats it as a special.

## Pitfalls

**Do not `just switch` while a rip or encode is running.** Editing anything in
this module changes the unit text, and activation SIGTERMs the running
service. The path unit then re-fires on the still-queued job and the rip starts
over _from title 0_. Three attempts and ~45 minutes of Blu-ray reads were lost
to this before `restartIfChanged = false` was added to `workerService`. That
option now prevents it, but a `systemctl restart` still would.

**`systemctl is-active --quiet` is false for a running oneshot.** It reports
`activating`, not `active`. Monitor loops must accept both or they exit
immediately and report that nothing happened.

**MakeMKV needs `/dev/sg*`, not just `/dev/sr0`.** Without the `sg` kernel
module it reports no drives at all. `boot.kernelModules = ["sg"]` handles it.

**MakeMKV builds self-expire (~60 days) and that only surfaces on a real
decrypt.** `makemkv-status` cannot detect it — an `info` scan succeeds and then
the rip fails with "This application version is too old". Currently pinned to
2.0.0 by an overlay in `modules/hosts/boxy.nix` with real hashes.

**An expired key is worse than no key.** MakeMKV with a lapsed `app_Key`
refuses outright instead of falling back to the 30-day evaluation.
`install_key` in the rip worker validates with `makemkvcon reg` and _removes_ a
key that fails, so evaluation can take over. As of 2026-09-30 there is no key
file at all and it is running on evaluation — 28 of 30 days left, so it needs a
key or a purchase before roughly 2026-10-28.

**Read errors vs. copy protection.** `HashCheck Errors` alongside `Read Error`
means genuine disc corruption (dirt, scratches) — clean the disc and retry.
Structural protection like ARccOS produces read errors _without_ hash failures.

**`rm -f "$stage"/*.mkv` inside a per-title loop deletes titles already
renamed.** Each title rips into its own `.title-N` scratch dir for this reason.
Slightly slower per rip; worth it.

**Audio dominates file size, not video.** On these Blu-rays the DTS-HD MA track
plus its redundant DTS core plus a stereo mix is 42–75% of the output. Tuning
the AV1 preset is rearranging deck chairs next to dropping unused audio tracks.

**8-bit, not 10-bit.** `pixelFormat = "auto"` picks 8-bit for SDR sources.
Forcing `yuv420p10le` produced `av01.0.04M.10`, which Firefox's MSE refuses, and
measured _worse_ (421 kbps at 0.988202 VMAF vs 420 at 0.987603).

**`film-grain` without `film-grain-denoise` does nothing** but cost ~5%
bitrate — the picture came back bit-identical. Default is now `filmGrain = 0`
with `filmGrainDenoise = true` available.

**Jellyfin's library monitor only watches folders that were non-empty at
startup.** A brand-new, empty library folder never gets a watcher; restart
Jellyfin after the first file lands or the real-time scan silently does
nothing.

**KDE Solid mounts discs explicitly via `Mount()`**, so a udev
`UDISKS_IGNORE=1` rule does not stop it. The fix is the plasma-manager
`device_automounter_kcmrc` settings in `modules/homeModules/kde.nix`. Takes
effect on next Plasma restart.

**Home-manager is NixOS-integrated on boxy** (`home-manager-igor.service`), so
`just switch` applies home config too. `just home` fails — there is no
standalone `home-manager` binary on PATH.

## Cheatsheet

```sh
# status
makemkv-status                       # MakeMKV build/key/evaluation state
systemctl status media-rip media-encode
journalctl -u media-rip -f | grep -v 'Current progress'
ls /var/lib/media-ripping/{rip,encode}-queue/          # pending
ls /var/lib/media-ripping/{rip,encode}-queue/failed/   # what broke

# ripping
rip-movie "Alien (1979)"
rip-tv "Dollhouse (2009) [tmdbid-14956]" -s 1 -e 11    # season 1, from ep 11
rip-tv "Dollhouse (2009) [tmdbid-14956]" -s 0 -e 1     # specials / unaired pilot
rip-titles ...                                         # lowest-level front end

# verify before trusting the numbering
rip-frames /mnt/8tb/media-rips/<stamp>-<name>/
rip-frames "/mnt/8tb/@media/tv/<show>/Season 01/"

# key management
sudo makemkv-update-key              # prompts hidden, or reads stdin
sudo makemkv-update-key < key.txt    # never pass the key as an argument

# after renaming library files by hand, drop the stale sidecars so Jellyfin
# regenerates them rather than reusing the old episode's metadata
rm -f "<name>.nfo" "<name>-thumb.jpg"; rm -rf "<name>.trickplay"
```

Beta keys rotate monthly; the MakeMKV forum thread "MakeMKV beta key" carries
the current one.

## Naming

`media-library-path` is the single definition. Provider IDs use a **hyphen**
and belong in _folder_ names only: `Dollhouse (2009) [tmdbid-14956]`, with
files named `Dollhouse (2009) - S01E11.mkv`. Season 00 is Specials. Multi-part
movies use `-part1`/`-part2`.

## Subtitles

**Bazarr was tried and removed.** It has no library scanner of its own — it is
a companion to Sonarr/Radarr and takes its media list from their APIs, so
there is no way to point it at `/mnt/8tb/@media`. It installs and runs
perfectly well on port 6767 and does precisely nothing. Using it would have
meant deploying Sonarr and Radarr purely as a library index.

`subliminal` replaced it, called per-file by the encode worker right after a
successful encode and before Jellyfin is told to rescan, so episodes are
indexed with their sidecars on the first pass. A provider failing never fails
an encode that already succeeded.

```sh
media-fetch-subtitles "/mnt/8tb/@media/tv/Some Show"   # backfill a directory
media-fetch-subtitles --age 7d /mnt/8tb/@media/tv      # only recent files
media-fetch-subtitles -f -v some.mkv                   # re-download, verbose
```

Configured by `igix.media-ripping.subtitles.*`: `languages` (empty disables
the whole thing), `providers`, `credentialsFile`, `minScore`, `forceEmbedded`.

**Credentials** are a `KEY=VALUE` file, mode 0400, owned by the rip user:

```
SUBLIMINAL_PROVIDER_OPENSUBTITLESCOM_USERNAME=...
SUBLIMINAL_PROVIDER_OPENSUBTITLESCOM_PASSWORD=...
```

On boxy that file is not written by hand: `opensubtitles_com_username` and
`opensubtitles_com_pw` live in the sops `default.yaml`, and a
`sops.templates."opensubtitles.env"` block in the host file renders them into
`/run/secrets/rendered/opensubtitles.env` at activation. Only
`<SOPS:...:PLACEHOLDER>` tokens reach the store — interpolating the secrets
into the content directly would publish them in a world-readable derivation.
Adding a provider login means adding a key to the sops file and a line to that
template, never a literal in the repo.

`..._APIKEY` is optional — subliminal ships its own consumer key. The file is
parsed, not sourced, and only `SUBLIMINAL_*` lines are honoured, because this
runs as the service account. Values reach subliminal through the environment,
never argv, so they stay out of {command}`ps`.

Only the `opensubtitles*` family and `addic7ed` need logins. `podnapisi`,
`tvsubtitles`, `gestdown`, `bsplayer`, `napiprojekt`, `subtitulamos` and
`subtis` are anonymous, which is why a few of them stay in the default
provider list as a fallback once quota runs out.

**Quota.** OpenSubtitles free allows 20 downloads/day and _each language
counts separately_ — three languages means roughly six episodes a day before
it dries up. The anonymous providers do not count against it.

**Embedded PGS.** Blu-ray rips ship embedded English subtitles, so subliminal
skips English by default, treating the embedded track as sufficient. PGS is a
bitmap: not searchable, restylable or scalable. `forceEmbedded = true`
overrides that, at the cost of spending quota on a language the disc already
carries.

## Services and ports

| service  | port | notes                                  |
| -------- | ---- | -------------------------------------- |
| Jellyfin | 8096 | NVENC via `igix.jellyfin.nvenc.enable` |

Jellyfin runs with `UMask = 0002` in group `media` so everything it writes
stays group-readable. Upstream hardcodes `0077`, which makes NFO sidecars and
artwork unreadable to everyone else; `jellyfin.nix` overrides it with
`lib.mkForce`.
