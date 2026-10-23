# Phase 14 device log analysis — 2026-10-23

## Later pass on installed `da7eb21`

2026-10-23 evening. Source
`da7eb2128294d2ef3d48a6691dd857da75ae8e89`. Squashfs
`f08c3fa8795565e4195f307ca194b7c16fb8429a1c3b0bde0b960236dc1b1fd1`.
GPU `libmali`. Seed `2026.06.23-0015`. Archive
`Portmaster and gpu report.zip`, SHA-256
`4c101d6e5e8b9ddff202795a247ca36bd87fd58648e3cce04e3b0751e954abb8`.
This section does not rewrite the `3da3f2b` table below.

Shards of God started and the maintainer reports usable pad input
after `shardsofgod.gptk` was restored without overwriting the
Syncthing conflict file. Winter Travelers failed: SDL2 disabled the
hardware cursor (`drmModeMoveCursor failed (-14)`), then AGS reported
`Failed to load GL` and `Cursor not initialized properly`, then a
segmentation fault. The soft-fail in this image did not fix that
launch. Steel Assault failed to reach `mono` after `taskset not
found`, `mount: bad address 'opt'`, and a doubled `/opt` squashfs
path. The squashfs file is on SD2. GL4ES logged `GL4ES_READY` on
Mali-G52 with `LIBGL_FB=3` and did not log `GL4ES_DONE`; the screen
stayed black. SDL3 logged button events and `SDL3_DONE frames=512
input=1` without a visible pad reaction in the probe. Box86's legal
console probe exited 0 with `box86-x86 4 475f677f`. DRM debugfs
clients were unavailable. The format=3 campaign on this image is not
an acceptance tool. The format=4 OTA is uninstalled. The decision
note is `docs/research/phase14-portmaster-architecture-proposal.md`.
It is not approved.

## Earlier analysis — `3da3f2b`

Phase 14 stays OPEN. This note records the maintainer log archive
`ph14-PORTS.zip` (SHA-256 `66c30d61…`) against installed image
`zlyme-my355-20261023-3da3f2bafe05.tar` (squashfs
`ad9c430a9efde75156146d2d2f1b26a2cc2e4bba1fc1f29f3cc7f4931bcfb320`,
NextUI `b0960dcde4d69d32871d6605c354b1b901621eb5`). Archive path:
`/home/ale/Downloads/DISPOSABLE/ph14-PORTS.zip`. SSH to the Flip timed
out during this analysis pass; process claims below are from the
uploaded logs and host reproduction only.

## Hardware results on `3da3f2b` (maintainer)

| Item | Status | Evidence bound |
| --- | --- | --- |
| Normal boot / NextUI | PASS | maintainer |
| Abombniball MENU+START | PASS | prior acceptance retained |
| RetroArch normal exit / MENU+START | PASS | maintainer |
| PortMaster GUI exit | PASS | maintainer |
| PPSSPP / Splore exit | PASS | maintainer |
| SDL3 window/render / clean return | PASS | maintainer; input NOT YET ACCEPTED |
| Ascent DX on libmali | PASS | launch observed; Panfrost FAIL |
| Shards of God on Mali | launch PASS; controls FAIL | start observed; input not working |
| Rakuen / LISA The Painful | PASS | LISA log has Audio.dat/lang.dat mount warnings; success retained |
| GL4ES triangle (Mali and Panfrost) | FAIL | `system-2/session.txt` |
| GL4ES return to NextUI | FAIL | `pak exit 1` |
| Winter Travelers | FAIL | `PORTS.log` |
| Mina the Hollower | FAIL | incomplete log in archive |
| Skautfold / Steel Assault | NOT PROPERLY TESTED | Skautfold log shows missing `game.droid` |

## Failure analysis

### PAK `initial TERM scan was incomplete`

Seen four times in `system-0/session.txt` interleaved with PortMaster
launches that later show `zlyme-input: built-in target already ready`
and mount cleanup. The warning is emitted from
`stop_session_bounded()` when `signal_session()` returns non-zero on
the first SIGTERM pass.

Root cause: when MENU+START (or any waiter stop) races a leader that
has already exited or become a zombie, the old `leader_identity_ok()`
treated that identity as a hard scan failure and aborted member
collection. Cleanup could still succeed afterward via
`wait_child_bounded` + `reap_session`, so the line did not prove
status 125. Host fix: classify a matching zombie or absent leader as
session state 0, still collect members by SID, and only fail closed on
PID reuse or unreadable `/proc`. Fail-closed status 125 is unchanged
for true unresolved ownership.

### GL4ES `kmsdrm not available`

`system-2/session.txt` order:

1. `LIBGL: Error while gathering supported extension`
2. `GL4ES_SDL_ERROR kmsdrm not available`
3. `LIBGL: using GBM` / `GBM on card /dev/dri/card0 is Available`
4. `pak exit 1`

`zlyme-gl4es-run` defaulted to `LIBGL_FB=4` (direct GBM). That opens
the card during `libGL` load inside `SDL_Init`, racing SDL2 KMSDRM's
master probe. Host fix: default `LIBGL_FB=3` (SDL window) and
`SDL_VIDEODRIVER=kmsdrm`, with probe logging of drivers, env, and
context. Hardware gate remains the triangle on both Mali and Panfrost
with clean NextUI return — separate GPU boots.

### Winter Travelers

`PORTS.log`: AGS 3.6.2 requests D3D9 (Windows default in config), falls
through to OpenGL, then `Failed to init gfx mode. Error:
drmModeMoveCursor() failed`, then segfault. Initial save bind-mount
`umount: Invalid argument` is the usual first-run missing mount and is
harmless once the bind succeeds.

`drmModeMoveCursor` is SDL2 KMSDRM hardware cursor movement. On this
DRM config the cursor BO can exist while move still fails; AGS treats
that SDL error as fatal. Fix is a narrow SDL2 soft-fail that keeps
software mouse state and logs once — not a global DRM-master change
and not an edit of proprietary game assets.

### `systemctl: not found`

Exact upstream finish line in PortMaster-New `ioawn4t` script:

`$ESUDO systemctl restart oga_events &`

Zlyme already translates that exact argv to `zlyme-input ensure`. The
device still hit `exec systemctl` (BusyBox line ~470). The matching
failure mode for card scripts edited on Windows is a trailing CR on
`oga_events`, which breaks `[ "$2" = oga_events ]`. Host fix: strip CR,
accept `.service`, log untranslated `systemctl` argv. No fake systemd.

### Skautfold

`PORTS.log.1`: `gmloadernext` Android runner; missing
`lib/arm64-v8a/libopenal.so`; `Unable to find game:
/roms/ports/skautfoldinsanity/saves/game.droid`. Classification:
`EXTERNAL DATA REQUIRED` at that path. Not a GPU failure. Do not
fabricate APK data.

### LISA warnings vs PASS

`PORTS.log.2`: RGSS3, `GL renderer Mali-G52`, `Failed mounting
Audio.dat` / `lang.dat`. Maintainer PASS retained; mount warnings are
data packaging noise, not a process-lifecycle failure.

### Incomplete in archive

Ascent DX Panfrost, Mina complete log, Shards controller path, dual-GPU
GL4ES — need fresh per-run evidence via the opt-in validator.

## Automated validation

Installed helpers (opt-in Tools PAK via `phase14-probe-paks install`):

- `phase14-portmaster-inventory` — classify every `*.sh` under both
  libraries' `Roms/Ports (PORTS)/`
- `phase14-portmaster-validate` **format=4** — claims one ELIGIBLE
  port into `active-run` with claimer pid+starttime, holds the
  campaign lock, and `exec`s canonical `PORTS.pak/launch.sh`.
  No in-session timer or post-observer. Exit is MENU+START or the
  game's own exit. SSH `observe` records post-session evidence.
  `complete` advances the cursor only after the claimer identity
  has ended and machine evidence shows: observe ran, NextUI
  restored, owned mounts none, no pak-cleanup 125, no foreign DRM,
  and no `blocked` file. User labels are not that proof.
  `fail`/`retry`/`reset`/`start` refuse while the claimer is live
  or any active-run is unresolved. Library identity is part of
  campaign identity. Lock owners are pid+starttime.
- `phase14-port-observer` — optional bounded SSH-side samples
- Per-run logs under the campaign `runs/` directory, named
  `$id-$gpu-$stamp.log` (does not rotate `PORTS.log`)
- Suite budget only; no automated kill of a saved numeric PID
- Mali then Panfrost require separate campaigns/boots; GPU setting
  is not flipped mid-run

Statuses allowed in the campaign matrix: PASS, FAIL, BLOCKED, NOT RUN,
EXTERNAL DATA REQUIRED. Process exit is never treated as render/input
PASS.

## Evidence matrix (this archive + host fixes)

| Port | GPU | Runtime | Data | Process | Render | Input | Audio | Exit | MENU+START | DRM | Mounts | NextUI | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GL4ES probe | both | GL4ES+SDL2 | n/a | launched | FAIL | n/a | n/a | 1 | n/a | — | — | returned after fail | FAIL |
| SDL3 probe | — | SDL3 | n/a | PASS | PASS | NOT YET | — | PASS | — | — | — | PASS | PARTIAL |
| Winter Travelers | Mali | AGS 3.6.2 | present | launched | FAIL cursor | gptokeyb | OpenAL opened | segfault | — | — | bind ok | returned | FAIL |
| Skautfold | — | gmloadernext | missing game.droid | launched | — | — | OpenAL missing | fail | — | — | — | returned | EXTERNAL DATA REQUIRED |
| LISA | Mali | RGSS3 | Audio/lang warn | launched | PASS (obs) | — | — | PASS (obs) | — | — | warn | PASS | PASS |
| Shards | Mali | AGS | present | launched | PASS (obs) | FAIL | — | — | — | — | — | — | FAIL (input) |
| Ascent DX | Mali | LÖVE | present | launched | PASS (obs) | — | — | — | — | — | — | — | PASS (Mali only) |
| Ascent DX | Panfrost | LÖVE | present | — | FAIL (obs) | — | — | — | — | — | — | — | FAIL |
| Mina | — | Machismo/Vulkan | — | — | FAIL (obs) | — | — | — | — | — | — | — | FAIL (incomplete log) |
| Steel Assault | — | Mono | — | NOT RUN | — | — | — | — | — | — | — | — | MISSING_RUNTIME likely |
| Rakuen | — | — | — | — | PASS (obs) | — | — | — | — | — | — | — | PASS |

Cells marked `(obs)` are maintainer observation without a complete
per-run archive transcript.

## Remaining maintainer hardware gates

1. Rebuild/install candidate with the host-tested fixes below; leave
   uninstalled until testing.
2. GL4ES triangle on Mali, then Panfrost, clean NextUI return.
3. Winter Travelers launch after SDL cursor soft-fail; physical render,
   mouse/gptokeyb, exit.
4. SDL3 physical controller input.
5. Shards controls on Mali; Ascent DX on Panfrost with fresh logs.
6. Mina complete bounded log.
7. Skautfold only after `game.droid` exists at the expected path.
8. Steel Assault only with official PortMaster Mono runtime present.
9. Opt-in validation Tools queue across eligible ports, both GPUs.
10. Box86/ARMHF real device, RetroArch HDMI CRTC 1280×720/74250 kHz,
    14J/N/L disposable fixtures as still open in the roadmap.

Do not mark Phase 14 complete while observed failures remain. Do not
start Phase 15.

## Live card inspection on `192.168.0.108` (read-only)

Installed squashfs SHA matches `ad9c430a…`. GPU mode `libmali`.

### Shards of God controls

Launch script runs `$GPTOKEYB "ags" -c "./shardsofgod.gptk"`, and the
resolution `sed` edits that same path. On the card the only mapping file
is `shardsofgod.sync-conflict-20260615-095224-KAO2TYI.gptk`. There is no
`shardsofgod.gptk`. That is a Syncthing conflict rename, not a Zlyme
input daemon defect. Mapping content is mouse emulation (dpad/analog →
mouse move, A/B → mouse buttons). Fix on the card: restore the expected
filename. Do not change global InputPlumber mapping for this.

### Skautfold

Tree has `assets/data.win`, `skautfoldinsanity.port`, and
`gmloadernext.aarch64`, but no `saves/game.droid`. `patchlog_error.txt`
records `Missing zip!` / `Patching process failed.` while
`patchlog.txt` already exists, so the launcher skips the patcher on
later runs. Classification remains EXTERNAL DATA / failed APK patch —
not a GPU failure. Do not fabricate the Android game blob.

### Steel Assault

`mono-6.12.0.122-aarch64.squashfs` is present under
`Ports (PORTS)/PortMaster/libs/`. `steelassault/log.txt` is only
`mono: command not found`, so a prior launch did not get a usable
mounted Mono bind. Runtime bytes exist; mount/PATH for that launch
failed. Re-test after the oga_events/systemctl and mount fixes; do not
install a global Mono package.

## Candidate OTA history (UNINSTALLED except baseline)

Installed accepted baseline remains `3da3f2bafe05` (squashfs `ad9c430a…`).

| Candidate | Status |
| --- | --- |
| `0a3cce950da4` | Do **not** install (superseded). |
| `3486b510aa8e` | **Blocked.** Tar `42bc535f…`, squashfs `f0b961a4…`. Validator lifecycle defects below. Do **not** install. |
| `da7eb2128294` | **Installed for hardware.** Squashfs `f08c3fa8…`. Still ships format=3 validator. Do **not** run campaign complete/fail/retry/start/reset on this image for queue acceptance; use normal Ports launches and passive SSH until format=4 OTA. |
| `074949c025c3` | **format=4 replacement (UNINSTALLED).** Verified-completion gates. Leave uninstalled until ready. |

### Replacement OTA `074949c025c3` (UNINSTALLED)

Built from `074949c025c3da0951c0b1f0c27d3822c561a5e2`. Supersedes format=3
`da7eb21` for validator campaign use. Installed device may still be
`da7eb21` until this is applied.

| Artifact | SHA-256 |
| --- | --- |
| `zlyme-my355-20261023-074949c025c3.tar` | `7d486c04575c228bd150cfbe826e9ec7457ac6abb184e96e5c82c676967663cb` |
| squashfs `zlyme` | `f241c05d61c5b3c7a59ef8592b8e453a334cd1e101cf9c043f5426fe8d82e873` |
| `Image.gz` | `564b6009d46a7a2b3922fa8de0dcec35603f28bf635fec21b7c82626054808de` |
| `rk3566-miyoo-flip.dtb` | `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18` |
| `idbloader.img` | `ff773a4fc97a65475639fed61f8cac86c79639e9e6498b37cfca82f296cca43e` |
| `u-boot.itb` | `59b828c86b6874a68918ffa73cf347190d02e3864dfac4d78874aae9f17843d7` |

Squashfs validate matches source (`format=4`, `require_completion_evidence`).

### Replacement OTA `da7eb2128294` (UNINSTALLED)

Built from `da7eb2128294d2ef3d48a6691dd857da75ae8e89` on `zlyme44.4-phase-14`.
Supersedes blocked `3486b510aa8e`. Installed baseline stays `3da3f2bafe05`.

| Artifact | SHA-256 |
| --- | --- |
| `zlyme-my355-20261023-da7eb2128294.tar` | `3efea80f648215e15b69ce2dc9f8eac8a0e5851b74291bfdac3ea86fb6fd5e2a` |
| squashfs `zlyme` | `f08c3fa8795565e4195f307ca194b7c16fb8429a1c3b0bde0b960236dc1b1fd1` |
| `Image.gz` | `564b6009d46a7a2b3922fa8de0dcec35603f28bf635fec21b7c82626054808de` |
| `rk3566-miyoo-flip.dtb` | `f4e159435e29428a7f1a391e238bd42225b4220fa58f2d0031a7a1011ed55d18` |
| `idbloader.img` | `ff773a4fc97a65475639fed61f8cac86c79639e9e6498b37cfca82f296cca43e` |
| `u-boot.itb` | `59b828c86b6874a68918ffa73cf347190d02e3864dfac4d78874aae9f17843d7` |

Squashfs `phase14-portmaster-validate` matches source (`format=3`, no timer/observer PID kill).

## Validator lifecycle fix (blocks `3486b51`)

| Item | Verdict |
| --- | --- |
| `$(arm_timeout_waiter)` / `$(start_post_observer)` blocking PORTS exec | Confirmed under bash, dash, and BusyBox ash (~2s stall). **Removed** both helpers; `cmd_run` claims then `exec`s PORTS with no background command-sub. |
| Delayed `kill -TERM` of a saved waiter PID | Confirmed unsafe (PID reuse). **Removed.** Exit is MENU+START / game exit. |
| Post-observer inside the PAK session | Confirmed: cleaned with the session. **Moved** to SSH `observe` after the session ends. Frontend return does not depend on it. |
| Lock released before `exec` | Confirmed: a second runner could advance. **Fixed:** lock + `active-run` held for the in-flight claim; cursor advances only on `complete`; `fail`/`retry` keep identity. |
| Tools validator duplicating PORTS setup | Still fixed: `exec` canonical `PORTS.pak/launch.sh`; `launch_is_ports` matches Validation Tools. |
| `LIBGL_FB=3` / SDL HW cursor / systemctl arity | Retained as previously corrected. |

### Shards card repair (2026-10-23, on installed `da7eb21`)

On `/mnt/sd2/Roms/Ports (PORTS)/shardsofgod/`, only the Syncthing
conflict file `shardsofgod.sync-conflict-20260615-095224-KAO2TYI.gptk`
existed. Launcher expects `./shardsofgod.gptk`. Mapping is mouse
emulation for AGS (compatible with `$GPTOKEYB` + InputPlumber virtual
pad; no global config change). Copied with `cp -n` to
`shardsofgod.gptk`. Conflict original retained and byte-identical.
Physical Shards input still needs a maintainer launch.

### Maintainer sequence on installed `da7eb21` (until format=4 OTA)

1. Do **not** use validator `complete`/`fail`/`retry`/`start`/`reset`
   for acceptance on format=3.
2. Normal Ports / probe Tools launches only.
3. Passive SSH: unique log path, DRM clients, owned mounts, NextUI
   pid, exit observation. Keep screen/input/audio notes separate.
4. Priority: GL4ES both GPUs; Winter Travelers cursor; Steel Mono;
   Shards input after gptk restore; Ascent Panfrost; Mina; Box86;
   SDL3 pad; RetroArch HDMI CRTC.

### Maintainer sequence after format=4 OTA

1. Install the format=4 candidate only when ready (leave uninstalled
   until then). Confirm squashfs hash.
2. `phase14-portmaster-validate start` (one campaign per GPU boot).
3. Tools → Zlyme PortMaster Validation (one game per launch).
4. Exit with MENU+START or the game exit.
5. SSH: `observe`, then `complete` only if evidence gates pass; else
   `fail` / `retry` after the claimer has ended.
6. Continue the named-port and 14A–14O hardware gates.

