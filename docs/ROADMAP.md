# Zlyme roadmap

Miyoo Flip (`my355`) is the only supported device. This file says where the work is. It is not the architecture. Current behavior is in `docs/ARCHITECTURE.md` and the other owning documents. How to write this file is in `docs/WRITING.md`.

The long record that used to live here was moved on 2026-10-15 to [docs/archive/roadmap-2026-10-15.md](archive/roadmap-2026-10-15.md). The immutable reference is `b926b9976c12ccdb3de20b629f8a550e574f8e51`. Four relative links in that copy were retargeted for `docs/archive/`. Sentences there that say Phase 13 is not scoped are that day's plan.

## Where we are

Phase 13 is closed. Published stable `zlyme44.3` is tag `zlyme-38828679802`, from `1ce2f56af1ec91a1087a01b23f741464fc6c34f6`, published 2026-10-16. The accepted device candidate was `ccd99997b98dc9015a3ed06a1808ecb2a207f197`. B6 and C1 stay excluded. `main` also has the later README commit `8b4218aa201b76e72706ab70036424c2a2dac6bc`, which is not in that firmware. Phase 14 is open on `zlyme44.4-phase-14` for `zlyme44.4`. It has not released. The installed PortMaster image is `72916de`, squashfs `cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`. The checklist is in `docs/MAINTENANCE.md`.

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

Limits, not open work: within-session cable removal was not measured, E30 stays the rollback for that limit, and `snps,dis_u2_susphy_quirk` stays. A discharge to 0% was not run. The maintainer required no further Phase 12 hardware test. On 2026-10-19, after Phase 13 had closed, the maintainer observed one automatic shutdown at 0%. That later observation is not a Phase 12 retest and does not reopen Phase 13. WestonPack cleanup and removal of obsolete PAKs are not a new hardware gate.

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

Phase 14 is open on `zlyme44.4-phase-14`. Phase 15 has not started. `zlyme44.4` has not released. `ZLYME_VERSION` stays `zlyme44.3` until a release is prepared.

The installed firmware as of 2026-10-24 was source `72916de97b2ce8a027bad14ace275ef25426a695`, squashfs `cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`, GPU `libmali`, PortMaster seed `2026.06.23-0015`. `da7eb2128294` (squashfs `f08c3fa8…`) is the previous installed image. The format=3 and format=4 validation campaigns are not the acceptance path.

The installed image on 2026-10-25 is `zlyme-my355-20261025-9acb1fcb30a5.tar` from `9acb1fcb30a5f72e1ab08aef6e9179a83619fa82`, squashfs `f90d46257936ea31293aaa63936f8bd3af290fa9c72e0e9a782ca98c71454942`, boot `e1d5969c-96f6-46cc-92d5-eb3285820dca`, GPU `libmali`. NextUI is running. The 49-SONAME ROCKNIX compatibility baseline is implemented and host-validated. That does not accept every PortMaster game, Zlyme's GL4ES fallback, or Panfrost. Aerofoil passes. X-Moto and JVGS still fail after their libraries load, and those failures are deferred. Gate 4 is the next hardware test and is not accepted.

`c67692fe7ba7d65b0a1762ee7d26a6ee5ddc4456` is not the installed firmware. It remains the image that accepted Abombniball MENU+START. `0b35a90` remains the image that accepted volume, Wi-Fi, HDMI audio, and NextUI at HDMI 720p. `4652076` remains the image that accepted the looked-at 14O rows. Later images do not rewrite those records.

Hardware acceptance is at the risky compatibility boundary, not one deferred pass at the end. The next step is the Gate 4 SDL3 hardware test. The proposal is [docs/research/phase14-portmaster-architecture-proposal.md](research/phase14-portmaster-architecture-proposal.md). The inventory is [docs/research/portmaster-capability-phase14.md](research/portmaster-capability-phase14.md). The matrix is [docs/research/portmaster-matrix-20261023.md](research/portmaster-matrix-20261023.md).

### Next decision gate

**Gate 0 approved Gate 1 only. Gate 1 and Gate 2 are hardware-accepted. Gate 3 remains open for Zlyme's GL4ES fallback and Panfrost. The 49-SONAME baseline is host-validated. Gate 4 is the next hardware test.**

Option A stays the baseline. Gate 1 corrected BusyBox `mount` of `//opt/system/Tools/PortMaster/...`. Option B stays deferred. Option C is not supported. On installed `72916de`, Steel Assault ran Mono and returned with no leftover Mono mount, and Shards of God returned with no leftover AGS bind. Winter Travelers shows a picture, takes pad input, plays audio, and returns after the maintainer set that game's loaded `acsetup.cfg` to `driver=software`. The port's original loaded file selected `D3D9`. No SDL or GPU change was required. A reinstall of the port is not guaranteed to keep that local file.

An isolated libmali GL4ES diagnostic passed on 2026-10-25. It used a private build of the same pin with `NOX11`, `NOEGL`, and `NO_INIT_CONSTRUCTOR`, called `initialize_gl4es()` after SDL created the context, flushed before each swap, and called `close_gl4es()` before SDL destroyed that context. The maintainer saw a moving triangle, the log recorded 709 frames and GL error 0, and NextUI returned with no Pak failed dialog and no leftover process or mount. That program called the GL4ES private API. It is not the installed library and not a Panfrost result. The installed library and its earlier dark-screen record stay.

Aerofoil is the accepted PortMaster GL4ES result on this image. Its launcher used the seed's `libgl_default.txt`, so `LIBGL_FB=4`, and SDL loaded the port's own `gl4es.aarch64` `libGL.so.1` and `libEGL.so.1` (GL4ES built Nov 12 2024, GBM on `card0`). The maintainer saw the game, used its menu to exit, and returned to NextUI with no leftover process, mount, or kernel fault. Zlyme's optional fallback was not the library that ran. Panfrost was not tested. One port does not accept every GL4ES game.

On the same installed image, boot `a0cf811e-e52e-453b-a7c5-a4d256b83fd4`, X-Moto and JVGS stayed blank because the dynamic linker stopped them. X-Moto needs `libxml2.so.2` and `libSDL2_net-2.0.so.0`. The system provides `libxml2.so.16` and does not provide SDL2_net. JVGS's bundled `libSDL_mixer-1.2.so.0` needs `libmodplug.so.1`, which is neither installed nor in that port. Neither reached SDL or a GL context. Their bundled GL4ES files were not loaded. The ROCKNIX compat archive at `691f24bc` supplies an unlabeled `libxml2.so.2` and neither of the other two libraries, so it is not installed. Pushed source `98ff32c` builds libxml2 2.13.9 into `/usr/lib/compat` and selects Buildroot `sdl2_net` and `libmodplug`. The maintainer installed local OTA `1b74536a35de`. Aerofoil still runs. X-Moto gets past the missing libraries and then fails in `SDL_Init` with `kmsdrm not available`. JVGS gets past `libmodplug.so.1`, warns that `.jvgs.xml` is missing, and then segmentation-faults. Neither new failure is a missing SONAME. `portmaster-rocknix-compat` installs the other 41 SONAMEs from that `compat.tar.gz` under `/usr/lib/compat`. It leaves both SDL2 objects out and does not replace the source-built `libxml2.so.2` or `libtheoradec.so.1`. `libgomp.so.1`, X11, Pango, Speex, libgcrypt, and libvdpau are source-built so those files can load. The license identifier is `LicenseRef-ROCKNIX-portmaster-compat-unspecified`. That record is not a license grant. `gl4es.tar.gz` stays out. Gate 4 is the next test.

Pushed source `5587b67` follows ROCKNIX `next` `projects/ROCKNIX/packages/graphics/gl4es/package.mk` at ROCKNIX `651150fc88a8ee40e3f8e69c6d36feb6b005bde5`: pin `81547d986798e876de8b434193920b606a72363f`, `ODROID`, `NOX11`, and `NOEGL`. It remains under `/usr/lib/portmaster/gl4es/aarch64`. `zlyme-gl4es-run` does not assign `LIBGL_FB`. A host package build passed. Installed `9acb1fc` contains that library under `/usr/lib/portmaster/gl4es/aarch64`. No port was switched onto it, and hardware acceptance is still pending. The constructor still runs. This does not close the earlier exit SIGSEGV. ARMHF GL4ES stays at `2037865590`. PortMaster's own GL4ES remains the contract normal ports use.

### 14A. Capability baseline

Compare official PortMaster, the pinned `2026.06.23-0015` seed, upstream `2026.10.03-1041` or a newer stable tag if one exists when the update is reviewed, and the relevant ROCKNIX, KNULLI, and Batocera packaging. Record implemented, missing, partial, and hardware-limited. Do not copy another distribution's claim into Zlyme. Do not treat a newer upstream `funcs.txt` as identical to this seed. Do not redistribute a proprietary blob because another distribution ships it.

Status: Inventory exists for this tree. The pin is still `2026.06.23-0015`. `zlyme` maps to `PlatformZlyme`. The recorded comparison, including historical `Zetarancio/distribution` branch `flip` at PortMaster `2026.05.04-1202` and official ROCKNIX commits already listed in `docs/UPSTREAMS.md`, is in the decision note. That comparison is not an implementation.

### 14B. ARMHF userspace

Ship a real 32-bit ARM hard-float userspace, not only a loader name. Prefer a separate Buildroot ARMHF target in the KNULLI style (`knulli-rk3566_armhf_libs`). Use an ARM EABI hard-float toolchain and matching glibc. Do not import another distribution's binaries. Do not set `DEVICE_HAS_ARMHF=Y` until a dynamically linked ARMHF program runs and its libraries resolve.

Status: Host-tested through qemu-user, and installed into the product target tree. `output-armhf` is built by `scripts/build-armhf-sysroot.sh`. `zlyme-armhf-runtime` checks its manifest and copies the loader and `/usr/lib/zlyme-armhf/` into the AArch64 root. A stale or missing manifest fails the package. The minimal image does not select it. A disposable Debian container with qemu-user 10.0.13 ran the probe: ELF32 ARM hard-float, interpreter `/lib/ld-linux-armhf.so.3`, `libc.so.6` from the private directory, output `armhf 32 0.3`. With `LD_LIBRARY_PATH=/usr/lib` the loader tries the AArch64 `libc.so.6` and then uses the private one. On the installed `00e6c343` image, `xdelta3.armhf -V` printed `Xdelta version 3.1.1`. The file is ELF32 ARM hard-float, the interpreter is `/lib/ld-linux-armhf.so.3`, and `libc.so.6` opened from `/usr/lib/zlyme-armhf`. `control.txt` now exports `DEVICE_HAS_ARMHF=Y`. `DEVICE_ARCH` stays `aarch64`. The bit is that userspace. It is not proof that every ARMHF port runs. Abombniball's tree has `libs.aarch64/libSDL_image-1.2.so.0` as ELF64 and no `libs.armhf` directory; its launcher selects `abombniball.${DEVICE_ARCH}`.

### 14C. Box86 and Box64

Keep the working Box64 and Wine path. Compare native Box86 with Box64's BOX32 against what PortMaster runs. Pick one combination. Do not enable both to raise a count.

Status: Implemented. On installed `da7eb21`, the legal console probe
`zlyme-box86-run` printed `box86-x86 4 475f677f` and exited 0. That
is not a graphical result. Native ARMHF Box86 is built from pinned
upstream `bb716a2a6576cc06da811bf55e31e2f6f03b7596`, imported through
a checked artifact manifest, and invoked explicitly by
`zlyme-box86-run`. There is no binfmt registration or permanent
service. Host qemu-arm checks still reject invalid ELF and unresolved
library paths. Box64 remains pinned at `2f130fab`, `BOX32=OFF`, and
Wine remains the amd64 WOW64 build. Graphical Box86 is still untested.
Its ARMHF EGL/GLES provider is Mesa/Panfrost, because the libmali
payload is AArch64-only. A libmali boot does not provide ARMHF
graphics.

### 14D. Graphics and SDL3

Audit GLES via libmali and Panfrost, GL4ES, SDL 1.2 compatibility, the existing SDL2, KMS/DRM, and application-scoped WestonPack. Do not add a permanent compositor or system Xwayland. Vulkan follows the saved GPU choice: libmali uses the proprietary Mali ICD, `panfrost` stays OpenGL, and `panvk` is the only PanVK opt-in. Neither Vulkan path is hardware-accepted here.

Ship Buildroot 2026.08's `BR2_PACKAGE_SDL3` with the KMSDRM, OpenGL ES, and Wayland options that package actually has. The `libSDL3.so.0` stub in `board/my355/post-build.sh` exists because FluidSynth linked that SONAME. It is not SDL3. Remove the stub after the real library is installed and no target ELF still needs the stub.

Status: Partial on installed `da7eb21`, libmali. SDL 3.4.12 provides
KMSDRM, OpenGL ES, and Wayland, and the old stub is absent. The SDL3
Tools probe selected an OpenGL ES2 renderer, saw the Xbox 360 virtual
pad, logged button events, and exited with `SDL3_DONE frames=512
input=1`. The maintainer saw no on-screen reaction to the pad. The
probe does not draw a response to those events. Event delivery is
PASS. Visual controller feedback is NOT DEMONSTRATED. That is not an
InputPlumber failure.

The installed GL4ES Tools probe logged `LIBGL_FB=3`, KMSDRM, and
`GL4ES_READY` with Mali-G52. The screen stayed black. MENU+START
returned. No `GL4ES_DONE` line was recorded. Context initialization
was observed. Visible rendering of that installed library is FAIL.
Later, on 2026-10-25, one private library from pin `2037865590` rendered
a moving triangle on libmali and returned to NextUI. That library
was not installed, and the program called GL4ES directly. Aerofoil
then passed on its bundled GL4ES. X-Moto and JVGS failed earlier, in
the dynamic linker, on missing `libxml2.so.2` and `libmodplug.so.1`.
Panfrost GL4ES was not run. GL4ES is not a general PortMaster result.
Pushed source `5587b67` follows the ROCKNIX `NOX11` and `NOEGL` pin.
A host build passed. Installed `9acb1fc` contains that library.
Hardware acceptance is still pending. On that image X-Moto and JVGS
get past the loader. X-Moto stops in its own database check and JVGS
segmentation-faults. Those failures are deferred. The dynamic-linker
stops stay the record of `72916de`.

Pinned GL4ES stays in explicit isolated AArch64 and ARMHF directories
and does not replace a system GL/EGL/GLES link or a port-bundled copy.
No shared SDL1.2 requirement was proved, so no conflicting SDL
compatibility layer was added. DRM debugfs clients were unavailable
on this pass. An empty client list was not observed, so DRM ownership
is UNKNOWN. An earlier idle inspection saw only `nextui.elf` holding
`/dev/dri/card0`. That is not a master-ownership PASS.

### 14E. GPTK and input

Audit gptokeyb, gptokeyb2, `.gptk`, `control.txt`, and the SDL controller map. InputPlumber keeps the virtual Xbox pad. Do not add a second grabber. MENU+START, MENU, suspend, and return to NextUI stay. Host-test the mapping before a device pass.

Status: Abombniball MENU+START stays accepted on `c67692f`. On
installed `da7eb21`, Shards of God started under gptokeyb with
`./shardsofgod.gptk` and the maintainer reports usable controller
input. The expected file was restored with a non-overwriting copy
from the Syncthing conflict file. The conflict original remains.
That result is this port, not every gptokeyb port. The seed's
unsuffixed gptokeyb binaries remain AArch64. InputPlumber remains
the virtual Xbox pad. No second grabber was added. Review of
LoveRetro NextUI, ROCKNIX, rocknix-hotkey, and PortMaster did not
justify replacing Zlyme's ownership model with application-name
`killall`. `zlyme-pak-spawn` distinguishes `/proc` failure from an
empty session, ignores zombies, and signals only a verified
pid/start-time/PGID/SID through a pidfd. Unresolved ownership stays
status 125. That hardening is later than `c67692f`, so Abombniball
still needs one focused rerun on a final candidate. The `c67692f`
acceptance stays.

### 14F. Shared runtimes

Audit PortMaster runtime download, squashfs mount and teardown, AArch64 and ARMHF discovery, GL4ES, OpenAL, SDL, and the engines a port actually needs. Native `libpulse` clients use `pipewire-pulse` on the one PipeWire graph. ALSA stays the hardware path. PipeWire's BlueZ monitor owns A2DP. The PulseAudio daemon and BlueALSA are not this graph. Large engine bundles stay PortMaster downloads. `/usr/lib/compat` holds the Theora 1.1 decoder for LÖVE, libxml2 2.13.9, and the ROCKNIX SONAME allowlist.

Status: Infrastructure is in the image. Representative execution is
partial. PipeWire, WirePlumber, and `pipewire-pulse` remain the one
audio graph. The seed keeps LÖVE 11.5. Other engine squashfs files
remain user-selected PortMaster downloads. On `da7eb21`, Steel
Assault's Mono squashfs is present on SD2 and the launch still failed:
`taskset not found, bailing...`, `mount: bad address 'opt'`, source
`//opt/system/Tools/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs`,
then `mono: command not found`. That is a runtime path and mount
failure. It does not prove the bytes are missing, and it does not
isolate one shell expansion. On installed `72916de` that mount path is corrected and Steel Assault
ran. The `da7eb21` failure stays the record of the earlier image.
GL4ES context init was observed and visible rendering of the
installed library failed, as in 14D. The 2026-10-25 private
diagnostic is not that library and is not a port. Console Box86
passed. Graphical Box86, WestonPack, and a candidate LÖVE render on
this image were not in this archive.
Mount cleanup still uses one recorded owner. Package presence is
not a rendered result.

### 14G. Named ports

The recorded cases are Shards of God, LISA The Painful, Rakuen, Steel
Assault, Skautfold: In Sanity, If On A Winter's Night, Four Travelers,
and Mina the Hollower. Audit each installed launcher and run every case
whose legal data and runtime are present. Missing proprietary data or a
user-declined runtime download is an attributable external blocker,
not PASS.

`systemctl` was reported missing.

REJECTED — a fake `systemctl`.

Status: Open. The current image is `72916de`. An earlier bounded check on a previous card did not
find the Mono squashfs. The 2026-10-23 evening archive shows that
file on SD2, and the launch still did not run `mono`. That later
observation does not delete the earlier check.

On `da7eb21`: Shards of God starts and takes pad input. Winter
Travelers failed on a D3D9 graphics setting. Both logs contain the
same KMSDRM cursor line. The contrast is in the matrix. Steel
Assault failed as in 14F. On installed `72916de`, Steel Assault and
Shards of God ran and returned. Winter also runs after the
maintainer set `ioawn4t/gamedata/acsetup.cfg` to `driver=software`.
That is a local game file. The earlier `D3D9` file remains the
incompatible original. The later isolated GL4ES diagnostic does not change these port results. LISA and Rakuen were not rerun in this archive. Skautfold
remains external data (`game.droid` absent in the earlier card
inspection). Mina's complete diagnostic was not in this archive.
Ascent DX on Panfrost was not run. LISA, Rakuen, Steel Assault, and
Winter still request `systemctl restart oga_events` after exit.
`zlyme-portmaster-exec` translates that request to `zlyme-input
ensure`. It does not provide a fake `systemctl`. One AGS success
does not mean every AGS port works.

### 14H. Acceptance

Volume and mute, Wi-Fi off and on, NextUI at HDMI 720p, and the internal
panel coming back remain accepted on installed `0b35a90`. The 14O rows
that were looked at remain accepted on installed `4652076`; a user
background was not a separate check. Abombniball MENU+START is accepted
on `c67692f`. Still open on a final candidate: Abombniball after
waiter hardening, graphical Box86, visible GL4ES, an SDL3 picture
that matches the events already logged on `da7eb21`, each remaining
eligible named port, and representative LÖVE, Mono, and WestonPack
runs that are actually installed. Audio, exit, NextUI return, owned
processes, and mounts stay separate from a process exit. RetroArch's
own 1280×720 CRTC stays open and does not reopen the accepted NextUI
HDMI result. The matrix is
[docs/research/portmaster-matrix-20261023.md](research/portmaster-matrix-20261023.md).

Status: Open. The installed PortMaster image is source `72916de`,
squashfs `cfb3873a5a1619330c33f483cfe8cac9c855a691ee4bab091b6d09fb965c02b6`.
Gate 1 is accepted there. `da7eb21` remains the earlier PortMaster
image.
It does not inherit hardware acceptance from `c67692f` or from
`0b35a90`. Dated failures and acceptances for earlier images stay in
the logbook and the matrix. Supersession is a later entry, not an
edit of the old result.

Ordered later work, none of it started, is in the decision note:
runtime paths (Steel), AGS graphics (Winter without breaking Shards),
visible GL4ES on Mali then Panfrost, SDL3 picture plus the events
already seen, representative engines, then regression against the
accepted items below. Gate 0 is the architecture review. It is not
approved.

- Boot reaches NextUI. MENU+START returns from a game.
- Wi-Fi off stops SSH, Samba, and Syncthing. Wi-Fi on starts only the services that are enabled. Run this on the device. Do not turn Wi-Fi off over the live SSH session. Accepted on `0b35a90`. Do not repeat it on this image.
- A system without its own picture shows the Art Book overlay. A tool does too. Recently Played shows `/storage/.config/nextui/shared/artbook/special/recent.png` when that file exists, then `/storage/bg.png`, then `/usr/share/nextui/artbook/special/recent.png`. The folder can be absent. A picture left in the folder is not used. Session start does not copy or delete one. An update from zlyme44.3 copies a non-built-in picture from the old folder path into the shared override when the override is absent, and leaves the old file and the history list in place.
- One native PortMaster game starts and returns. `zlyme-portmaster-cleanup` leaves no mount it recorded.
- `/usr/bin/zlyme-armhf-probe` is not the check. The ARMHF userspace check is an ELF32 hard-float program whose interpreter is `/lib/ld-linux-armhf.so.3` and whose `libc.so.6` opens from `/usr/lib/zlyme-armhf`. `xdelta3.armhf` did that and printed `Xdelta version 3.1.1`. `DEVICE_HAS_ARMHF=Y` advertises that ABI. Every ARMHF port working is still not proven.
- PipeWire, WirePlumber, and `pipewire-pulse` start from `rc.late` after the first frame. The codec, HDMI when the connector is connected and the published ELD advertises a format, and an A2DP headset share that graph. On installed `0b35a90` the maintainer accepts HDMI television audio, disconnect back to the speaker, the external-audio mark clearing, reconnect back to the television, and Bluetooth disconnect and reconnect. Volume and mute, including sound returning after mute, are accepted on that image. `74597688` left the speaker silent after HDMI unplug. That failure stays with that image. The route file names the effective default sink and does not select it. A radio link and that sink are different marks. A saved zero stays silent. The headphone jack follows the plug. Speaker quality, the icons, television audio, Bluetooth playback, and the jack passed on `be5d8c0` and were not withdrawn. The PulseAudio daemon and BlueALSA are the earlier candidate, not this graph. A Bluetooth scan in Settings lists a nearby device, including one with no class. RetroArch's KMS path is separate and is not proof of the SDL panel-off.
- HDMI, with `ZLYME_HDMI_720P=1` only after the normal boot has reached NextUI. A normal boot still leaves the gate unset and keeps the internal panel at 640×480. One session owns DRM. `S28minui stop` does not stop it. With SSH already connected and Wi-Fi left on, end that session, confirm `pidof nextui-session` is empty, and start one `ZLYME_HDMI_720P=1 /usr/sbin/nextui-session`. Quitting the picture restarts it still gated. Return is to end that session and start one ungated session. A hang does not restore the panel. Reboot does: `/run` is cleared and boot is ungated. Do not start a second session beside the owner. Pass requires an HDMI CRTC at 1280×720 whose clock is 74250 kHz for the 1650×750 60 Hz mode, the DSI CRTC inactive, and the internal panel dark. The sysfs `mode` file is not that proof. One RetroArch GLES core must show the same HDMI CRTC while the game keeps its own aspect. That RetroArch path does not use the SDL panel-off patch and is not yet proven. Unplugging the cable does not program the panel back. The return is the ungated session. That session scans the panel at the saved 640×480 mode, and `/storage/.config/zlyme/display_mode` is unchanged. Connecting the cable while NextUI is already running does not switch. A failed HDMI modeset must leave the panel scanning. Earlier candidates kept both CRTCs active. That is history, not this requirement.
- Dolphin EGLDRM, PPSSPP Vulkan, AetherSX2 EGLFS, Weston, and a third-party PortMaster binary are separate observations. A shared backend that was not watched stays unproven. On `da7eb21` the GL4ES probe initialized and the picture stayed black. The SDL3 probe delivered pad events. Visual button feedback was not demonstrated. Neither probe is accepted as complete. RetroArch's own 1280×720 CRTC remains open. The accepted NextUI HDMI 720p result on `0b35a90` stays closed.

The version string stays `zlyme44.3`. `c67692f` accepts Abombniball
MENU+START. `4652076` retains the looked-at 14O rows. `0b35a90`
retains HDMI, volume, Wi-Fi, and panel acceptance. A user background
was not a separate 14O check. RetroArch's own KMS path and the
runtime matrix remain open. No `zlyme44.4` release until this pass.

### 14I. PortMaster platform

Add a small `PlatformZlyme` instead of mapping `zlyme` to `PlatformROCKNIX`. Keep `CFW_NAME=Zlyme`, the selected library, artwork import, and user-installed ports. Do not replace a PortMaster tree the user already updated. Review upstream `2026.10.03-1041` or newer before changing the pin.

Status: Host-verified. The patched `platform.py` from `2026.06.23-0015` imports, `HM_PLATFORMS['zlyme']` is `PlatformZlyme(PlatformBase)`, and `ES_NAME` stays unset. `first_run`, `portmaster_install`, and `portmaster_post_install` create no files. At that pin, `harbourmaster` never reads `ES_NAME`. Prepare still rewrites an older `PlatformROCKNIX` mapping. Not a hardware test.

### 14J. Orphan game preferences

Settings → Game removes per-ROM governor and emulator rows in `/storage/.config/nextui/shared/zlyme-prefs.txt` whose ROM is gone. Folder and system rows stay. A missing card does not count as a missing ROM. Host tests are the gate.

Status: Host-tested. The cleanup is `zlyme-game-cleanup orphan-prefs`. The replacement file is created in the preference directory and the previous file stays if that rename fails. A missing second card does not drop its rows. An unplugged USB volume whose name is only a path prefix is kept when that folder is not on a card that is in. Not a hardware test.

### 14K. Network services follow Wi-Fi

SSH, Samba, and Syncthing start only when Wi-Fi is on and that service is enabled. Turning Wi-Fi off stops all three and keeps their settings. The Settings row must not look active while Wi-Fi is off. No extra daemon, and the first frame does not wait.

Status: Accepted on installed `0b35a90`, 2026-10-23. Wi-Fi off and on restored the enabled services. Do not turn Wi-Fi off over an SSH session that is using that radio. `zlyme-net-services apply` is the boot and per-service path. A Wi-Fi toggle starts one short-lived worker and returns. The worker rereads the saved flag; a following toggle is the state that remains. A direct init start also returns without the daemon while Wi-Fi is off. The Settings switch stays the saved preference. The quick menu reads the same Wi-Fi flag. The 2026-10-23 acceptance used the Flip's own switch.

### 14L. ArtBook defaults

Ship a verified subset of ArtBook NextUI system and root artwork as the default when the user has no image. Do not overwrite `.media` or backgrounds on update. Do not ship Theme Manager unchanged. The license check is in the research note. Splash branding stays as it is.

Status: Host-tested. `zlyme-artbook` downloads Art Book Next `d772d071` and composes a transparent 640×480 overlay for each of the 54 systems, plus one image for each built-in Tool, plus `special/recent.png` for Recently Played, plus `special/tools.png` for the Tools root. The root picture uses the upstream `tools.png` and `tools.svg`. MKXP-Z uses the EasyRPG illustration and its own wordmark. Generated wordmarks use Changa One Italic from that archive. The nine pak pictures are otherwise unchanged. NextUI clears the background layer before blending the next picture, so a transparent overlay does not keep the previous art. NextUI selects the package. The finished PNGs are installed into the squashfs, which the full image and the OTA ship as `zlyme`. The minimal image does not. The nine tool pictures and the Recently Played picture are supplied 454×1080 illustrations. The package clips them to the Art Book silhouette. System, Tool, and Recently Played names use the same centered logo. Logos stay in the right half, at most 291 pixels wide. ROM lists do not get a bundled wallpaper. A background load that finishes after the picture was cleared does not put it back. User `.media` and `/storage/bg.png` win. Recently Played is seeded once through that `.media` path, so the name column is not reserved. The packed-rootfs check has a host fixture. A full image was not built for it. Not a hardware test.

### 14M. HDMI 720p

Prefer 1280×720 at 60 Hz on HDMI when the display lists that mode, and an EDID mode otherwise. A normal boot keeps the internal panel at 640×480. After HDMI scanout succeeds under `ZLYME_HDMI_720P=1`, the internal DSI CRTC is off. Leaving that client restores the panel. Modesetting belongs to the DRM client. RetroArch uses its own KMS path and has not shown this on a Flip. A write to a read-only sysfs `modes` file is not that. Drop the manual cycle if the automatic choice replaces it. No DTS change for this item.

Status: Implemented in the managed launch path, host-tested. On the installed candidate, with the gate passed only to that one query, `zlyme-hdmi` selected HDMI-A-1 at 1280×720, mode index 10, 60.000 Hz. It did not modeset. The session gate was unset, and both sysfs `mode` files were empty. `zlyme-hdmi` selects one HDMI-A mode by its connector id and its index in that connector's mode list, so 59.94 Hz stays distinct from 60 Hz. `ZLYME_HDMI_720P=1` is required. SDL 2.32.10 KMSDRM programs that DRM mode and does not mark the window fullscreen to do it. An explicit different fullscreen size is left alone. NextUI letterboxes 640×480. The sysfs `mode` file is width and height only. `ra-run` adds a session RetroArch config and does not edit the user file. Weston and AetherSX2 receive a temporary mode file whose refresh is an integer. Dolphin's EGLDRM path and PPSSPP Vulkan are not on this path. The gate is off in a normal boot, and the panel stays 640×480. With the gate on, a successful HDMI scanout disables the DSI CRTC. On 2026-10-23 the maintainer accepts NextUI at HDMI 720p and the internal panel coming back, on installed `0b35a90`. RetroArch's own KMS path was not given a separate CRTC observation. That limit does not reopen the NextUI result. Audio acceptance is a separate gate and was already closed on this image. The gated process does not program the panel back on exit. `/run/zlyme/hdmi-panel-off` tells the next ungated SDL client to modeset DSI. There is no watchdog if that client hangs. Reboot clears `/run` and boots ungated. `S16display` still replays `display_mode` and still sets the panel refresh. No DTS change. The decision against the Batocera mode-index file is in the Phase 14 research note.

### 14N. Delete Game cleanup

Settings → Delete game removes that ROM, its matching saves, its `.png` / `.jpg` / `.jpeg` artwork, its exact per-ROM governor and emulator row, and its Recently Played entry. Folder and system rows stay. A same-named ROM on another card stays. Shared artwork stays while another file in that folder still uses it. The action derives the file list from the ROM again and refuses a path that is not a regular file in a mounted library. Host tests are the gate.

Status: Host-tested. Saves are taken only from that system's folder on the save-root card. A second ROM with the same stem keeps the shared save. Not a hardware test.

### 14O. List text width

Accepted on installed `zlyme-my355-20261023-465207696ff8.tar`, NextUI `b0960dcde4d69d32871d6605c354b1b901621eb5`, for the rows that were looked at. A user background was not a separate check. Do not change this geometry without a demonstrated regression.

The selection pill and the scrolling text use one width. The first row stops at the hardware cluster. A later row does not. A ROM thumbnail limits a row that meets that picture, using the same box the thumbnail is drawn in. Art Book stops at x=320 and does not also subtract the cluster. A user background does not reserve that column. The scroll texture stays inside the pill. A surface width does not go to zero. Game art width stays in Settings. Its displayed percent multiplies before the cast, so 0.45 shows as 45. The settings file writer already did that and was left as it was. Saved settings are not migrated. Sorting prefixes stay on the stored name.

The previous pin `666ff5fdf737a01f83505b843916ac9c46da80d6` subtracted `ow` on the first row with no thumbnail, and the scroll path subtracted it again. That is the narrow first row. Host checks are `scripts/tests/test_list_width.sh`.

On the installed image, the first row and a later row with no picture, a ROM thumbnail, Art Book system and tool artwork, a long name inside the pill, and the default Game art percent were accepted. `/storage/bg.png` was not a separate check.
