# Zlyme roadmap

Miyoo Flip (`my355`) is the only supported device. This file says where the work is. It is not the architecture. Current behavior is in `docs/ARCHITECTURE.md` and the other owning documents. How to write this file is in `docs/WRITING.md`.

The long record that used to live here was moved on 2026-10-15 to [docs/archive/roadmap-2026-10-15.md](archive/roadmap-2026-10-15.md). The immutable reference is `b926b9976c12ccdb3de20b629f8a550e574f8e51`. Four relative links in that copy were retargeted for `docs/archive/`. Sentences there that say Phase 13 is not scoped are that day's plan.

## Where we are

Phase 13 is closed. Published stable `zlyme44.3` is tag `zlyme-38828679802`, from `1ce2f56af1ec91a1087a01b23f741464fc6c34f6`, published 2026-10-16. The accepted device candidate was `ccd99997b98dc9015a3ed06a1808ecb2a207f197`. B6 and C1 stay excluded. `main` also has the later README commit `8b4218aa201b76e72706ab70036424c2a2dac6bc`, which is not in that firmware. Phase 14 is open on `zlyme44.4-phase-14` for `zlyme44.4`. It has not released. The checklist is in `docs/MAINTENANCE.md`.

Host-tested means a host check passed. It is not a Flip result. Blocked means the item stopped on the limit named there. Planned means the source is not on this branch yet.

## Closed phases

| Phase | Closed | Reference |
| --- | --- | --- |
| 0 | 2026-09-22. The product image booted to NextUI. | [Phase 0](#phase-0-repository-and-baseline) |
| 1 | 2026-09-23. Application-scoped Weston returned to NextUI. | [Phase 1](#phase-1-application-scoped-weston) |
| 2 | 2026-09-23. Eighteen kernel patches remained. | [Phase 2](#phase-2-kernel-patch-audit) |
| 3 | 2026-09-25. The built-in gamepad was accepted. | [Phase 3](#phase-3-built-in-gamepad) |
| 4 | 2026-09-28. Applications use InputPlumber `xb360` pads. | [Phase 4](#phase-4-inputplumber) |
| 5 | 2026-09-28. Second patch reduction. | [Phase 5](#phase-5-second-patch-reduction) |
| 6 | Deep suspend from the power button. | [Phase 6](#phase-6-deep-suspend) |
| 7 | DMC is an external module. | [Phase 7](#phase-7-dmc-module) |
| 8 | 2026-09-30. NextUI is a pinned fork. | [Phase 8](#phase-8-nextui-fork) |
| 9 | 2026-10-04. Published `zlyme44`. | [Phase 9](#phase-9-first-stable-release) |
| 10 | 2026-10-06. Documentation closure. `zlyme44.1` was not published. | [Phase 10](#phase-10-documentation) |
| 11 | 2026-10-08. Published `zlyme44.2`. | [Phase 11](#phase-11-zlyme442) |
| 12 | 2026-10-14. Development closed, with the limits below. | [Phase 12](#phase-12-zlyme443-development) |
| 13 | 2026-10-16. Accepted on `ccd99997`. B6 and C1 excluded. | [Phase 13](#phase-13-compatibility-on-this-branch) |

## Phase 0. Repository and baseline

Objective: make the tree's documents, board hooks, and `my355` identity explicit without changing runtime behavior.

Status: Closed, 2026-09-22. Both my355 defconfigs configured, and a clean product image booted to NextUI.

Reference: `docs/LOGBOOK.md`, 2026-09-22.

## Phase 1. Application-scoped Weston

Objective: run a Wayland or X11 program without a permanent compositor.

Status: Closed, 2026-09-23. Temporary Weston recovered NextUI on Panfrost and libmali. WestonPack and Wine returned the same way. No open work.

Reference: [docs/research/weston.md](research/weston.md).

## Phase 2. Kernel patch audit

Objective: classify the inherited Linux patches against the selected kernel, upstream, the hardware wiki, and current comparison trees, then remove only what that audit justified.

Status: Closed, 2026-09-23. Evidence pin `8984f6106c99f89bde214a3beeec3ee4bc175ba7`. Eighteen Linux patches remained. Joypad, deep suspend, and DMC stayed in later phases.

Reference: [docs/research/kernel-patch-audit.md](research/kernel-patch-audit.md).

## Phase 3. Built-in gamepad

Objective: replace the ROCKNIX joypad stack with `miyoo-flip-gamepad` for the Flip's UART pad.

Status: Closed, 2026-09-25. Original sticks, buttons, MENU, and rumble were accepted. Switch 1 replacement sticks were a compatibility target and were not called validated.

Dependency: the hardware and protocol record. Applications were Phase 4.

Reference: [docs/research/joypad-driver.md](research/joypad-driver.md), [docs/archive/roadmap-phase-3c.md](archive/roadmap-phase-3c.md).

## Phase 4. InputPlumber

Objective: give each application one virtual `xb360` pad per player. The built-in pad stays the calibration device.

Status: Closed, 2026-09-28. Accepted image `zlyme-my355-20260927-0b139e9099ee.tar` from `0b139e9099eec699e31d1cb5313998f57f387e12`. External controllers were not part of that acceptance.

Reference: [docs/research/inputplumber.md](research/inputplumber.md).

## Phase 5. Second patch reduction

Objective: drop kernel patches the new gamepad and the newer kernel made obsolete, and record what stayed.

Status: Closed, 2026-09-28. The first accepted runtime is `7eaecf794830a15c53f6b417a1b408dd31ceee53`. The corrected stack that entered Phase 6 is `8119387e0fdb729f1f013bed9dbc48c76e37a1df`. `7eaecf79` was not rewritten as that later stack.

Reference: [docs/research/kernel-patch-audit-phase5.md](research/kernel-patch-audit-phase5.md).

## Phase 6. Deep suspend

Objective: enter and leave Linux mem suspend through the existing RK3568 BL31 path, from the menu and from a game, using the power button.

Status: Closed. Accepted runtime `b709719aac5c5540394d0369e5e06981b8aa00bc`. The PM config driver stays built in. RK817 `005` stayed unapplied. Lid-open wake was not measured. The 2026-10-15 lid-close work does not add that measurement.

A later check on the installed Phase 13 candidate saw one lid open wake the device. That check does not reopen this phase.

Not a closure requirement: long cycle counts, a standby-current number, and a full USB or radio matrix. Those were not claimed.

Reference: [docs/research/deep-suspend-phase6.md](research/deep-suspend-phase6.md).

## Phase 7. DMC module

Objective: run the RK3568 DMC devfreq driver as an out-of-tree module instead of a kernel patch.

Status: Closed. Accepted runtime `21de8081d6e6a419d708e8f3c792e4f1357eaafc`. `1012a` and `1012b` are gone. DFI patch `1010` stayed. A later failure-path correction, `70acb1d27443447df84903e2043a2af05dbd9ee3`, was source-reviewed and was not given its own hardware run.

Reference: `package/drivers/rk3568-dmc/README.md`.

## Phase 8. NextUI fork

Objective: fetch Zlyme's NextUI from a pinned commit, keep other-platform source in the fork, and leave `/boot` read-only.

Status: Closed, 2026-09-30. Hardware-equivalent runtime `7a0fc397cb5b3e0f7c4b19f4f3abe8626eaccaf8`. The profile did not justify a frontend optimization. Upstream pins were not moved.

Reference: [docs/research/frontend-source-phase8.md](research/frontend-source-phase8.md).

## Phase 9. First stable release

Objective: finish the product surface for the first stable `zlyme44` and publish it from a clean remote build.

Status: Closed, 2026-10-04. Implementation `337ccbce2587393463a4b49c551f94e33e318e44`. The maintainer accepted the 2026-10-03 image, including a ZcrapeGoat cheat and a root-sized delta. Run `37164297221` published `zlyme-37164297221`.

Reference: [docs/research/product-phase9.md](research/product-phase9.md).

## Phase 10. Documentation

Objective: make the owning documents match the source, and add the maintenance index, without a new product feature.

Status: Closed, 2026-10-06. Accepted source `6a398b311310246ef6a5515ed72805c6f58d787d`. `zlyme44.1` was not published. Run `37375071442` was dispatched with `publish_release` false. Deferred findings `(i)`, `(m)`, `(n)`, and `(q)` were not Phase 10 blockers. `(i)` later changed in Phase 12A1.

Reference: `docs/MAINTENANCE.md`, [docs/research/documentation-audit-phase10.md](research/documentation-audit-phase10.md).

## Phase 11. zlyme44.2

Objective: ship the Settings, runtime, and recovery work that became published `zlyme44.2`.

Status: Closed, 2026-10-08. 11A and 11B were hardware-accepted on 2026-10-06. 11C's recovery preloader was hardware-accepted on 2026-10-08. Erase is not USB MASKROM. The published runtime is `9b7d91d5ce6e36764aa663748a92ef7e7be6f3f3`. PortMaster mounts left behind by `PORTS.pak` were Phase 12 preflight, not a 44.2 gate.

Reference: `docs/LOGBOOK.md` and the archived roadmap. The UART logs are in the hardware wiki.

## Phase 12. zlyme44.3 development

Objective: battery, SSH, clock, updater, launch logs, Buildroot 2026.08, PanVK as an experimental opt-in, unused kernel-test cleanup, and USB File Transfer.

Status: Closed, 2026-10-14, after the same-day correction. The installed image is the E32 archive, squashfs `ac46ac3783ed4d9bcc9bbceed1d6b023c65a878cd50561b11dc119980d06c24c`. It was built before `ZLYME_VERSION` became `zlyme44.3`. The maintainer accepted ordinary MTP on that image, including a second start with the cable left in place, one PortMaster port on the second card, and charging and upper-port host use by report. The maintainer presented one orange frame twice. PPSSPP did not present a game through PanVK. The archive `7951a37668e3` is an earlier file-copy baseline, not this accepted image.

A later local candidate, recorded under Phase 13, replaced that image on one Flip. It does not reopen this phase.

Limits, not open work: within-session cable removal was not measured, E30 stays the rollback for that limit, and `snps,dis_u2_susphy_quirk` stays. A discharge to 0% was not run. The maintainer required no further Phase 12 hardware test. WestonPack cleanup and removal of obsolete PAKs are not a new hardware gate.

The hardware wiki was updated for the development Linux 7.2.10 boot and the lower-port session. That update does not call the device tree proven.

Dependency: published 44.2 source. No Phase 12 item waits on a wiki edit.

Reference: [docs/research/usb-mtp-phase12d.md](research/usb-mtp-phase12d.md), [docs/research/linux-7.2.10-migration.md](research/linux-7.2.10-migration.md).

## Phase 13. Compatibility on this branch

Phase 13 is closed, 2026-10-16. The maintainer accepted the local candidate from `ccd99997b98dc9015a3ed06a1808ecb2a207f197`. On that image, Samba login and the Settings password worked, and a PortMaster JPEG appeared as the launcher's artwork. No further regression was seen. An earlier candidate, `b39435147fc7`, had Samba enabled with no listener and did not publish that JPEG. On that earlier image, SSH accepted a changed password and About showed it, Syncthing accepted a GUI password change and About did not show it, one lid close entered sleep and the following lid open woke the device, and repeated PortMaster to MTP cycles showed no error.

B6 and C1 are excluded. They are not implemented. The menu text stays small. PortMaster-GUI still has one ports directory. The earlier intermittent PortMaster-to-MTP nested mount was not reproduced and is not a release blocker. MTP still refuses a nested mount. Within-session USB cable replug is not a new hardware gate. A long suspend was not required. Phase 12 stays closed. Credits for B7, B8, D1, and D2 stay in those commit messages, not in the README.

The earlier 13E list, E1 through E4, is in the archive. The milestones below replace it.

### Phase 13A. Small corrections

Objective: branding rebuild, the Windows Basic Data partition type, MTP names, VTree translations, the README lockup width, and the Unreleased cleanup.

Status: Host-tested, 2026-10-15. No image was built for these items. No open work inside 13A.

Reference: the archived roadmap, section Phase 13A.

### Phase 13B. RetroArch and emulators

B6 is excluded from Phase 13. It is not implemented. It does not block closure of Phase 13B.

##### B1. Menu confirm and back

Objective: menus confirm with A and go back with B. Game actions stay.

Status: Host-tested. No separate menu-confirm setting disagreed with the game map, so those bindings were left alone.

##### B2. Stock emulator configuration

Objective: ship one stock file, copy it only when the user's file is missing, and let an explicit reset replace it. Launchers do not rewrite an existing file.

Status: Host-tested. The 2026-10-15 host test of launcher-time key insertion does not validate this policy.

Dependency: NextUI `2d95d33` added the RetroArch reset row. `7cb6ecaa` added lid-close mem. Published `zlyme44.3` pins `9931d99e`, which is on NextUI `zlyme`. This branch pins `be39118a` for the delete-game row, the Wi-Fi service switches, and transparent Art Book overlays. About reads Syncthing through `zlyme-syncthing-gui`.

##### B3. RGUI theme

Objective: stop forcing the custom Zlyme theme. Classic Orange is the stock default this pin understands.

Status: Host-tested. An existing file that still names the old theme stays until the configuration reset.

##### B4. Standalone RetroArch tool

Objective: Tools → RetroArch starts `ra-run` with no ROM.

Status: Host-tested.

##### B5. Persistent libretro cores

Objective: copy packaged cores to `/storage/.config/retroarch/cores/`. A reboot leaves a hand-replaced shipped core. A new image refreshes the filenames it ships. A core the image does not ship stays.

Status: Host-tested. The 2026-10-15 host test of the tmpfs symlink directory does not validate this policy. Cores are real files. The first copy is about 213 MiB and was not timed on a Flip.

##### B6. Readable RetroArch menu

Objective: make RGUI text usable on the Flip with options the pinned RetroArch already has.

Status: Excluded from Phase 13. Not implemented. RetroArch 1.22.2 draws RGUI into a 320×240 buffer and scales it. The existing scale options do not make the glyphs larger. A font patch is not approved. The menu text stays small. This is not a Phase 13 closure blocker.

##### B7. Quit through RetroArch menus

Objective: Close Content from a NextUI launch returns to NextUI and can write the automatic state. The standalone tool stays in RetroArch.

Status: Host-tested. MENU+START is unchanged.

##### B8. Native arcade BIOS lookup

Objective: let the pinned FBNeo and MAME 2003-Plus cores find BIOS archives themselves.

Status: Host-tested. The 2026-10-15 host test of `zlyme-arcade-stage` does not validate this policy. That stage is superseded. The lookup order is in `docs/USER_GUIDE.md`.

### Phase 13C. PortMaster on two cards

##### C1. Installed ports on both cards

Objective: show installed ports from both cards, and still write an install, update, or removal to the card that owns it.

Status: Excluded from Phase 13. Not implemented. PortMaster-GUI has one ports directory. Two ports with the same name cannot both live there. NextUI already lists each card's Ports folder. This is not a Phase 13 closure blocker.

REJECTED — a union or a symlink farm. A removal or extract can hit the wrong card. NextUI already lists each card's Ports folder. An upstream change would have to record which directory owns each port. No such change is approved.

##### C2. Cover art

Objective: after an install, publish suitable art as `.media/<launcher>.png` on that port's card. Art the user already chose stays.

Status: Accepted on `ccd99997`. PortMaster copies a cover or screenshot onto the same card, named for the launcher. A JPEG stays a JPEG. NextUI prefers `.png` and reads `.jpg` or `.jpeg` when the PNG is absent. The earlier candidate `b39435147fc7` did not show `Abombniball.sh`.

### Phase 13D. Samba and lid suspend

##### D1. Samba authentication

Objective: require the `zlyme` account, keep a changed password across reboot and update, and leave guest access off. Samba stays off until Settings enables it.

Status: On the installed candidate, Samba was enabled, the account export existed, and `smbd` was not running. Samba 4.24.6 writes uid 0 into the smbpasswd export, so `pdbedit -i` exits 0 without adding `zlyme`. `smbd` also exits when `/var/run/samba` is missing. The source repair rewrites that uid and creates the runtime directories, then reports failure if `smbd` does not stay up. A damaged account file still does not start `smbd` and does not restore the public password. A temporary listener on port 44445, using the target binaries, accepted `zlyme` and rejected a guest client. Port 445 was not started, and the live account was not changed. The maintainer accepted Samba login and the Settings password on `ccd99997`. No NetBIOS, `nmbd`, or WS-Discovery.

##### D2. Lid-close deep suspend

Objective: one lid close requests the existing mem path once, in the menu and in a pak. A second close in that closed period does not. The power button stays on the same helper.

Status: On the installed candidate, one lid close entered sleep and the following lid open woke the device. That is the tested scenario. A long suspend was not part of it. NextUI `7cb6ecaa` and `zlyme-keylidmon` share the mem path. A switch sample that reads open clears the period when the open event was missed. The DTS was not changed.

### Phase 13E. Final compatibility

13E is the last integration pass for `zlyme44.3`. It is closed with the acceptance of `ccd99997` recorded above.

#### 13E1. PortMaster mounts and MTP

A port can leave a mount nested under `/storage` after NextUI returns. USB File Transfer then rejects the primary storage because that tree contains a nested mount. A restart clears the case that was seen. The earlier AGS ports bind-mount under the NextUI state tree.

Objective: find which owner creates the mount and which step should release it. Keep MTP's check that refuses a nested mount. Do not recursively unmount `/storage`. Make the user-facing MTP error readable when the text is cut off.

This is Phase 13 because it breaks USB File Transfer. Broader port compatibility is Phase 14.

Status: Host-tested for mounts the wrapper recorded. Repeated PortMaster to MTP cycles on the installed candidate showed no error. The earlier intermittent nested mount was not reproduced, and reproducing it is not a release gate. Cleanup unmounts a recorded mount only when its mountinfo id is the visible mount at that path, using the parent id rather than the order of mountinfo lines. A different filesystem mounted at the same path stays. A covered or hidden mount stays, and the registry line stays. A line with no id is reported and kept. The pre-launch snapshot is gone. An unrelated mount, and a mount created by calling `mount` outside the wrapper, stays mounted. USB File Transfer still refuses the primary storage while such a mount remains. The screen says another filesystem is mounted inside storage. That refusal stays. A busy recorded mount stays registered and is tried again. Library roots and the second card stay mounted. The host tests use a fake mount table. They do not reproduce that earlier leak. MTP still refuses to start while a nested mount remains. The read-only check is in `docs/OPERATIONS.md`.

#### 13E2. Syncthing credentials

Objective: a new Syncthing config gets GUI username `zlyme` and password `zlyme`, stored as Syncthing 2.0.13's supported hash, not as plaintext in the saved XML. Syncthing stays off until the user enables it. The GUI listens on `0.0.0.0:8384` today and must not be reachable without authentication. Generate the normal per-device identity. Do not ship a fixed device ID, TLS key, or API key. Do not replace a config the user already has, on boot or on update. The user changes the GUI login in Syncthing's own page. There is no Settings password row. If setup fails, do not start an open GUI. The default password is public and the guide says to change it.

Status: Host-tested. A new home is created with `syncthing generate` before the listener starts. The GUI user is `zlyme` and the password is a bcrypt hash of `zlyme`. `zlyme-syncthing-gui` parses `config.xml` with Python's ElementTree and follows Syncthing 2.0.13 `IsAuthEnabled`: LDAP, or a nonempty user and password. An XML comment is not a credential. More than one `gui`, `user`, `password`, or `authMode` element refuses startup. An existing authenticated `config.xml` is not rewritten. A missing, commented, or ambiguous login does not start `0.0.0.0:8384`. The host test ran Syncthing 2.0.13 from the pinned source, checked the hash with its bcrypt package from a temporary module, logged in on `127.0.0.1`, and confirmed that a commented GUI section leaves that binary unauthenticated on loopback. On the installed candidate, Syncthing accepted a GUI password change and kept listening. About did not show that password.

#### 13E3. About credentials

Objective: Settings → About shows, in order, SSH account, SSH password, Samba account, Samba password, Syncthing account, Syncthing password, then IP. Read them when About opens. Do not run the helpers on every redraw. Show the real usernames. Show `zlyme` as a password only when that default is still in force. After the user changes a Samba or Syncthing password, show that it was changed or that it cannot be read. Do not show a hash. Do not keep a second plaintext copy for this screen. Labels have to fit the Flip. About does not edit Samba or Syncthing passwords.

Status: Host-tested. NextUI `3f4120cc` reads the rows when About opens and keeps them for redraws. SSH still shows the live password. Samba shows `zlyme` only when the NT hash is still the initial password, `(changed)` when it is another valid hash, and `(unavailable)` otherwise. Syncthing asks `zlyme-syncthing-gui`, the same parser the init script uses. The account is the GUI user. The password is `(set)` when the parsed value is a bcrypt hash, and `(unavailable)` otherwise. An XML comment is not a username or a password. The page does not show the hash and does not start Syncthing to check it. The host test compiled the label functions and ran them against that helper. About was opened on the installed candidate. It showed the changed SSH password and did not show the Syncthing password. NextUI `e06814c9` adds Settings → Network → Samba Password. That row worked on `ccd99997`. The earlier image's NextUI was `3f4120cc`.

#### 13E4. Obsolete configuration

Objective: remove Phase 12 and 13 scaffolding that is proven unused, and leave the one stock RetroArch configuration. Candidates include `board/my355/fsoverlay/etc/retroarch.cfg`, `ra-perf.cfg`, retired RGUI theme files, obsolete launcher references, the removed arcade stage, and temporary core mechanisms. Read the pinned RetroArch fallback before deleting `/etc/retroarch.cfg`. Review AetherSX2's edits of existing INI paths against the user-owned configuration rule, and keep ROM and card paths working. Do not delete a file because it only looks unused.

Status: Source-checked. `ra-perf.cfg` was not installed by a recipe and nothing read it, so it is removed. `/etc/retroarch.cfg` stays. RetroArch 1.22.2 installs its default file there and, when the user file is missing, copies that path as the skeleton. The overlay file has no settings. The stock file is `/usr/share/zlyme/retroarch/retroarch.cfg`. `zlyme-stock-seed` copies it when the user file is missing or empty, and when Reset RetroArch configuration runs. `ra-run` does not write the user file. Retired RGUI theme files stay deleted by `board/my355/post-build.sh`. `zlyme-arcade-stage` stays removed. AetherSX2 1.0.0's help has no folder argument, so the launcher still rewrites the BIOS, savestate, and memory-card lines to the active library. The other lines stay. This was not run on a Flip.

#### 13E5. Documentation coherence

Objective: make `docs/ARCHITECTURE.md`, `docs/MAINTENANCE.md`, `docs/OPERATIONS.md`, `docs/DEVELOPMENT.md`, `docs/UPSTREAMS.md`, `docs/DEVICE_PORTING.md`, `docs/USER_GUIDE.md`, `docs/LOGBOOK.md`, and `CHANGELOG.md` agree with current behavior. Link to evidence. Do not paste it twice. Dated logbook entries stay as they were written. The changelog stays short and user-facing.

Status: Source-checked. The canonical docs record the installed candidate, the one lid-open wake, the unreproduced PortMaster-to-MTP leak, and the remaining Samba and artwork corrections. B6 and C1 stay unimplemented and are excluded from Phase 13. Dated logbook entries were left as written.

#### 13E6. Source review and acceptance

Objective: review Phase 12 and 13 for ownership, persistent data, cleanup, first-boot order, dependencies, dead code, and duplicated policy. Run the host checks that match those paths. After the implementation is done, build one local candidate. The maintainer does the focused hardware acceptance, including the PortMaster mount that blocks MTP.

Do not reopen an accepted hardware campaign without a concrete regression. B6 stays a documented limit unless a bounded fix is approved separately. C1 stays a documented limit. Do not add an unsafe ports union.

Status: Accepted, 2026-10-16, on the local candidate `ccd99997`. Samba and PortMaster JPEG artwork passed there. The earlier candidate `b39435147fc7` had been installed and checked: SSH, Syncthing, one lid close and open, and repeated PortMaster to MTP cycles passed, and Samba did not listen. B6 and C1 are excluded. A mount the wrapper never recorded can still block USB File Transfer. Within-session cable removal is not a new gate. Published `zlyme44.3` is tag `zlyme-38828679802` from `1ce2f56af1ec91a1087a01b23f741464fc6c34f6`. The later README commit `8b4218aa` is not that firmware.

## Phase 14. PortMaster compatibility and zlyme44.4

Phase 14 is open on `zlyme44.4-phase-14`. `ZLYME_VERSION` stays `zlyme44.3` until the release is prepared. The aim is the broadest practical PortMaster match on the Miyoo Flip, plus the OS-quality items below. It does not claim that every port runs. A `zlyme44.4` release waits for acceptance. Research notes belong in `docs/research/`, not here. Hardware checks are one pass at the end, except where a destructive risk appears earlier. The inventory is [docs/research/portmaster-capability-phase14.md](research/portmaster-capability-phase14.md).

### 14A. Capability baseline

Compare official PortMaster, the pinned `2026.06.23-0015` seed, upstream `2026.10.03-1041` or a newer stable tag if one exists when the update is reviewed, and the relevant ROCKNIX, KNULLI, and Batocera packaging. Record implemented, missing, partial, and hardware-limited. Do not copy another distribution's claim into Zlyme.

Status: Inventory started from this tree. The pin is still `2026.06.23-0015`. `zlyme` maps to `PlatformZlyme`.

### 14B. ARMHF userspace

Ship a real 32-bit ARM hard-float userspace, not only a loader name. Prefer a separate Buildroot ARMHF target in the KNULLI style (`knulli-rk3566_armhf_libs`). Use an ARM EABI hard-float toolchain and matching glibc. Do not import another distribution's binaries. Do not set `DEVICE_HAS_ARMHF=Y` until a dynamically linked ARMHF program runs and its libraries resolve.

Status: Host-tested through qemu-user, and installed into the product target tree. `output-armhf` is built by `scripts/build-armhf-sysroot.sh`. `zlyme-armhf-runtime` checks its manifest and copies the loader and `/usr/lib/zlyme-armhf/` into the AArch64 root. A stale or missing manifest fails the package. The minimal image does not select it. A disposable Debian container with qemu-user 10.0.13 ran the probe: ELF32 ARM hard-float, interpreter `/lib/ld-linux-armhf.so.3`, `libc.so.6` from the private directory, output `armhf 32 0.3`. With `LD_LIBRARY_PATH=/usr/lib` the loader tries the AArch64 `libc.so.6` and then uses the private one. `DEVICE_HAS_ARMHF` stays `N` until a Flip runs an ARMHF program. A full image was not built.

### 14C. Box86 and Box64

Keep the working Box64 and Wine path. Compare native Box86 with Box64's BOX32 against what PortMaster runs. Pick one combination. Do not enable both to raise a count.

Status: Deferred. The pinned Box64 `2f130fab` (v0.4.4) marks `BOX32` experimental and says not to use it. Its README still points 32-bit Windows programs at Box86 or at a WOW64 build. Zlyme's Wine is the WOW64 build on this Box64 with `BOX32=OFF`. Buildroot 2026.08 has no Box86 package. A native Box86 would be an ARMHF program on top of the private glibc, and it needs a Flip result before it can replace anything. `BOX32` stays off. Box86 is not added.

### 14D. Graphics and SDL3

Audit GLES via libmali and Panfrost, GL4ES, SDL 1.2 compatibility, the existing SDL2, KMS/DRM, and application-scoped WestonPack. Do not add a permanent compositor or system Xwayland. Report Vulkan as experimental PanVK, not as a Mali replacement.

Ship Buildroot 2026.08's `BR2_PACKAGE_SDL3` with the KMSDRM, OpenGL ES, and Wayland options that package actually has. The `libSDL3.so.0` stub in `board/my355/post-build.sh` exists because FluidSynth linked that SONAME. It is not SDL3. Remove the stub after the real library is installed and no target ELF still needs the stub.

Status: Built on the host toolchain. SDL 3.4.12 with KMSDRM, OpenGL ES, and Wayland. The stub is not installed. A Flip has not opened an SDL3 window.

### 14E. GPTK and input

Audit gptokeyb, gptokeyb2, `.gptk`, `control.txt`, and the SDL controller map. InputPlumber keeps the virtual Xbox pad. Do not add a second grabber. MENU+START, MENU, suspend, and return to NextUI stay. Host-test the mapping before a device pass.

Status: Audited. The PortMaster seed ships AArch64 `gptokeyb` and `gptokeyb2`, plus ARMHF copies. `control.txt` points `GPTOKEYB` and `GPTOKEYB2` at the unsuffixed AArch64 binaries in the PortMaster tree. InputPlumber remains the virtual Xbox pad. No second grabber is added. A missing `.gptk` mapping is a per-port Flip check.

### 14F. Shared runtimes

Audit PortMaster runtime download, squashfs mount and teardown, AArch64 and ARMHF discovery, GL4ES, OpenAL, SDL, and the engines a port actually needs. ALSA and BlueALSA stay the audio path. Do not add a resident PulseAudio. Large engine bundles stay PortMaster downloads. `/usr/lib/compat` already holds the Theora 1.1 decoder for LÖVE.

Status: Audited. The seed's `runtimes/` directory contains LÖVE 11.5 for AArch64 and x86_64. `libs/` is empty. Other engines stay catalogue downloads. `libgl_default.txt` prepends a port's own GL4ES directory. Zlyme does not ship GL4ES or OpenAL. ALSA and BlueALSA stay. Squashfs mount and cleanup stay in `zlyme-portmaster-exec` and `zlyme-portmaster-cleanup`. `/usr/lib/compat` remains the Theora 1.1 decoder.

### 14G. Named ports

The recorded cases are Shards of God, LISA The Painful, Rakuen, Steel Assault, Skautfold: In Sanity, If On A Winter's Night, Four Travelers, and Mina the Hollower. They are background for missing infrastructure. Individual game debugging is not part of Phase 14, and running each one is not a closure requirement.

`systemctl` was reported missing.

REJECTED — a fake `systemctl`.

Status: Deferred as per-game work. The rejection stands.

### 14H. Acceptance

One late hardware pass: boot and controls, Wi-Fi off and on with one enabled network service, HDMI 720p and return to the panel, one native port and one compatibility runtime, then a clean return to NextUI with no leaked mount. Host and build checks cover the rest. Say what was not run.

Status: Planned. No `zlyme44.4` release until this pass. One candidate, then one hardware session. Pass means the observation named here. Anything else stays untested.

- Boot reaches NextUI. MENU+START returns from a game.
- Wi-Fi off stops SSH, Samba, and Syncthing. Wi-Fi on starts only the services that are enabled.
- A system without its own picture shows the Art Book overlay. A tool does too. Recently Played shows the seeded picture unless `.media` or the card background already has one.
- One native PortMaster game starts and returns. `zlyme-portmaster-cleanup` leaves no mount it recorded.
- `/usr/bin/zlyme-armhf-probe` is not the check. The ARMHF probe is in the side sysroot. On the Flip, an ELF32 hard-float program whose interpreter is `/lib/ld-linux-armhf.so.3` must print a 32-bit result while `libc.so.6` opens from `/usr/lib/zlyme-armhf`. `DEVICE_HAS_ARMHF` stays `N` until that happens.
- HDMI, with `ZLYME_HDMI_720P=1` only after the normal boot has reached NextUI. Stop the frontend and start `ZLYME_HDMI_720P=1 /usr/sbin/nextui-session`. Pass for NextUI requires `/sys/class/drm/card0-HDMI-A-1/mode` to read `1280x720` when that size is in `modes`, side bars on the UI, and the log line `ZLYME_HDMI_SCANOUT` naming that same `mode` file. That file is width and height. The clock is the CRTC line in `/sys/kernel/debug/dri/0/state` when debugfs is mounted: 74250 kHz is 60 Hz and 74176 kHz is 59.94 Hz for the 1650×750 timings. A listed fallback passes only when the sysfs `mode` file and the request log name the same size. One RetroArch core must show the same sysfs `mode` while the game keeps its own aspect. One SDL2 standalone (PPSSPP OpenGL or Flycast) must show the same sysfs `mode`. Unplug: NextUI returns, `card0-DSI-1/mode` reads `640x480`, and `/storage/.config/zlyme/display_mode` is unchanged. The saved 40, 50, or 60 Hz is the value `S16display` wrote at boot. Then stop that process. A reboot is the return to the unset path.
- Dolphin EGLDRM, PPSSPP Vulkan, AetherSX2 EGLFS, Weston, and a third-party PortMaster binary are separate observations. A shared backend that was not watched stays unproven. No SDL3 window probe is shipped. Skip that row.

The installed image stays `zlyme44.3` until that candidate is built and accepted. HDMI unplug and the ARMHF program are the two checks that can change the display or prove a new userspace. Neither needs to run before the first boot of the candidate.

### 14I. PortMaster platform

Add a small `PlatformZlyme` instead of mapping `zlyme` to `PlatformROCKNIX`. Keep `CFW_NAME=Zlyme`, the selected library, artwork import, and user-installed ports. Do not replace a PortMaster tree the user already updated. Review upstream `2026.10.03-1041` or newer before changing the pin.

Status: Host-verified. The patched `platform.py` from `2026.06.23-0015` imports, `HM_PLATFORMS['zlyme']` is `PlatformZlyme(PlatformBase)`, and `ES_NAME` stays unset. `first_run`, `portmaster_install`, and `portmaster_post_install` create no files. At that pin, `harbourmaster` never reads `ES_NAME`. Prepare still rewrites an older `PlatformROCKNIX` mapping. Not a hardware test.

### 14J. Orphan game preferences

Settings → Game removes per-ROM governor and emulator rows in `/storage/.config/nextui/shared/zlyme-prefs.txt` whose ROM is gone. Folder and system rows stay. A missing card does not count as a missing ROM. Host tests are the gate.

Status: Host-tested. The cleanup is `zlyme-game-cleanup orphan-prefs`. The replacement file is created in the preference directory and the previous file stays if that rename fails. A missing second card does not drop its rows. An unplugged USB volume whose name is only a path prefix is kept when that folder is not on a card that is in. Not a hardware test.

### 14K. Network services follow Wi-Fi

SSH, Samba, and Syncthing start only when Wi-Fi is on and that service is enabled. Turning Wi-Fi off stops all three and keeps their settings. The Settings row must not look active while Wi-Fi is off. No extra daemon, and the first frame does not wait.

Status: Host-tested. `zlyme-net-services apply` is the boot, Wi-Fi, and per-service path. A direct init start also returns without the daemon while Wi-Fi is off. The Settings switch stays the saved preference. The quick menu reads the same Wi-Fi flag. Not a hardware test.

### 14L. ArtBook defaults

Ship a verified subset of ArtBook NextUI system and root artwork as the default when the user has no image. Do not overwrite `.media` or backgrounds on update. Do not ship Theme Manager unchanged. The license check is in the research note. Splash branding stays as it is.

Status: Host-tested. `zlyme-artbook` downloads Art Book Next `d772d071` and composes a transparent 640×480 overlay for each of the 54 systems, plus one image for each built-in Tool, plus `special/recent.png` for Recently Played. NextUI selects the package. The finished PNGs are installed into the squashfs, which the full image and the OTA ship as `zlyme`. The minimal image does not. The nine tool pictures and the Recently Played picture are supplied 454×1080 illustrations. The package clips them to the Art Book silhouette. System, Tool, and Recently Played names use the same centered logo. Logos stay in the right half, at most 291 pixels wide. ROM lists do not get a bundled wallpaper. A background load that finishes after the picture was cleared does not put it back. User `.media` and `/storage/bg.png` win. Recently Played is seeded once through that `.media` path, so the name column is not reserved. The packed-rootfs check has a host fixture. A full image was not built for it. Not a hardware test.

### 14M. HDMI 720p

Prefer 1280×720 at 60 Hz on HDMI when the display lists that mode, and an EDID mode otherwise. The panel stays 640×480 at the selected refresh. Modesetting belongs to the DRM client. A write to a read-only sysfs `modes` file is not that. Drop the manual cycle if the automatic choice replaces it. No DTS change for this item.

Status: Implemented in the managed launch path, host-tested, not device-tested. `zlyme-hdmi` selects one HDMI-A mode by its connector id and its index in that connector's mode list, so 59.94 Hz stays distinct from 60 Hz. `ZLYME_HDMI_720P=1` is required. SDL 2.32.10 KMSDRM programs that DRM mode and does not mark the window fullscreen to do it. An explicit different fullscreen size is left alone. NextUI letterboxes 640×480. The sysfs `mode` file is width and height only. `ra-run` adds a session RetroArch config and does not edit the user file. Weston and AetherSX2 receive a temporary mode file whose refresh is an integer. Dolphin's EGLDRM path and PPSSPP Vulkan are not on this path. The gate is off in a normal boot. `S16display` still replays `display_mode` and still sets the panel refresh. No DTS change. The decision against the Batocera mode-index file is in the Phase 14 research note.

### 14N. Delete Game cleanup

Settings → Delete game removes that ROM, its matching saves, its `.png` / `.jpg` / `.jpeg` artwork, its exact per-ROM governor and emulator row, and its Recently Played entry. Folder and system rows stay. A same-named ROM on another card stays. Shared artwork stays while another file in that folder still uses it. The action derives the file list from the ROM again and refuses a path that is not a regular file in a mounted library. Host tests are the gate.

Status: Host-tested. Saves are taken only from that system's folder on the save-root card. A second ROM with the same stem keeps the shared save. Not a hardware test.
