# Zlyme roadmap

Miyoo Flip (`my355`) is the only supported device. This file says where the work is. It is not the architecture. Current behavior is in `docs/ARCHITECTURE.md` and the other owning documents. How to write this file is in `docs/WRITING.md`.

The long record that used to live here was moved on 2026-10-15 to [docs/archive/roadmap-2026-10-15.md](archive/roadmap-2026-10-15.md). The immutable reference is `b926b9976c12ccdb3de20b629f8a550e574f8e51`. Four relative links in that copy were retargeted for `docs/archive/`. Sentences there that say Phase 13 is not scoped are that day's plan.

## Where we are

Phase 14 is closed, 2026-10-26, after the final reconciliation in 14P. Gate 5 was accepted within its recorded scope on installed `0017d58`, OTA `zlyme-my355-20261025-0017d580b025.tar`, squashfs `2aecb98a91ae4f57126badc4b7e0b76c1adec8fa3f54e9c9bf66b221e1a0b7d1`. Gate 6's mandatory checklist is closed with the evidence and exclusions below. [Phase 15](#phase-15-documentation-and-zlyme444-preparation) is in progress. The installed candidate is `zlyme-my355-20261026-d358bf533e79.tar`, source `d358bf533e79d058bb63bfc32487bd544d8eb5de`, squashfs `e3772c9f0760c494120098cddb5575e195aaa5e57212aaf14def79f68758d10b`. The maintainer reports that this installation functions, and a read-only check matched that identity. It is not the `zlyme44.4` release. `ZLYME_VERSION` remains `zlyme44.3`. Published stable `zlyme44.3` remains tag `zlyme-38828679802`, from `1ce2f56af1ec91a1087a01b23f741464fc6c34f6`, published 2026-10-16.

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
| 14 | 2026-10-26. Gates reconciled and 14P executed. Release not published. | [Phase 14](#phase-14-portmaster-compatibility-and-zlyme444) |

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

Objective: broaden PortMaster compatibility and finish the accepted settings, artwork, audio, display, and list behavior intended for `zlyme44.4`.

Status: Closed, 2026-10-26. Gate 5 is accepted within its recorded scope on installed `0017d58`. Gate 6 is closed by reconciling the mandatory checklist with existing evidence and explicit exclusions; it does not invent a RetroArch HDMI result. Phase 15 has not started, `zlyme44.4` has not released, and `ZLYME_VERSION` remains `zlyme44.3`. No final release OTA or source SHA exists yet.

Main result: Zlyme has a private ARMHF userspace, explicit Box86, SDL3 KMSDRM, the 49-SONAME compatibility baseline, safer PortMaster process and mount ownership, one PipeWire graph, `PlatformZlyme`, Art Book defaults, Wi-Fi-owned services, game cleanup, HDMI policy, and corrected list geometry. Runtime cleanup commit `b114755` removed unused Phase 14 experiments.

References: [architecture proposal](research/phase14-portmaster-architecture-proposal.md), [capability inventory](research/portmaster-capability-phase14.md), [acceptance matrix](research/portmaster-matrix-20261023.md), [ROCKNIX compatibility coverage](research/phase14-rocknix-compat-coverage.md), and [logbook](LOGBOOK.md) entries dated 2026-10-19 through 2026-10-26.

### 14A. Capability baseline

Status: Closed. The inventory distinguishes implemented, missing, partial, and hardware-limited capabilities against the pinned PortMaster `2026.06.23-0015` seed and named comparison trees. Comparisons remain evidence, not Zlyme implementation claims. See the [capability inventory](research/portmaster-capability-phase14.md).

### 14B. ARMHF userspace

Status: Closed. A separately built ARM hard-float sysroot installs its loader and libraries under `/usr/lib/zlyme-armhf`; the product image advertises `DEVICE_HAS_ARMHF=Y`, while the minimal image omits the runtime. QEMU host checks and `xdelta3.armhf` on a Flip verified the ELF32 interpreter and private libc. Bowling Cross later reached native ARMHF GameMaker gameplay on Panfrost. This does not claim that every ARMHF port works.

### 14C. Box86 and Box64

Status: Closed. Pinned native ARMHF Box86 is explicit through `zlyme-box86-run`, with no binfmt registration or service; its legal console probe passed. Box64 remains `BOX32=OFF` and the existing amd64 WoW64 Wine path is unchanged. Graphical Box86 had no installed candidate and is not applicable to Gate 5's installed set.

### 14D. Graphics and SDL3

Status: Closed. SDL 3.4.12 ships with KMSDRM, OpenGL ES, and Wayland; its libmali probe showed a picture, recorded Xbox 360 input, returned to NextUI, and left no client or mount. Aerofoil accepted its port-bundled AArch64 GL4ES on libmali. The ARMHF Mesa/Panfrost and isolated ARMHF GL4ES runtime remain for native and Box86 ports.

The unused Zlyme AArch64 GL4ES fallback stayed black and had no consumer, so `b114755` removed it and its production wrapper. Port-bundled GL4ES, SDL3, ARMHF GL4ES, Mesa, and compatibility libraries remain. No system GL/EGL/GLES link was replaced, and no permanent compositor or system Xwayland was added.

### 14E. GPTK and input

Status: Closed. InputPlumber remains the one virtual Xbox-pad owner, with the seed's GPTK tools used per port and no second grabber. Process cleanup signals only verified session ownership. Abombniball ran and returned through MENU+START on `9acb1fc`, which includes that waiter hardening.

### 14F. Shared runtimes

Status: Closed. PortMaster retains user-selected engine downloads and releases recorded squashfs and bind mounts by owner. The corrected `//opt/...` handling let Steel Assault's Mono runtime run and return.

`/usr/lib/compat` supplies the host-validated 49-SONAME baseline: 41 allowlisted unmodified files from the pinned ROCKNIX archive, six source-built/system SONAMEs, and source-built `libxml2.so.2` and `libtheoradec.so.1`. The two archive SDL2 objects and `gl4es.tar.gz` are not installed. The imported files use `LicenseRef-ROCKNIX-portmaster-compat-unspecified`; their per-file provenance record is not a license grant.

PipeWire, WirePlumber, and `pipewire-pulse` remain the one product and minimal-image audio graph. ALSA is the hardware backend and PipeWire's BlueZ monitor owns A2DP; no PulseAudio daemon or BlueALSA graph was added.

### 14G. Named ports

Status: Closed within the installed legal-data set. Shards of God, Steel Assault, LISA, Rakuen, and Winter Travelers with its local software-renderer setting ran in their recorded scopes. No fake `systemctl` was added; supported restart requests map to `zlyme-input ensure`.

Mina is accepted through Panfrost GLES on `0017d58`, not Vulkan. The earlier libmali `VK_ERROR_SURFACE_LOST_KHR` remains unresolved. X-Moto's database failure and JVGS's application crash occur after compatibility libraries load and are deferred application failures. Skautfold remained blocked on missing port data.

### 14H. Acceptance

Status: Closed. Gate 5 was accepted within the recorded scope on installed `0017d58`. Accepted categories are LÖVE on libmali and Panfrost, Godot/FRT, AArch64 GameMaker, mkxp, native ARMHF GameMaker gameplay on Panfrost, Aerofoil's bundled GL4ES on libmali, Abombniball MENU+START, SDL3 KMSDRM on libmali, the reported GPU switch and rollback, and Mina on Panfrost GLES.

Gate 5 excludes graphical Box86 and WestonPack because no installed game used them, Mina Vulkan, Bowling Cross's clean exit after accepted gameplay, the deferred X-Moto and JVGS application failures, and the removed optional Zlyme AArch64 GL4ES fallback. Those are not converted into passes.

Gate 6's mandatory checklist is closed by reconciling existing evidence. The forced-session RetroArch HDMI CRTC/74250 diagnostic is explicitly excluded. Normal HDMI reportedly switches NextUI to the television, but that report is not proof of timing, clock, or DSI state. No RetroArch HDMI result is claimed. One RetroArch run on the internal panel on `0017d58` remains untested and nonblocking.

Earlier scoped acceptances remain evidence: volume, mute, Wi-Fi service return, HDMI audio, and the forced-session NextUI 720p/panel-return path on `0b35a90`; the looked-at list rows on `4652076`; and Abombniball after waiter hardening on `9acb1fc`. See the [matrix](research/portmaster-matrix-20261023.md) and dated logbook entries for exact limits.

### 14I. PortMaster platform

Status: Closed and host-verified. The pinned seed maps `zlyme` to a small `PlatformZlyme`, keeps `CFW_NAME=Zlyme`, and preserves the selected library, artwork, installed ports, and user-updated PortMaster tree. It does not impersonate ROCKNIX or add unused `ES_NAME` behavior.

### 14J. Orphan game preferences

Status: Closed and host-tested. Settings removes per-ROM governor and emulator rows only when the ROM is absent from a mounted library. Folder and system rows stay, and a missing card does not make its preferences orphaned. Replacement is atomic; failure leaves the previous file.

### 14K. Network services follow Wi-Fi

Status: Closed and accepted on `0b35a90`. Wi-Fi off stops SSH, Samba, and Syncthing without clearing their saved switches; Wi-Fi on starts only the enabled services. The work is short-lived and does not delay the first frame. Do not turn Wi-Fi off through the SSH session using that radio.

### 14L. ArtBook defaults

Status: Closed and host-tested. The product image ships licensed transparent Art Book defaults for 54 systems, built-in Tools, the Tools root, and Recently Played; the minimal image does not. User `.media` and `/storage/bg.png` take priority. Updates preserve a non-built-in Recently Played picture, and ROM lists do not gain a second bundled wallpaper. See [the Art Book research](research/nextui-theme-manager-phase14.md).

### 14M. HDMI 720p

Status: Closed with scoped evidence. The managed forced-session path selects a listed 1280×720 60 Hz HDMI mode, letterboxes NextUI, disables the separate DSI CRTC after successful scanout, and lets the next ungated SDL client restore the panel. That NextUI path was accepted on `0b35a90`; sysfs mode text alone is not proof, there is no hang watchdog, and reboot remains the recovery.

Normal HDMI reportedly switches NextUI to the television, but that report does not prove the CRTC timing, 74250 kHz clock, or DSI state. RetroArch has an independent KMS path. Its forced-session HDMI diagnostic is excluded from Gate 6, no RetroArch HDMI result is claimed, and the unrun internal-panel RetroArch check on `0017d58` is nonblocking.

### 14N. Delete Game cleanup

Status: Closed and host-tested. Delete Game revalidates a regular ROM in a mounted library, then removes that ROM, matching saves and artwork, its exact per-ROM choices, and its Recently Played entry. Same-named games on another card, folder/system choices, and files still shared by another ROM stay.

### 14O. List text width

Status: Closed and accepted on installed `4652076` for the rows inspected. Selection and scrolling use one width; status icons, ROM thumbnails, and Art Book reserve only their actual columns, and the Game art percentage displays correctly. A user background was not separately checked. Do not change this geometry without a demonstrated regression.

### 14P. Final reconciliation, cleanup and release-readiness review

Status: Executed, 2026-10-26. Source, documentation, changelog, provenance, package separation, migration safety, and the scoped hardware evidence were reconciled. The long chronology remains in the [logbook](LOGBOOK.md) and linked research notes.

Runtime cleanup commit `b114755` removed the unused AArch64 GL4ES fallback, its production wrapper, the graphics probes, and the disposable validation PAK installer. It preserves Aerofoil's port-bundled GL4ES, the ARMHF GL4ES/Mesa runtime, SDL3, compatibility libraries, and useful read-only host diagnostics.

The OTA migration removes each of the three Phase 14 probe PAKs only when its ownership marker, exact launcher contents, and exact generated two-file tree match. A changed or user-created PAK stays.

Release publication is separate work. At this closure, Phase 15 had not started. `zlyme44.4` is not released and `ZLYME_VERSION` is unchanged. The local OTA built from `d358bf5` was installed afterward; that check is in the logbook and is not a release.

## Phase 15. Documentation and zlyme44.4 preparation

Status: In progress, 2026-10-26. 15A and 15B are closed. 15C is next. `zlyme44.4` is not released. `ZLYME_VERSION` remains `zlyme44.3`. The installed candidate named above is the firmware under test, not the release image.

Objective: correct the documentation against the Phase 14 source, then retest two measured RetroArch issues and prepare the release only after approval.

### 15A. Documentation inventory and scope

Status: Closed, 2026-10-26. The inventory is `docs/research/documentation-audit-phase15.md`. Current-state contradictions it names were corrected in the owning documents. Vendored licenses, package prose, and USB evidence were not rewritten.

### 15B. Documentation reconciliation and ADRs

Status: Closed, 2026-10-26. `docs/ARCHITECTURE.md` now describes the PipeWire boot and the version-independent DMC module path. The retired PulseAudio and BlueALSA text is in `docs/research/audio-phase14.md`. ADR 0007, 0008, and 0009 record the audio, GPU, and PortMaster decisions. The upstream-first procedure is in `docs/UPSTREAMS.md`.

### 15C. GitHub issues #2 and #3

Status: Next. The first step is a read-only investigation of GitHub issues #2 and #3 on the installed `d358bf5` PipeWire image. No fix is proposed until that investigation is done.

### 15D. Final validation and zlyme44.4 release preparation

Status: Planned. Reconcile the final source, documentation, runtime, provenance, licensing, release notes, and artifact identities. Do not publish without explicit approval.
