# PortMaster compatibility architecture review

Status: **NOT APPROVED**. This note is a decision proposal for maintainer
review. It is not current architecture. `docs/ARCHITECTURE.md` still
owns what Zlyme ships. Phase 15 has not started. `zlyme44.4` has not
released. No gate below is authorized work.

## Installed image

The 2026-10-23 PortMaster hardware pass used installed source
`da7eb2128294d2ef3d48a6691dd857da75ae8e89`, squashfs
`f08c3fa8795565e4195f307ca194b7c16fb8429a1c3b0bde0b960236dc1b1fd1`,
GPU `libmali`, PortMaster seed `2026.06.23-0015`. That image's
validator is format=3. The format=4 archive built from
`074949c025c3da0951c0b1f0c27d3822c561a5e2` is uninstalled and is not
an acceptance tool. Do not run the validation campaign for acceptance.

Earlier acceptances stay with their images. Abombniball MENU+START
stays on `c67692f`. Volume, Wi-Fi, HDMI television audio, and NextUI
at HDMI 720p stay on `0b35a90`. Looked-at list width stays on
`4652076`. Those sentences are not claims about `da7eb21`.

## Evidence read for this note

Archive `Portmaster and gpu report.zip`, SHA-256
`4c101d6e5e8b9ddff202795a247ca36bd87fd58648e3cce04e3b0751e954abb8`.
`PORTS.log.2` is Shards of God at 2026-10-23T20:55:20Z. `PORTS.log.1`
is Winter Travelers at 20:55:54Z. `PORTS.log` is Steel Assault at
20:56:30Z. `system-0/session.txt` is the GL4ES then SDL3 Tools
launches on the same boot. The version string in those launches is
`zlyme44.3 (2026-10-23)` and `PM_VERSION=2026.06.23-0015`.

The Box86 console line is from the same installed image, over SSH,
and is not a file in that zip. Graphical Box86 was not run.

DRM debugfs clients were unavailable on that image. The earlier
passive inspection saw `nextui.elf` as the only process with a
`/dev/dri/card0` descriptor while no port was running. That is not
a DRM-master PASS.

| Case | Result on `da7eb21` |
| --- | --- |
| Shards of God | AGS 3.6.2 reached `Starting game` with SDL2 software / OpenGL ES2 at 640×480. gptokeyb opened `./shardsofgod.gptk`. The maintainer reports usable controller input. The expected filename was restored with a non-overwriting copy from the Syncthing conflict file. The conflict original remains. This is one AGS port, not every AGS port. |
| Winter Travelers | FAIL. SDL2 logged `drmModeMoveCursor failed (-14); disabling HW cursor`. AGS then logged `Failed to load GL` and `Failed to init gfx mode. Error: Cursor not initialized properly`, then a segmentation fault. The cursor soft-fail already in this image did not make this launch work. A replacement design is not established. |
| Steel Assault | FAIL. The Mono squashfs is on SD2. The log has `taskset not found, bailing...`, `mount: bad address 'opt'`, mount source `//opt/system/Tools/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs`, and `mono: command not found`. That is a runtime path and mount failure. It does not prove the squashfs bytes are missing, and it does not by itself prove one shell-expansion bug. A shared PortMaster runtime-path contract is a design candidate. |
| GL4ES Tools probe | Context init observed, visible rendering FAIL. `LIBGL_FB=3`, KMSDRM, and `GL4ES_READY` with renderer Mali-G52 were logged. The screen stayed black. The maintainer used MENU+START. No `GL4ES_DONE` line was recorded. |
| SDL3 Tools probe | Event delivery PASS. Visual controller feedback NOT DEMONSTRATED. KMSDRM selected an OpenGL ES2 renderer. An Xbox 360 virtual pad was detected. Several `SDL3_INPUT` lines were logged, then `SDL3_DONE frames=512 input=1`. The maintainer saw no on-screen reaction to the pad. The probe source does not draw a response to those events. This is not an InputPlumber failure. |
| Box86 | Console probe exit 0, `box86-x86 4 475f677f`. Graphical Box86 untested. A libmali boot does not provide ARMHF GLES. |

Still open where this archive does not close them: Panfrost GL4ES,
Ascent DX on Panfrost, a complete Mina diagnostic, RetroArch's own
HDMI 720p CRTC, and the other named ports.

## Upstream comparison already on record

This pass did not fetch new upstream trees. The comparison below is
the one already recorded, plus the PortMaster facts from that review.

`Zetarancio/distribution`, branch `flip`, is a historical working
Miyoo Flip ROCKNIX fork. The recorded PortMaster pin there is
`2026.05.04-1202`. That tree uses ROCKNIX `compat.tar.gz` and
compatibility libraries, a distribution `control.txt`, mapper,
`oga_controls`, gptokeyb, and `/etc/profile` environment, and
`runemu.sh` for launch. Its Mali/Panfrost gpudriver switches global
graphics libraries and contains PortMaster-specific SDL handling.
A checkout of that fork was previously recorded at
`d249b09bd95120c65555b0c56bc381f72ce073bc` for kernel comparison.
That fork is comparison evidence. It is not the source of truth for
current Zlyme behavior, and it is not copied into
`docs/ARCHITECTURE.md`.

Official ROCKNIX, already cited in `docs/UPSTREAMS.md`: `next` at
`5e81daa9748b5139eaca899578da43c4e10e8724` was compared for the
unpack-on-storage pattern. `7cffc96617df2a051af091182e8a3d270fd794a4`
installs PortMaster `2026.09.13-0343` with `/usr/lib/compat` from
`compat.tar.gz`. That archive is not shipped by Zlyme. A newer
upstream `funcs.txt` is not treated as identical to the pinned Zlyme
seed `2026.06.23-0015`.

KNULLI is a Buildroot packaging reference. Its shell launcher
generates a controller database and exports an SDL controller map.
Its frontend and runtime conventions are not NextUI's. The reviewed
`knulli-main` commit remains
`57afa662009641d181f57241bcc480119b131530`.

Upstream PortMaster's portable contract is `control.txt`,
`device_info.txt`, `funcs.txt`, and `mod_<CFW>.txt`, plus
architecture-specific compatibility directories. Zlyme's seed stays
`2026.06.23-0015` until a later stable pin is reviewed.

Batocera is another Buildroot packaging reference. It is not a proven
Miyoo Flip runtime.

Another distribution shipping a proprietary library or binary blob
is not permission for Zlyme to redistribute it. Provenance and
license rules stay in `docs/UPSTREAMS.md`.

## Options

Preferred evaluation principle: adopt an upstream-proven mechanism
at the interface that already owns that job, instead of stacking
one-port patches. That principle does not pre-authorize a new
graphics runtime, a new service, a global SDL replacement, or a
package import.

### A. Keep the current integration and fix demonstrated contract failures

Zlyme already has an application-scoped PortMaster path: the pinned
seed, `PlatformZlyme`, `zlyme-portmaster-prepare`, `zlyme-portmaster-exec`,
recorded mount cleanup, isolated GL4ES, explicit Box86, InputPlumber
`xb360` pads, and one PipeWire graph. Shards of God started and took
pad input on `da7eb21` on that path. SDL3 events arrived. Box86 ran
a legal console probe.

The same image failed Winter's AGS graphics init after the cursor
soft-fail, failed to mount Steel's Mono squashfs onto a usable
`mono`, and showed a black GL4ES probe after `GL4ES_READY`. Those
are concrete contract failures. Option A would change only the
failing contract, with a hardware check at that boundary.

Cost: each new port can reveal another path, loader, or SDL quirk.
Benefit: no second graphics stack and no global library switch.
The Shards success is evidence that a blanket replacement is not
required before the failing contracts are named.

### B. Add an application-scoped compatibility environment

Informed by ROCKNIX's compat archive, upstream PortMaster's
per-architecture directories, and KNULLI's generated controller map,
without making that environment the system default. A port launch
would see stable runtime roots, ABI-matched loaders, and SDL/GL
libraries only for that process. Steel's Mono mount and Winter's
AGS/SDL/GL combination are the representative cases. GL4ES would
stay an explicit selector, not a system `libGL`.

This matches the principle of one interface for runtime resolution.
It is larger than option A. It is still not a boot-time GPU switch
and not a permanent compositor. It is not implemented. Licensing of
any imported compat archive has to be decided file by file before
a recipe exists. ROCKNIX `compat.tar.gz` is not in this tree.

### C. Adopt ROCKNIX-style system-wide GPU and runtime behavior

The historical Flip fork switches global graphics libraries with the
GPU choice and wires PortMaster SDL into that switch. Official
ROCKNIX installs a system compat tree. Copying that into Zlyme would
touch every GLES client, including NextUI and RetroArch, and would
fight the current rule that libmali and Panfrost stay behind the
board GPU choice without replacing system SONAMEs for one program.

No `da7eb21` failure requires that. Shards rendered with the system
SDL2 OpenGL ES2 path. GL4ES already isolated its `libGL`. A global
switch would add boot and regression cost for a problem that has
not been shown to be global. Option C stays a rejected direction
unless a later measurement shows the application-scoped path cannot
carry a supported port.

## What the evidence supports

Option A is the smallest reading of the successes: Shards, SDL3
events, and the Box86 console probe already run on the current
integration. Option B is the smallest reading of the shared
failures: Steel's runtime root and Winter's AGS graphics init are
not one-game typos, and a per-port patch would miss the next
squashfs or the next AGS title. Option C is not supported by this
archive.

This note does not choose B over A. The maintainer decides after
reviewing `docs/ROADMAP.md`. Until that decision, no compat archive,
no new service, and no global SDL or GPU library change is in scope.

## Unknowns

- Why AGS reports `Cursor not initialized properly` after SDL2 has
  already disabled the hardware cursor. The soft-fail is present and
  insufficient. The next graphics change is not specified here.
- Whether Steel's `mount: bad address 'opt'` is the control-folder
  path, `taskset` aborting early, or the squashfs helper. The log
  shows the doubled `/opt` path and a missing `mono` command. It
  does not isolate one line of shell.
- Whether GL4ES PBuffer mode can present on the panel, or whether
  the black screen is swap/presentation while the context is valid.
  Panfrost was not booted for this probe.
- Whether the SDL3 probe's missing picture reaction is only the
  probe's drawing, which the source suggests, or also a modeset
  the maintainer could not see. Events were delivered.
- Graphical Box86, WestonPack, Mina, Ascent on Panfrost, and
  RetroArch's HDMI CRTC.
- Which files inside a ROCKNIX compat archive, if option B is
  chosen later, have a license Zlyme can ship. Unknown license is
  not a grant.

## Implementation gates

These gates are a review list. Gate 0 is the only one that can
start, and it is the review itself. Do not begin Gate 1.

### Gate 0. Review

Prerequisite: this note and the Phase 14 roadmap section.
Scope: maintainer reads the roadmap diff. Approval required.
Pass: a written choice of A or B, or a named rejection of both.
Fail: implementation starts without that choice.
Regression risk: none. This gate changes no tree behavior.
Hardware: not required.

### Gate 1. Runtime paths

Prerequisite: Gate 0 approval.
Scope: canonical PortMaster paths and runtime ABI for one shared
engine. Steel Assault is the Mono representative.
Pass: the squashfs mounts, `mono` runs, the game leaves, NextUI
returns, and the recorded mount is gone.
Fail: `mono: command not found` or a bad mount path remains.
Regression risk: other squashfs ports and the selected library on
SD2. Hardware: required.

### Gate 2. AGS graphics

Prerequisite: Gate 1, or an explicit decision that Winter does not
depend on the runtime-root fix.
Scope: one supported AGS/SDL cursor and graphics path.
Pass: Winter Travelers shows a picture and leaves. Shards of God
still starts and still takes pad input.
Fail: Winter still dies on cursor or GL init, or Shards regresses.
Regression risk: SDL2 KMSDRM for every port, not only AGS.
Hardware: required. A replacement cursor design is not implied by
the current patch.

### Gate 3. GL4ES presentation

Prerequisite: Gate 0. Can follow Gate 2 if SDL2 changes would
confound the probe.
Scope: visible rendering on Mali, then a separate Panfrost boot.
Pass: the triangle is visible and `GL4ES_DONE` is logged, then
NextUI returns. Context-only `GL4ES_READY` is not a pass.
Fail: black screen or a missing done line.
Regression risk: ports that bundle another `libGL`.
Hardware: required on each GPU boot.

### Gate 4. SDL3 picture and pad

Prerequisite: Gate 0. Do not rebuild InputPlumber if events already
arrive, which they did on `da7eb21`.
Scope: confirm the probe's picture and whether a button changes
that picture, or record that the probe does not draw button state.
Pass: a visible frame and a logged button, with the on-screen
behavior matching the probe source.
Fail: no picture, or events stop arriving.
Regression risk: SDL3 SONAME used by other packages.
Hardware: required.

### Gate 5. Representative engines

Prerequisite: Gates 1–4 for the class each port uses.
Scope: one present LÖVE port, WestonPack if a port on the card
needs it, ARMHF and graphical Box86 on Panfrost, Vulkan only as
the experimental PanVK opt-in, and the remaining eligible named
ports whose data is present.
Pass and fail are per port: process, picture, input, audio, exit,
mounts, and NextUI are separate. Missing commercial data stays
external, not PASS.
Regression risk: audio graph and mount cleanup.
Hardware: required for each class that is actually installed.

### Gate 6. Regression

Prerequisite: the gates that changed a shared component.
Scope: NextUI, RetroArch, MENU+START, audio, mounts, DRM, both
cards, HDMI, and the already accepted Phase 14 items on their
original images. A new image does not inherit those acceptances.
Pass: no regression of an accepted item that the change could
affect, plus RetroArch's own 1280×720 CRTC if HDMI policy changed.
Fail: an accepted path breaks, or a DRM client is reported clean
when debugfs was unavailable.
Hardware: required where the change can affect that path.
