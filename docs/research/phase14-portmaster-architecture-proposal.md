# PortMaster compatibility architecture review

Status: Gate 0 approved a narrow Gate 1 fix. Gate 1 and Gate 2 are
hardware-accepted on source `72916de97b2ce8a027bad14ace275ef25426a695`,
squashfs `cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`.
Gate 2 is the maintainer's local Winter `acsetup.cfg` change to
`driver=software`, not a firmware patch. Option B and option C are
not approved. Gate 3 is not started. This note is not current
architecture. `docs/ARCHITECTURE.md` still owns what Zlyme ships.
Phase 15 has not started. `zlyme44.4` has not released.

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
| Shards of God | AGS 3.6.2 reached `Starting game`. The log contains `KMSDRM: drmModeMoveCursor failed (-14); disabling HW cursor`, then an SDL `opengles2` renderer on the software graphics path. gptokeyb opened `./shardsofgod.gptk`. The maintainer reports usable controller input. The expected filename was restored with a non-overwriting copy. The conflict original remains. This is one AGS port, not every AGS port. |
| Winter Travelers | FAIL. The same cursor line is present. Winter then requests another graphics path, logs `Failed to load GL` and `Failed to init gfx mode. Error: Cursor not initialized properly`, and segmentation-faults. The cursor line is not, by itself, the established cause. The soft-fail already in this image did not make this launch work. A replacement design is not established. |
| Steel Assault | FAIL. The Mono squashfs is on SD2. The log has `taskset not found, bailing...`, `mount: bad address 'opt'`, a mount source that begins `//opt/system/Tools/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs` (a double leading slash), and `mono: command not found`. `taskset`, the squashfs mount, the runtime root, and `PATH` stay separate possibilities. No shell-expansion cause is established. |
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

The same image also shows separate failures: Winter's AGS graphics
path, Steel's Mono runtime path, and a black GL4ES probe after
`GL4ES_READY`. Option A is the current baseline. A later approval
can name one of those contracts and stop there.

Cost: each new port can reveal another path, loader, or SDL quirk.
Benefit: no second graphics stack and no global library switch.
The Shards success is evidence that a blanket replacement is not
required before the failing contracts are named.

### B. Add an application-scoped compatibility environment

Informed by ROCKNIX's compat archive, upstream PortMaster's
per-architecture directories, and KNULLI's generated controller map,
without making that environment the system default. A port launch
would see stable runtime roots, ABI-matched loaders, and SDL/GL
libraries only for that process. Steel and Winter are different
failures at compatibility boundaries. They become reasons to
consider B only if a narrow fix of the current baseline cannot
carry the contract that actually failed. GL4ES would stay an
explicit selector, not a system `libGL`.

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
not been shown to be global. Option C is not supported by the
present evidence.

## What the evidence supports

Option A is the implementation baseline. Shards, SDL3 events, and
the Box86 console probe already run on it. Option B is a conditional
extension if a diagnosed failure needs a broader compatibility
environment. Steel and Winter do not establish that need by
themselves. Option C is not supported by this archive.

The maintainer can approve a narrow diagnostic or fix, defer B, or
escalate to B later. Review is still required before any of that
work. Until then, no compat archive, no new service, and no global
SDL or GPU library change is in scope.

## Unknowns

- Which AGS graphics and cursor contract Winter uses, and why that
  path reports `Failed to load GL` and `Cursor not initialized
  properly` while Shards logs the same KMSDRM cursor line and still
  reaches `Starting game`. The cursor line alone is not the cause.
- Whether Steel's `mount: bad address 'opt'` comes from `taskset`
  bailing, the squashfs mount, the runtime root, or `PATH`. The
  mount source begins with `//`. That double leading slash is not
  a proven shell-expansion bug.
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
Pass: written approval of a narrow diagnostic or fix on the current
baseline, or a written deferral of B, or a later escalation to B
with the evidence that justifies it.
Fail: implementation starts without that approval. A forced choice
of B is not required.
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
Scope: identify the AGS graphics and cursor contract Winter uses,
and the contract Shards uses, before any correction is chosen.
Both `da7eb21` logs contain `drmModeMoveCursor failed (-14)`.
Shards then creates an `opengles2` renderer and reaches
`Starting game`. Winter requests another path, reports
`Failed to load GL` and `Cursor not initialized properly`, and
crashes. The cursor line is not the selected fix.
Pass: Winter shows a picture and leaves, and Shards still starts
and still takes pad input.
Fail: a patch is chosen before those two contracts are named, Winter
still dies in graphics init, or Shards regresses.
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
needs it, ARMHF and graphical Box86 on Panfrost, and the remaining
eligible named ports whose data is present. Vulkan follows
`docs/ARCHITECTURE.md`: libmali selects the proprietary Mali ICD,
and `panvk` is the explicit experimental PanVK opt-in. `panfrost`
does not enable PanVK. Neither Vulkan path is hardware-accepted
until a watched result says so. Do not enable PanVK for every GPU
choice.
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
affect. RetroArch's own 1280×720 HDMI CRTC stays an open Phase
14H/14M requirement. It is not conditional on an HDMI policy
change. The accepted NextUI HDMI 720p and panel result on
`0b35a90` stays closed.
Fail: an accepted path breaks, the RetroArch CRTC check is dropped,
or a DRM client is reported clean when debugfs was unavailable.
Hardware: required where the change can affect that path.
