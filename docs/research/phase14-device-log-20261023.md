# Phase 14 device log analysis — 2026-10-23 (`3da3f2b`)

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
- `phase14-portmaster-validate` — one ELIGIBLE port per Tools launch,
  reusing PORTS.pak prepare/bind/drm-release/script execution
- `phase14-port-observer` — bounded process/DRM/mount samples
- Per-run logs under `/storage/.config/zlyme/phase14-validate/runs/`
  named `$id-$gpu-$stamp.log` (does not rotate `PORTS.log`)
- Suite budget and per-port timeout; timeout signals only the recorded
  session leader (not MENU+START, not `killall`)
- Mali then Panfrost require separate boots; GPU setting is not flipped
  mid-run

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

## Candidate OTA (UNINSTALLED) — supersedes `0a3cce9`

Do **not** install `0a3cce950da4`. Installed baseline remains `3da3f2b`.

Built from `3486b510aa8e` on branch `zlyme44.4-phase-14`.

| Artifact | SHA-256 |
| --- | --- |
| `zlyme-my355-20261023-3486b510aa8e.tar` | `42bc535f986201b0c6bec5e56d663ab98a0ae544c6fcecb92066261642fa8b3e` |
| squashfs `zlyme` inside tar | `f0b961a429d4c8e76eed3a9d842b258f0eabd50c5cc63c349281bf56c6b86e24` |

Host-verified in `output/target`: PORTS validation exec path, `launch_is_ports` for the Validation Tools PAK, systemctl arity guards, GL4ES PBuffer comment/`LIBGL_FB:=3`, SDL "disabling HW cursor", NextUI pin `b0960dcde4d69d32871d6605c354b1b901621eb5`.


## Validator and runtime correction pass (pre-install)

Do **not** install `0a3cce9`. Installed baseline stays `3da3f2b`.

### Confirmed defects vs false alarms

| Item | Verdict |
| --- | --- |
| Tools validator duplicating PORTS setup / skipping `launch_is_ports` cleanup | Confirmed. Fixed: Validation PAK `exec`s canonical `PORTS.pak/launch.sh`; `launch_is_ports` also matches the Validation Tools path. |
| Timeout SIGTERM to validation shell only | Confirmed incomplete. Fixed: timeout signals the pak-spawn **waiter** (`PPID`), which owns `stop_session_bounded`. |
| `pidof nextui.elf` inside the Tools PAK | Confirmed false PASS risk. Fixed: post-observer runs after the leader exits and records `NEXTUI_RESTORED` separately. |
| Persistent queue / suite-started after reset | Confirmed. Fixed: campaign IDs per GPU/boot/squashfs; `reset` clears active campaign and suite budget; reports retained; flock-style lock. |
| `LIBGL_FB=3` as "SDL framebuffer" | Documentation error. Upstream USAGE: FB=3 is **PBuffer**; FB=4 is **GBM**. Kept FB=3 to avoid GBM DRM race; comment corrected. |
| SDL MoveCursor soft-success | Too weak. Revised patch disables/destroys the HW cursor BO on first failed move, clears the SDL error, and returns success from warp so AGS can continue without a frozen plane. |
| systemctl `$1`/`$2` under `set -u` | Confirmed. Arity checked before reading args. |

### Maintainer sequence after replacement OTA

1. `phase14-portmaster-validate start` (one campaign per GPU boot).
2. Tools → Zlyme PortMaster Validation (one game per launch) **or** launch Ports normally with observer.
3. GL4ES Mali then Panfrost; Winter Travelers cursor; Shards gptk restore; Steel Mono mount; Ascent Panfrost; Mina log; SDL3 pad; Box86; HDMI CRTC.

