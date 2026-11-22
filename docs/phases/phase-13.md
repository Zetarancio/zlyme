# Phase 13. Compatibility on this branch

Objective: finish the compatibility items accepted on this branch, including RetroArch defaults, PortMaster artwork, Samba, and the final source review.

Disposition: Closed, 2026-10-16.

Accepted behavior: the maintainer accepted the local candidate from `ccd99997b98dc9015a3ed06a1808ecb2a207f197`. On that image, Samba login and the Settings password worked, and a PortMaster JPEG appeared as the launcher's artwork. No further regression was seen. An earlier candidate, `b39435147fc7`, had Samba enabled with no listener and did not publish that JPEG. On that earlier image, SSH accepted a changed password and About showed it, Syncthing accepted a GUI password change and About did not show it, one lid close entered sleep and the following lid open woke the device, and repeated PortMaster to MTP cycles showed no error.

Limitations: B6 and C1 are excluded and are not implemented. The menu text stays small. PortMaster-GUI still has one ports directory. The earlier intermittent PortMaster-to-MTP nested mount was not reproduced and is not a release blocker. MTP still refuses a nested mount. Within-session USB cable replug is not a new hardware gate. A long suspend was not required. Phase 12 stays closed. Credits for B7, B8, D1, and D2 stay in those commit messages, not in the README. The earlier 13E list, E1 through E4, is in [docs/archive/roadmap-2026-10-15.md](https://github.com/Zetarancio/zlyme/blob/9439d82fd99a859ad6b185275676f08b3fd02477/docs/archive/roadmap-2026-10-15.md). The milestones in the 2026-11-17 snapshot replace it.

Each subphase objective, status, and reference remains under its heading in that snapshot.

Records: the heading list below.

## Headings in the 2026-11-17 snapshot

- [Phase 13. Compatibility on this branch](../archive/roadmap-2026-11-17.md#phase-13-compatibility-on-this-branch)
- [Phase 13A. Small corrections](../archive/roadmap-2026-11-17.md#phase-13a-small-corrections)
- [Phase 13B. RetroArch and emulators](../archive/roadmap-2026-11-17.md#phase-13b-retroarch-and-emulators)
- [B1. Menu confirm and back](../archive/roadmap-2026-11-17.md#b1-menu-confirm-and-back)
- [B2. Stock emulator configuration](../archive/roadmap-2026-11-17.md#b2-stock-emulator-configuration)
- [B3. RGUI theme](../archive/roadmap-2026-11-17.md#b3-rgui-theme)
- [B4. Standalone RetroArch tool](../archive/roadmap-2026-11-17.md#b4-standalone-retroarch-tool)
- [B5. Persistent libretro cores](../archive/roadmap-2026-11-17.md#b5-persistent-libretro-cores)
- [B6. Readable RetroArch menu](../archive/roadmap-2026-11-17.md#b6-readable-retroarch-menu)
- [B7. Quit through RetroArch menus](../archive/roadmap-2026-11-17.md#b7-quit-through-retroarch-menus)
- [B8. Native arcade BIOS lookup](../archive/roadmap-2026-11-17.md#b8-native-arcade-bios-lookup)
- [Phase 13C. PortMaster on two cards](../archive/roadmap-2026-11-17.md#phase-13c-portmaster-on-two-cards)
- [C1. Installed ports on both cards](../archive/roadmap-2026-11-17.md#c1-installed-ports-on-both-cards)
- [C2. Cover art](../archive/roadmap-2026-11-17.md#c2-cover-art)
- [Phase 13D. Samba and lid suspend](../archive/roadmap-2026-11-17.md#phase-13d-samba-and-lid-suspend)
- [D1. Samba authentication](../archive/roadmap-2026-11-17.md#d1-samba-authentication)
- [D2. Lid-close deep suspend](../archive/roadmap-2026-11-17.md#d2-lid-close-deep-suspend)
- [Phase 13E. Final compatibility](../archive/roadmap-2026-11-17.md#phase-13e-final-compatibility)
- [13E1. PortMaster mounts and MTP](../archive/roadmap-2026-11-17.md#13e1-portmaster-mounts-and-mtp)
- [13E2. Syncthing credentials](../archive/roadmap-2026-11-17.md#13e2-syncthing-credentials)
- [13E3. About credentials](../archive/roadmap-2026-11-17.md#13e3-about-credentials)
- [13E4. Obsolete configuration](../archive/roadmap-2026-11-17.md#13e4-obsolete-configuration)
- [13E5. Documentation coherence](../archive/roadmap-2026-11-17.md#13e5-documentation-coherence)
- [13E6. Source review and acceptance](../archive/roadmap-2026-11-17.md#13e6-source-review-and-acceptance)

