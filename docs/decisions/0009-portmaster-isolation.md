# ADR 0009 — PortMaster compatibility stays off the system ABI

Status: Accepted

Date: 2026-10-26

## Context

PortMaster games arrive with several ABIs. Some need older shared-library sonames. Some are native AArch64. Some are native ARMHF, including 32-bit GameMaker. Some ship their own GL4ES. Copying another distribution's global library set would replace Zlyme's AArch64 SDL, EGL, and audio stack.

ROCKNIX publishes a compatibility archive with no license text. Zlyme uses an allowlist from one pinned archive. That provenance record is not a license grant, and this decision does not create redistribution rights for those files.

## Decision

AArch64 compatibility libraries live in `/usr/lib/compat` and are searched only on the PortMaster path. Source-built `libxml2.so.2` and `libtheoradec.so.1` stay there. The 41 imported ROCKNIX ELF files stay there, unmodified, under `LicenseRef-ROCKNIX-portmaster-compat-unspecified`. They do not replace system sonames.

Native ARMHF programs use the private loader and `/usr/lib/zlyme-armhf`. That tree includes its own SDL2, OpenAL, FreeType, Mesa, and GL4ES. It is not on the AArch64 linker path. ARMHF audio clients use `pipewire-pulse`; they do not start a second mixer.

A port may ship GL4ES beside its own game. Zlyme does not install a global `libGL` or an AArch64 GL4ES fallback. The optional fallback was removed after no installed port used it and its own probe did not present a picture.

Box86 is an explicit opt-in. It is not implied by a native ARMHF program working.

## Consequences

A missing library is a specific port or ABI gap. The fix is a private library with a recorded license, or a port-local file, not a change to the system EGL or SDL stack.

The 41 imported files remain an open release question until their redistribution rights are known. Shipping them is a maintainer decision recorded in `docs/UPSTREAMS.md`, not a permission created here.

`docs/ARCHITECTURE.md` owns the runtime layout.
