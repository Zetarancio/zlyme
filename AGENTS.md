# Zlyme agent instructions

## Project

Zlyme is a purpose-built Buildroot Linux distribution for handheld gaming devices.

**The only supported device today is the Miyoo Flip (`my355`, Rockchip RK3566).**

The repository should be structured so another device can be added later without rewriting generic Zlyme code, but do not implement hypothetical devices or abstractions with no current user.

External source-of-truth model:

- `Zetarancio/Miyoo-Flip-Mainline-Linux-Reverse-Engineering` is the distribution-independent Miyoo Flip hardware/firmware wiki and the primary device reference.
- This Zlyme repository is authoritative for the active OS implementation.
- `Zetarancio/distribution` is an archived historical ROCKNIX implementation/evidence source. Do not treat it as current project state or try to keep it synchronized.
- `ROCKNIX/distribution`, KNULLI, and other distributions are external comparison/packaging references, not authorities for Zlyme behavior.
- Do not modify the hardware wiki or archived ROCKNIX fork as part of a Zlyme task unless the task explicitly requests work in that repository.

Primary goals, in order:

1. Hardware safety and correctness.
2. Reproducible builds.
3. Low runtime latency and predictable frame times.
4. Fast boot to the frontend.
5. Minimal runtime footprint.
6. Simple, understandable implementation.
7. Maintainability.
8. Build speed and image size.

Prefer explicit code and narrow interfaces over framework-building.

## Required context

Before making code changes, read:

- `docs/ENGINEERING_PRINCIPLES.md`

Before architectural, boot, device, graphics, audio, storage, packaging, update, or runtime changes, also read:

- `docs/ARCHITECTURE.md`
- `docs/DEVICE_PORTING.md`

For design/refactoring work also read:

- `docs/ENGINEERING_PRINCIPLES.md`

For build/package/toolchain work also read:

- `docs/DEVELOPMENT.md`
- `docs/UPSTREAMS.md`

For live-device and recovery work also read:

- `docs/OPERATIONS.md`

For sequencing planned project work, read:

- `docs/ROADMAP.md`

`ROADMAP.md` is non-normative: it describes planned work, not current architecture. Do not implement a later roadmap phase unless the active task asks for it.

Architecture documents state what the system is and why. This file states how changes should be made.

## Current architecture invariants

Preserve these unless the task explicitly requires changing them:

- Buildroot remains a `BR2_EXTERNAL` tree. Do not modify upstream Buildroot.
- Miyoo Flip / `my355` is the only supported target.
- Normal graphics use direct DRM/KMS.
- Do not add a permanent desktop environment.
- Do not add a permanently running X11 or Wayland compositor just to support one program.
- Software that cannot use direct KMS may use an application-scoped compatibility runtime such as Weston/WestonPack.
- BusyBox init is the normal init system.
- Optional services must not delay the frontend first frame.
- ALSA is the normal local audio API; BlueALSA provides Bluetooth audio.
- The root filesystem is read-only squashfs; persistent state belongs under `/storage`.
- The curated emulator model is intentional. Do not add alternate cores merely because they exist.
- Hardware safety, thermal protection, and filesystem integrity outrank benchmark results.
- Do not redistribute ROMs, BIOS files, keys, commercial software, firmware, or vendor binaries without verifying redistribution rights.

## Device-boundary rule

Do not make generic Zlyme code know Miyoo Flip hardware details unless the detail is part of a documented stable interface.

Good boundaries:

- `board/my355/` owns Miyoo Flip kernel, U-Boot, DT, image layout, board overlay, and hardware policy.
- A future board gets its own `board/<device>/`.
- Board-specific Buildroot hooks belong in the board's make integration, not in the global `external.mk`, when they only apply to that board.
- Device-specific runtime implementations may expose stable Zlyme commands such as `zlyme-audio`, `zlyme-governor`, `zlyme-led`, and `zlyme-halt`.
- Generic callers depend on the command contract, not RK817 mixer names, GPIO numbers, DRM connector names, or sysfs paths.
- NextUI platform selection is a device property, not a universal constant.
- Update artifact prefix and DTB name are device properties, not universal constants.

Do not create a generic abstraction solely because a second device might exist someday. Extract an interface only when it cleanly describes the current implementation.

## Change policy

Before changing code:

1. Read the relevant implementation and adjacent files.
2. Search for existing helpers and conventions.
3. Identify the smallest change that solves the problem.
4. Preserve unrelated behavior.
5. Validate with the narrowest useful test.
6. Inspect the final diff for unrelated modifications.

Do not perform drive-by refactors.

Do not rename, reformat, reorganize, or modernize unrelated code while implementing another feature.

Prefer one conceptual reason per commit.

Do not introduce an abstraction until it either:
- removes a current source of duplication/error, or
- defines a stable device boundary already required by the current Miyoo Flip implementation.

## Buildroot rules

Keep packages self-contained.

Package-specific workarounds belong with that package whenever practical.

Use global `external.mk` only for:
- package discovery;
- genuinely global Buildroot integration;
- board dispatch.

Board-only Linux/U-Boot hooks should live with the board.

For downloaded packages provide where applicable:

- explicit version;
- immutable reference where practical;
- dependencies;
- license identifier;
- license file(s);
- hashes.

Do not track moving branches for reproducible packages unless there is a documented reason.

Use the Buildroot target toolchain:

- `$(TARGET_CC)`
- `$(TARGET_CXX)`
- `$(TARGET_AR)`
- `$(TARGET_STRIP)`
- target CFLAGS/CPPFLAGS/LDFLAGS

Never accidentally build target software with the host compiler.

Do not fetch dependencies from package build/install commands when Buildroot can manage them.

## Shell

Use POSIX `sh` for target scripts unless Bash is genuinely required.

For host Bash scripts use:

```bash
set -euo pipefail
```

unless documented otherwise.

Quote path and variable expansions.

Avoid `eval`.

Use `mktemp` and `trap` for temporary resources.

Prefer idempotent scripts.

Do not use arbitrary `sleep` for readiness when an observable condition exists.

Background only independent work.

Validate destructive destinations before filesystem or block-device writes.

## C and C++

Keep hardware daemons small and single-purpose.

Check return values from syscalls, ioctl, ALSA, allocation, file operations, and device initialization.

Do not conflate:

- device absent;
- valid negative state;
- transient error;
- permanent failure.

Use stable identities:
- ALSA card IDs, not card numbers;
- capabilities/names, not `/dev/input/eventN`;
- persistent identifiers, not probe order.

Prefer event-driven behavior over polling.

Keep ownership and cleanup obvious.

`goto cleanup` is acceptable in C when it makes cleanup more correct.

Project-owned C/C++ should compile cleanly with at least `-Wall -Wextra` where practical.

## Runtime

Distinguish mandatory hardware from optional features.

Required storage/display/input failures must be diagnosable.

Missing Wi-Fi, Bluetooth, headphones, HDMI, or USB should degrade gracefully when possible.

Networking must not be required for the frontend first frame.

Persistent daemons need a clear reason to exist.

Avoid pointless wakeups, polling, writes, and logs.

## Performance

Do not assume an optimization helps. Measure it.

For runtime/emulator changes prefer:

- frame-time consistency;
- p95/p99 frame time;
- audio underruns;
- input latency where measurable;
- CPU/GPU utilization;
- required clocks;
- temperature/throttling;
- power consumption.

Average FPS alone is insufficient.

Do not silently change compiler optimization policy, governor policy, affinity, voltage, or overclocking.

The current repository intentionally has performance-specific choices. Preserve them unless the task is specifically to revisit them.

## Documentation

Comments explain why, hardware quirks, upstream limitations, safety constraints, and compatibility requirements.

Do not write comments that merely restate code.

Do not remove a workaround until its original reason has been understood and proven obsolete.

Update documentation when changing:
- architecture;
- build commands;
- device contract;
- storage/update format;
- runtime interfaces;
- package layout;
- user-visible behavior.

## Licensing

Every package and shipped PAK must have its licensing understood.

Do not assume source availability means redistribution permission.

Do not remove copyright or license notices.

## Validation

Run the narrowest applicable checks first.

Examples:
- Buildroot external-tree checks for package metadata/style.
- ShellCheck for shell changes.
- Compile project-owned C/C++ with warnings enabled.
- Build the affected package before a full image when practical.
- Confirm generated kernel/U-Boot configuration after Kconfig changes.
- Distinguish build validation from real-device validation.

Never claim hardware testing unless it was performed on the Miyoo Flip.

If a validation step cannot be run, say so.

Never fabricate results.

## Agent behavior

Do not guess repository behavior when source can answer it.

Search before adding a new implementation.

Do not silently upgrade dependencies.

Do not silently change kernel, bootloader, init, graphics, audio, update, storage, or package architecture.

Do not replace a small implementation with a framework without a demonstrated requirement.

Do not add compatibility code for hypothetical future hardware.

Do not add a second-device code path until a second device actually exists.

When preparing the repository for future devices, isolate current Miyoo Flip assumptions behind explicit board/runtime contracts instead of adding unused generic machinery.

At completion report:
- what changed;
- why;
- validation actually performed;
- anything that still needs Miyoo Flip hardware testing.

## Rule precedence

If a general engineering principle conflicts with a documented Zlyme architecture or hardware-safety constraint, the Zlyme-specific constraint wins.

Use `docs/ROADMAP.md` for sequencing major migrations. Do not execute multiple roadmap phases in one task unless the maintainer explicitly asks for that.
