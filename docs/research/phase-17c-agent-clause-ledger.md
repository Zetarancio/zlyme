# Phase 17C agent-clause ledger

Status: preservation ledger for a later reduction, 2026-11-02. This file does not shorten `AGENTS.md`, move a clause, add a skill, or authorize 17C2 implementation.

17C2B, 2026-11-02: no disposition changed. `AGENTS.md` stayed byte-identical to `01fc5db0c0f104589cd0743edaca304aa058c6af`. The discovery record is in [phase-17-plan.md](phase-17-plan.md).

Baseline for every row except AB00: `802904bf913316a26aef42a584377cfeb790dda6`. Line numbers are that file. AB00 is the authorization paragraph added after that baseline. Its line is the worktree file. `AGENTS.md` remains the authoritative source.

A row is one actionable instruction or one independent constraint. A sentence with several independent bans is several rows. A conjunction that is one gate, or a closed list that is one obligation, is one row and names every item. An exception stays on the row it qualifies.

Dispositions are proposals. Nothing here deletes or moves text.

- KEEP: the clause stays directly in `AGENTS.md`.
- ROUTE: not used. A route is recorded only when a current document already contains the same obligation and a task cannot skip it. No candidate met that test.
- DUPLICATE: not used. Repeated rules below do not share both scope and consumers.
- UNCERTAIN: keep the text until a separate decision. One row.

Proof, for KEEP: a later diff still contains the obligation and the exceptions in that row. A keyword in another file is not proof. Proof for UNCERTAIN: the text is still present and no task has reclassified it. Proof for AB00: the worktree paragraph remains, including the authorization list, the allowed ordinary work, and the statement that authorization does not change the physical-SD transfer rule or the release mechanics in `docs/MAINTENANCE.md`.

`Always` means the clause has to be available without an optional skill. `universal` means every task. `trigger` means every task of that kind. Trigger clauses still live in `AGENTS.md` because no loader can select them without failing open.

## Heading coverage

| Heading | Baseline lines | Rows |
| --- | --- | --- |
| Project | 3–30 | P01–P10 |
| Required context | 32–82 | RC01–RC25 |
| Current architecture invariants | 84–101 | INV00–INV14g |
| Superseded designs | 103–115 | SS00–SS09e |
| Device-boundary rule | 117–131 | DB01–DB10 |
| Change policy | 133–164 | CP01–CP39 |
| Buildroot rules | 166–200 | BR01–BR14 |
| Shell | 202–226 | SH01–SH09 |
| C and C++ | 228–252 | CC01–CC10 |
| Runtime | 254–266 | RT01–RT06 |
| Performance | 268–287 | PF01–PF09 |
| Documentation | 289–306 | DC01–DC14 |
| Licensing | 308–330 | LC01–LC06 |
| Validation | 332–352 | VA01–VA07 |
| Hardware payload transfer | 354–356 | HP01–HP06 |
| Source investigation | 358–368 | SI01–SI14 |
| Agent behavior | 370–392, plus AB00 | AB00–AB16 |
| Rule precedence | 394–398 | RP01–RP02 |

The file title on line 1 is not a clause. Blank lines and `##` headings are not clauses. Line 121, "Good boundaries:", is the label for DB02–DB08. Line 135, "Before changing code:", is the trigger for CP02–CP07.

## Project

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | 5 | purpose-built Buildroot | Zlyme is a Buildroot distribution for handheld gaming devices. | universal | none | universal | This sentence | KEEP |
| P02 | 7 | only supported device today | The only supported device is the Miyoo Flip, `my355`, RK3566. | universal | The word today is the time limit, not permission to add a device. | universal | This sentence | KEEP |
| P03 | 9 | do not implement hypothetical devices | The tree may keep a seam for a later device. Do not implement a hypothetical device or an abstraction with no current user. | universal | A seam that adds no device and no unused abstraction. | universal | This sentence | KEEP |
| P04 | 11–13 | primary device reference | The hardware wiki is the primary device reference. | universal | none | universal | The wiki for hardware facts | KEEP |
| P05 | 14 | authoritative for the active OS | This repository is authoritative for the active OS implementation. | universal | none | universal | This repository | KEEP |
| P06 | 15 | archived historical ROCKNIX | `Zetarancio/distribution` is archived evidence. Do not treat it as current state or synchronize it. | universal | none | universal | This sentence | KEEP |
| P07 | 16 | not authorities for Zlyme behavior | ROCKNIX, KNULLI, and other distributions are comparison references, not authorities. | universal | none | universal | This sentence | KEEP |
| P08 | 17 | unless the task explicitly requests | Do not modify the hardware wiki or the archived ROCKNIX fork as part of a Zlyme task. | universal | The task explicitly requests work in that repository. | universal | This sentence | KEEP |
| P09 | 19–28 | Primary goals, in order | When goals conflict, earlier wins: hardware safety and correctness, reproducible builds, latency and frame times, fast boot, minimal footprint, simple implementation, maintainability, then build speed and image size. | universal | none | universal | This list | KEEP |
| P10 | 30 | narrow interfaces over framework-building | Prefer explicit code and narrow interfaces over framework-building. | universal | none | universal | This sentence | KEEP |

P02 and INV02 both name one device. P02 states support. INV02 is a hold-still rule with INV00's exception. They are not duplicates.

## Required context

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RC01 | 34 | Cursor and OpenCode V2 both follow | Cursor and OpenCode V2 follow this file. | universal | none | universal | This sentence | KEEP |
| RC02 | 34 | short summary that defers | `.cursor/rules/zlyme-core.mdc` is a short summary that defers to this file. | universal | none | universal | This sentence. The summary is not the carrier. | KEEP |
| RC03 | 34 | shared workflow | The shared workflow is `docs/DEVELOPMENT.md`. | universal | none | universal | `docs/DEVELOPMENT.md` for the workflow body. The pointer stays here. | KEEP |
| RC04 | 36–38 | Before making code changes | Before code changes, read `docs/ENGINEERING_PRINCIPLES.md`. | code changes | A task that changes no code. | trigger | `docs/ENGINEERING_PRINCIPLES.md` | KEEP |
| RC05 | 40–43 | architectural, boot, device, graphics, audio | Before architectural, boot, device, graphics, audio, storage, packaging, update, or runtime changes, read `docs/ARCHITECTURE.md` and `docs/DEVICE_PORTING.md`. | those change classes | A task outside that list. | trigger | Those two files. The pointer stays here. | KEEP |
| RC06 | 45 | also read `docs/architecture/audio.md` | Audio work also reads `docs/architecture/audio.md`. | audio | none | trigger | `docs/architecture/audio.md` | KEEP |
| RC07 | 45 | authoritative detailed audio contract | That file is the authoritative detailed audio contract. | audio | none | trigger | `docs/architecture/audio.md` | KEEP |
| RC08 | 45 | remains the entry point | `docs/ARCHITECTURE.md` remains the entry point, and `## 9. Audio` links to the detailed contract. | audio | none | trigger | `docs/ARCHITECTURE.md` | KEEP |
| RC09 | 45 | reads already required above still apply | The reads already required above still apply. | audio | none | trigger | RC04, RC05, and any other matching bullet | KEEP |
| RC10 | 47–49 | design/refactoring work | Design or refactoring work also reads `docs/ENGINEERING_PRINCIPLES.md`. | design | none | trigger | `docs/ENGINEERING_PRINCIPLES.md` | KEEP |
| RC11 | 51–54 | build/package/toolchain | Build, package, and toolchain work reads `docs/DEVELOPMENT.md` and `docs/UPSTREAMS.md`. | those tasks | none | trigger | Those two files | KEEP |
| RC12 | 56–58 | NextUI fork, and releases | Maintenance, kernel-patch review, package updates, vendored helpers, the NextUI fork, and releases read `docs/MAINTENANCE.md`. | those tasks | none | trigger | `docs/MAINTENANCE.md` | KEEP |
| RC13 | 60–62 | other prose work | README, user-guide, changelog, release-note, and other prose reads `docs/WRITING.md`. | prose | none | trigger | `docs/WRITING.md` | KEEP |
| RC14 | 64 | owns prose style | `docs/WRITING.md` owns prose style, the README and changelog rules, and how `docs/ROADMAP.md` is written. | prose and roadmap writing | none | universal | `docs/WRITING.md` | KEEP |
| RC15 | 64 | entry point for human contributors | `CONTRIBUTING.md` is the entry point for human contributors. | human contributors | none | universal | `CONTRIBUTING.md` | KEEP |
| RC16 | 64 | operating contract | This file stays the operating contract. | universal | none | universal | `AGENTS.md` | KEEP |
| RC17 | 66–68 | live-device and recovery | Live-device and recovery work reads `docs/OPERATIONS.md`. | those tasks | none | trigger | `docs/OPERATIONS.md` | KEEP |
| RC18 | 70–72 | defect investigation | An AI-assisted defect investigation reads `docs/AUDITING.md`. | investigations | none | trigger | `docs/AUDITING.md` | KEEP |
| RC19 | 74 | separate from the ordinary change review | The audit procedure is separate from the ordinary change review. | universal | none | universal | `docs/AUDITING.md` and CP11 | KEEP |
| RC20 | 74 | not part of every change | A dedicated audit is not part of every change. | universal | AUDITING's own triggers, restated by CP12. | universal | `docs/AUDITING.md` | KEEP |
| RC21 | 76–78 | sequencing project work | Sequencing work reads `docs/ROADMAP.md`. | sequencing | none | trigger | `docs/ROADMAP.md` | KEEP |
| RC22 | 80 | not the current architecture | `docs/ROADMAP.md` is non-normative. It is not the current architecture. | universal | none | universal | `docs/ARCHITECTURE.md` for behavior | KEEP |
| RC23 | 80 | How to write it | How to write the roadmap is in `docs/WRITING.md`. | roadmap edits | none | trigger | `docs/WRITING.md` | KEEP |
| RC24 | 80 | later roadmap phase | Do not implement a later roadmap phase unless the active task asks for it. | universal | The active task asks for that phase. | universal | This sentence | KEEP |
| RC25 | 82 | how changes should be made | Architecture documents state what the system is and why. This file states how changes are made. | universal | none | universal | This sentence | KEEP |

RC04 and RC10 are two triggers for the same file. A design task that changes no code still needs RC10. Not a duplicate.

RC06–RC09 are the four sentences of the 17C1 audio paragraph. All four stay.

## Current architecture invariants

INV00 attaches to every INV row: preserve the invariant unless the task explicitly requires changing it.

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| INV00 | 86 | unless the task explicitly requires | Preserve each invariant unless the task explicitly requires changing that invariant. | universal | An explicit task requirement for that invariant. | universal | This sentence | KEEP |
| INV01 | 88 | Do not modify upstream Buildroot | Buildroot remains a `BR2_EXTERNAL` tree. Do not modify upstream Buildroot. | universal | INV00 | universal | This sentence. `docs/DEVELOPMENT.md` describes the tree. | KEEP |
| INV02 | 89 | only supported target | Miyoo Flip / `my355` is the only supported target. | universal | INV00 | universal | This sentence | KEEP |
| INV03 | 90 | direct DRM/KMS | Normal graphics use direct DRM/KMS. | universal | INV00 | universal | This sentence. The graphics body is still in `docs/ARCHITECTURE.md`. | KEEP |
| INV04 | 91 | permanent desktop | Do not add a permanent desktop environment. | universal | INV00 | universal | This sentence | KEEP |
| INV05 | 92 | just to support one program | Do not add a permanently running X11 or Wayland compositor just to support one program. | universal | INV00. The qualifier is part of the ban. | universal | This sentence | KEEP |
| INV06 | 93 | Weston/WestonPack | Software that cannot use direct KMS may use an application-scoped Weston or WestonPack runtime. | graphics compatibility | Only when direct KMS cannot be used, and only for one application's scope. | universal | This sentence | KEEP |
| INV07 | 94 | BusyBox init | BusyBox init is the normal init system. | universal | INV00 | universal | This sentence. [ADR 0003](../decisions/0003-busybox-init.md) is the decision. | KEEP |
| INV08 | 95 | frontend first frame | Optional services must not delay the frontend first frame. | universal | INV00 | universal | This sentence | KEEP |
| INV09a | 96 | One PipeWire daemon is the mixer | One PipeWire daemon is the mixer on both the product image and the minimal image. | universal | INV00 | universal | Hold-still rule here. Mechanism in `docs/architecture/audio.md`. | KEEP |
| INV09b | 96 | WirePlumber and `pipewire-pulse` | That mixer has WirePlumber and `pipewire-pulse`. | universal | INV00 | universal | Same split as INV09a | KEEP |
| INV09c | 96 | ALSA is the hardware backend | ALSA is the hardware backend. | universal | INV00 | universal | Same split as INV09a | KEEP |
| INV09d | 96 | BlueZ monitor owns A2DP | PipeWire's BlueZ monitor owns A2DP. | universal | INV00 | universal | Same split as INV09a | KEEP |
| INV09e | 96 | `zlyme-audio` chooses the sink | `zlyme-audio` chooses the sink. | universal | INV00 | universal | Same split as INV09a | KEEP |
| INV09f | 96 | omits emulators and NextUI | The minimal image omits emulators and NextUI. | image contents | INV00 | universal | This sentence | KEEP |
| INV09g | 96 | second audio backend | The minimal image does not use a second audio backend. | universal | INV00 | universal | This sentence | KEEP |
| INV10a | 97 | read-only squashfs | The root filesystem is read-only squashfs. | universal | INV00 | universal | This sentence. [ADR 0006](../decisions/0006-root-image-lifecycle.md). | KEEP |
| INV10b | 97 | persistent state belongs under | Persistent state belongs under `/storage`. | universal | INV00 | universal | This sentence | KEEP |
| INV11 | 98 | merely because they exist | Do not add alternate emulator cores merely because they exist. | emulators | INV00. The qualifier is part of the ban. | universal | This sentence | KEEP |
| INV12 | 99 | outrank benchmark results | Hardware safety, thermal protection, and filesystem integrity outrank benchmark results. | universal | INV00 | universal | This sentence | KEEP |
| INV13 | 100 | An unknown license is not that right | Do not redistribute ROMs, BIOS files, keys, commercial software, or vendor binaries without a verified right or a named exception in `docs/UPSTREAMS.md`. An unknown license is not that right. | redistribution | A verified right, or a named exception. See LC04. | universal | This sentence and Licensing | KEEP |
| INV14a | 101 | immutable `NEXTUI_VERSION` | Zlyme `main` pins one immutable `NEXTUI_VERSION` commit reachable from NextUI branch `zlyme`. | NextUI pin | INV00 | universal | This sentence. Procedure in `docs/MAINTENANCE.md`. | KEEP |
| INV14b | 101 | moving branch | Do not point Buildroot at a moving branch. | NextUI pin | INV00 | universal | This sentence | KEEP |
| INV14c | 101 | upgrade NextUI silently | Do not upgrade NextUI silently. | NextUI pin | INV00 | universal | This sentence | KEEP |
| INV14d | 101 | matching NextUI branch temporarily | A development branch may use a matching NextUI branch temporarily. | development branches | The temporary pin is not the `main` pin. INV14e still applies before `main`. | universal | This sentence | KEEP |
| INV14e | 101 | before it is the pin | That commit lands on NextUI `zlyme` before it is the pin on Zlyme `main`. | landing on `main` | none beyond INV00 | universal | This sentence | KEEP |
| INV14f | 101 | separate upstream line | NextUI `main` stays the separate upstream line. | NextUI fork | INV00 | universal | This sentence | KEEP |
| INV14g | 101 | procedure is in `docs/MAINTENANCE.md` | The NextUI pin procedure is in `docs/MAINTENANCE.md`. | NextUI work | none | trigger | `docs/MAINTENANCE.md` `## NextUI fork` | KEEP |

## Superseded designs

SS00 attaches to every SS revival ban.

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SS00 | 105 | Do not revive them | The designs in this section were replaced. Do not revive them. | universal | none | universal | This sentence | KEEP |
| SS01a | 107 | ALSA-only minimal image | Do not revive an ALSA-only minimal image. | audio image | none | universal | This ban. The graph is in `docs/architecture/audio.md`. | KEEP |
| SS01b | 107 | `dmix`/`FlipVolume` | Do not revive the `dmix` / `FlipVolume` default graph. | audio | none | universal | This ban | KEEP |
| SS01c | 107 | Both images use PipeWire | Both images use PipeWire. | both images | none | universal | This sentence and INV09a | KEEP |
| SS01d | 107 | `hw_codec` and `hw_hdmi` | `hw_codec` and `hw_hdmi` remain diagnostic PCMs. | audio | none | universal | This sentence and `docs/architecture/audio.md` | KEEP |
| SS02a | 108 | `rocknix-joypad` | Do not revive `rocknix-joypad` or `rocknix-singleadc-joypad`. | input | none | universal | This ban | KEEP |
| SS02b | 108 | `miyoo-flip-gamepad` | The built-in pad is `miyoo-flip-gamepad`. | input | none | universal | This sentence | KEEP |
| SS02c | 108 | InputPlumber's virtual `xb360` | Applications read InputPlumber's virtual `xb360` pads. | input | none | universal | This sentence | KEEP |
| SS02d | 108 | deletes leftover modules | `board/my355/post-build.sh` deletes leftover modules. | image build | none | universal | This sentence | KEEP |
| SS03a | 109 | mergerfs pool | Do not revive a mergerfs pool of `/storage/Roms`. | storage | none | universal | This ban | KEEP |
| SS03b | 109 | Each card is its own library | Each card is its own library. | storage | none | universal | This sentence | KEEP |
| SS03c | 109 | `/run/zlyme/libraries` | The active libraries are listed in `/run/zlyme/libraries`. | storage | none | universal | This sentence | KEEP |
| SS03d | 109 | mergerfs package is not in the tree | The mergerfs package is not in the tree. | packages | none | universal | This sentence | KEEP |
| SS04a | 110 | Artwork Scraper and Cheat Downloader | Do not revive the Artwork Scraper or the Cheat Downloader. | tools | none | universal | This ban | KEEP |
| SS04b | 110 | ZcrapeGoat replaced both | ZcrapeGoat replaced both tools. | tools | none | universal | This sentence | KEEP |
| SS04c | 110 | removes old card copies | `board/my355/post-update.sh` removes old card copies. | update | none | universal | This sentence | KEEP |
| SS05a | 111 | `PortMaster/themes/Zlyme` | Do not revive a cloned `PortMaster/themes/Zlyme` directory. | PortMaster | none | universal | This ban | KEEP |
| SS05b | 111 | color scheme inside PortMaster | Zlyme is a color scheme inside PortMaster's default theme. | PortMaster | none | universal | This sentence | KEEP |
| SS06a | 112 | `/userdata` paths | Do not revive KNULLI or Batocera `/userdata` paths. | storage | none | universal | This ban | KEEP |
| SS06b | 112 | `.userdata/shared` | Do not revive NextUI `/mnt/SDCARD/.userdata/shared` paths. | storage | none | universal | This ban | KEEP |
| SS06c | 112 | does not exist on the read-only root | `/userdata` does not exist on the read-only root. | storage | none | universal | This sentence | KEEP |
| SS06d | 112 | silently writes onto the OS card | `/mnt/SDCARD` is a symlink to `/storage`. A copied `.userdata` path writes onto the OS card. | storage | none | universal | This sentence | KEEP |
| SS06e | 112 | `/storage/.config/` | Persistent configuration is `/storage/.config/<owner>`. | storage | none | universal | This sentence | KEEP |
| SS06f | 112 | `nextui/my355` | NextUI state is `/storage/.config/nextui/shared` and `/storage/.config/nextui/my355`. | NextUI state | none | universal | This sentence | KEEP |
| SS07a | 113 | permanent compositor | Do not revive a permanent compositor. | graphics | none | universal | This ban. Distinct from INV05, which forbids adding one. | KEEP |
| SS07b | 113 | `zlyme-weston-run` | Weston runs for one application at a time through `zlyme-weston-run`. | graphics | none | universal | This sentence | KEEP |
| SS07c | 113 | WestonPack belongs to PortMaster | WestonPack belongs to PortMaster. | PortMaster | none | universal | This sentence | KEEP |
| SS08a | 114 | Patching `/boot/zlyme` in place | Do not patch `/boot/zlyme` in place. | update | none | universal | This ban | KEEP |
| SS08b | 114 | `/storage/.update/reconstruct` | A delta reconstructs a new root under `/storage/.update/reconstruct`. | update | none | universal | This sentence. Apply behavior is in `docs/ARCHITECTURE.md` and `docs/OPERATIONS.md`. | KEEP |
| SS08c | 114 | `pending/zlyme` | Initramfs copies the verified `pending/zlyme` on reboot. | update | none | universal | This sentence | KEEP |
| SS08d | 114 | `/boot` stays read-only | `/boot` stays read-only at runtime. | boot | none | universal | This sentence | KEEP |
| SS08e | 114 | `zlyme-boot-write` | Writes go through `zlyme-boot-write`. | boot writes | none | universal | This sentence | KEEP |
| SS09a | 115 | `zlyme-maskrom` | Do not revive `zlyme-maskrom`, the boot-FAT request, or the U-Boot consumer that was meant to call `rbrom`. | recovery | none | universal | This ban | KEEP |
| SS09b | 115 | one-entry recovery preloader | MASKROM recovery is the one-entry recovery preloader. | recovery | none | universal | This sentence | KEEP |
| SS09c | 115 | Erasing the preloader is not that path | Erasing the preloader is not the MASKROM recovery path. | recovery | none | universal | This sentence | KEEP |
| SS09d | 115 | `001`–`007` | Production U-Boot patches stay `001` through `007`. | U-Boot | none | universal | This sentence | KEEP |
| SS09e | 115 | not in the stack | The diagnostic boot-delay patch and the MASKROM-request patches are not in the stack. | U-Boot | none | universal | This sentence | KEEP |

## Device-boundary rule

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DB01 | 119 | documented stable interface | Generic Zlyme code must not know Miyoo Flip hardware details unless the detail is part of a documented stable interface. | hardware code | A documented stable interface. | universal | This sentence. `docs/DEVICE_PORTING.md` is the porting document. | KEEP |
| DB02 | 121–123 | `board/my355/` owns | `board/my355/` owns the Flip kernel, U-Boot, DT, image layout, board overlay, and hardware policy. | board code | none | universal | This sentence | KEEP |
| DB03 | 124 | future board gets its own | A future board gets its own `board/<device>/` directory. | tree shape | Not permission to add a device. P03 and AB14 govern that. | universal | This sentence | KEEP |
| DB04 | 125 | not in the global `external.mk` | Board-specific Buildroot hooks belong in that board's make integration, not in global `external.mk`, when they apply only to that board. | board hooks | A hook that is genuinely global. | universal | This sentence | KEEP |
| DB05 | 126 | `zlyme-halt` | Device-specific runtime code may expose stable commands such as `zlyme-audio`, `zlyme-governor`, `zlyme-led`, and `zlyme-halt`. | runtime interfaces | none | universal | This sentence | KEEP |
| DB06 | 127 | not RK817 mixer names | Generic callers depend on the command contract, not RK817 mixer names, GPIO numbers, DRM connector names, or sysfs paths. | callers | none | universal | This sentence | KEEP |
| DB07 | 128 | not a universal constant | NextUI platform selection is a device property, not a universal constant. | NextUI | none | universal | This sentence | KEEP |
| DB08 | 129 | DTB name | The update artifact prefix and the DTB name are device properties, not universal constants. | update and boot | none | universal | This sentence | KEEP |
| DB09 | 131 | solely because a second device | Do not create a generic abstraction solely because a second device might exist someday. | design | none | universal | This sentence | KEEP |
| DB10 | 131 | cleanly describes the current implementation | Extract an interface only when it cleanly describes the current implementation. | design | The two sufficient cases in CP39 are the change-policy form of this gate. | universal | This sentence | KEEP |

DB09, DB10, P03, and AB13–AB15 forbid different acts: an abstraction with no user, compatibility code, a second-device code path, and unused generic machinery. Not duplicates.

## Change policy

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CP01 | 137 | obviously local mistake | A nontrivial bug fix or design choice follows the upstream-first procedure in `docs/UPSTREAMS.md`. | nontrivial fixes and design | A typo, a comment, or an obviously local mistake. | trigger | `docs/UPSTREAMS.md` for the procedure. The gate stays here. | KEEP |
| CP02 | 135–139 | adjacent files | Before changing code, read the relevant implementation and adjacent files. | code changes | none | trigger | This step | KEEP |
| CP03 | 140 | existing helpers | Search for existing helpers and conventions. | code changes | none | trigger | This step | KEEP |
| CP04 | 141 | smallest change | Identify the smallest change that solves the problem. | code changes | none | trigger | This step | KEEP |
| CP05 | 142 | Preserve unrelated behavior | Preserve unrelated behavior. | code changes | none | trigger | This step | KEEP |
| CP06 | 143 | narrowest useful test | Validate with the narrowest useful test. | code changes | none | trigger | This step | KEEP |
| CP07 | 144 | unrelated modifications | Inspect the final diff for unrelated modifications. | code changes | none | trigger | This step | KEEP |
| CP08 | 146 | recorded baseline before finalizing | After a nontrivial implementation change and its tests, an independent review runs against the recorded baseline before finalizing or committing. | nontrivial implementation | CP10 | trigger | This sentence and `docs/AUDITING.md` | KEEP |
| CP09 | 146 | high-risk change | A high-risk change, as named in `docs/AUDITING.md`, requires that review. | high-risk changes | none | trigger | `docs/AUDITING.md` names the class. The requirement stays here. | KEEP |
| CP10 | 146 | Say why it was skipped | A typo, a comment, a documentation-only edit, or a behavior-neutral metadata change may skip the review. Say why. | those edits | The skip is unavailable when the task calls the edit safety-sensitive, and unavailable for CP09. | trigger | This sentence | KEEP |
| CP11 | 148 | not a dedicated audit | That review is not a dedicated audit. | reviews | none | universal | This sentence | KEEP |
| CP12 | 148 | own trigger conditions | `docs/AUDITING.md` applies only when its own trigger conditions are met. | investigations | none | universal | `docs/AUDITING.md` | KEEP |
| CP13 | 150 | one named diff | The review is one named diff. | reviews | none | universal | This sentence | KEEP |
| CP14 | 150 | `.cursor/agents/zlyme-code-reviewer.md` | Cursor's reviewer is `.cursor/agents/zlyme-code-reviewer.md`. | Cursor reviews | none | universal | That adapter | KEEP |
| CP15 | 150 | `.opencode/agents/zlyme-code-reviewer.md` | OpenCode V2's reviewer is `.opencode/agents/zlyme-code-reviewer.md`. | OpenCode reviews | none | universal | That adapter | KEEP |
| CP16 | 150 | Both follow this file | Both adapters follow this file and `docs/AUDITING.md`. | reviews | none | universal | This sentence | KEEP |
| CP17 | 152 | fresh reviewer context | Use a fresh reviewer context. | reviews | none | universal | This sentence | KEEP |
| CP18 | 152 | review scope | Pass the baseline SHA, the current worktree state, and the review scope. | reviews | none | universal | This sentence | KEEP |
| CP19 | 152 | previous reviewer's verdict | Do not pass findings, rationale, a suggested fix, or a previous reviewer's verdict. | reviews | none | universal | This sentence | KEEP |
| CP20 | 152 | already contains the conclusion | A fresh context is not independent when the prompt already contains the conclusion. | reviews | none | universal | This sentence | KEEP |
| CP21 | 152 | not a second model | A fresh context that uses the same model is a separate context. It is not a second model. | reviews | none | universal | This sentence | KEEP |
| CP22 | 152 | not actually invoked | Report whether the reviewer ran. Unavailable, blocked, or not invoked is not an independent review. | reviews | none | universal | This sentence | KEEP |
| CP23 | 154 | Verify an actionable finding | Verify an actionable finding against the source. | reviews | none | universal | This sentence | KEEP |
| CP24 | 154 | defect the task authorizes | Correct only a defect the task authorizes. | reviews | none | universal | This sentence | KEEP |
| CP25 | 154 | Rerun the affected checks | Rerun the affected checks after a correction. | reviews | none | universal | This sentence | KEEP |
| CP26 | 154 | one follow-up | The cadence is one comprehensive post-change review and one follow-up after a substantive correction. | reviews | none | universal | `docs/AUDITING.md` states the cadence. The requirement stays here. | KEEP |
| CP27 | 154 | not waived silently | A serious confirmed finding is not waived silently. | reviews | none | universal | This sentence | KEEP |
| CP28 | 154 | recorded limitation | Deferral follows `docs/AUDITING.md`: an explicit decision and a recorded limitation. | reviews | none | universal | `docs/AUDITING.md` | KEEP |
| CP29 | 156 | drive-by refactors | Do not perform drive-by refactors. | code changes | none | universal | This sentence | KEEP |
| CP30 | 158 | modernize unrelated code | Do not rename, reformat, reorganize, or modernize unrelated code while implementing another feature. | code changes | none | universal | This sentence | KEEP |
| CP31 | 160 | one conceptual reason per commit | One conceptual reason per commit. | commits | none | universal | This sentence | KEEP |
| CP32 | 160 | may contain several commits | One session may contain several commits. | commits | This permits several commits. It does not permit mixing reasons. | universal | This sentence | KEEP |
| CP33 | 160 | tests with the code | Keep the tests with the code they verify. | commits | none | universal | This sentence | KEEP |
| CP34 | 160 | documentation of that change | Keep the documentation of that change with it. | commits | none | universal | This sentence | KEEP |
| CP35 | 160 | unrelated subsystems | Do not combine unrelated subsystems because they were handled in the same session. | commits | none | universal | This sentence | KEEP |
| CP36 | 160 | every trivial edit | Do not make a separate commit for every trivial edit. | commits | none | universal | This sentence | KEEP |
| CP37 | 160 | Before each commit | Before each commit, review the changed paths, the conceptual scope, accidental unrelated changes, and the tests and documentation that belong with that change. | commits | none | universal | This sentence | KEEP |
| CP38 | 160 | Phase 13 and Phase 14 | The commit rule applies to every change, including Phase 13 and Phase 14. | commits | none | universal | This sentence | KEEP |
| CP39 | 162–164 | duplication/error | Do not introduce an abstraction unless it removes a current source of duplication or error, or it defines a stable device boundary the current Flip implementation already requires. | design | Either of those two conditions. | universal | This sentence | KEEP |

The named features in the commit paragraph are examples of separate commits, not instructions to implement those features. CP31 carries that paragraph.

## Buildroot rules

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BR01 | 168 | packages self-contained | Keep packages self-contained. | packages | none | trigger | This sentence | KEEP |
| BR02 | 170 | whenever practical | Package-specific workarounds belong with that package whenever practical. | packages | The qualifier whenever practical. It is not a license to put a workaround in a global file by default. | trigger | This sentence | KEEP |
| BR03 | 172–175 | package discovery | Global `external.mk` is only for package discovery, genuinely global Buildroot integration, and board dispatch. | Buildroot integration | Those three uses. | trigger | This sentence | KEEP |
| BR04 | 177 | Linux/U-Boot hooks | Board-only Linux and U-Boot hooks live with the board. | kernel and U-Boot | none | trigger | This sentence. DB04 is the broader hook rule. | KEEP |
| BR05 | 179–181 | explicit version | A downloaded package provides an explicit version where applicable. | downloaded packages | Where applicable. | trigger | This sentence | KEEP |
| BR06 | 182 | immutable reference where practical | A downloaded package provides an immutable reference where practical. | downloaded packages | Where practical, and where applicable. | trigger | This sentence | KEEP |
| BR07 | 183 | dependencies | A downloaded package provides its dependencies where applicable. | downloaded packages | Where applicable. | trigger | This sentence | KEEP |
| BR08 | 184 | license identifier | A downloaded package provides a license identifier where applicable. | downloaded packages | Where applicable. | trigger | This sentence | KEEP |
| BR09 | 185 | license file | A downloaded package provides license files where applicable. | downloaded packages | Where applicable. | trigger | This sentence | KEEP |
| BR10 | 186 | hashes | A downloaded package provides hashes where applicable. | downloaded packages | Where applicable. | trigger | This sentence | KEEP |
| BR11 | 188 | documented reason | Do not track a moving branch for a reproducible package unless there is a documented reason. | packages | A documented reason. | trigger | This sentence | KEEP |
| BR12 | 190–196 | target CFLAGS/CPPFLAGS/LDFLAGS | Use the Buildroot target toolchain: `TARGET_CC`, `TARGET_CXX`, `TARGET_AR`, `TARGET_STRIP`, and the target CFLAGS, CPPFLAGS, and LDFLAGS. | target builds | none | trigger | This sentence | KEEP |
| BR13 | 198 | host compiler | Never accidentally build target software with the host compiler. | target builds | none | trigger | This sentence | KEEP |
| BR14 | 200 | Buildroot can manage them | Do not fetch dependencies from package build or install commands when Buildroot can manage them. | packages | When Buildroot cannot manage that dependency. | trigger | This sentence | KEEP |

`docs/DEVELOPMENT.md` was checked for these sentences. It does not carry BR13 or the metadata list. These rows stay here.

## Shell

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SH01 | 204 | unless Bash is genuinely required | Target scripts use POSIX `sh` unless Bash is genuinely required. | target scripts | Bash is genuinely required. | trigger | This sentence | KEEP |
| SH02 | 206–212 | unless documented otherwise | Host Bash scripts use `set -euo pipefail` unless documented otherwise. | host Bash | Documented otherwise. | trigger | This sentence | KEEP |
| SH03 | 214 | Quote path and variable expansions | Quote path and variable expansions. | shell | none | trigger | This sentence | KEEP |
| SH04 | 216 | Avoid `eval` | Avoid `eval`. | shell | none | trigger | This sentence | KEEP |
| SH05 | 218 | `mktemp` and `trap` | Use `mktemp` and `trap` for temporary resources. | shell | none | trigger | This sentence | KEEP |
| SH06 | 220 | idempotent scripts | Prefer idempotent scripts. | shell | none | trigger | This sentence | KEEP |
| SH07 | 222 | observable condition | Do not use an arbitrary `sleep` for readiness when an observable condition exists. | shell | No observable condition exists. | trigger | This sentence | KEEP |
| SH08 | 224 | Background only independent work | Background only independent work. | shell | none | trigger | This sentence. SI11 says what independent means. | KEEP |
| SH09 | 226 | destructive destinations | Validate destructive destinations before filesystem or block-device writes. | shell writes | none | trigger | This sentence. AB00 still governs Flip and boot-media operations. | KEEP |

`docs/DEVELOPMENT.md` `## Shell` repeats some of SH01–SH04 and SH07–SH08 in weaker wording and adds a ban on silently ignoring critical failures. It does not contain SH05, SH06, or SH09. It is not loaded for every shell edit. Not a duplicate and not a safe route.

## C and C++

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CC01 | 230 | small and single-purpose | Keep hardware daemons small and single-purpose. | C and C++ daemons | none | trigger | This sentence | KEEP |
| CC02 | 232 | device initialization | Check return values from syscalls, ioctl, ALSA, allocation, file operations, and device initialization. | C and C++ | none | trigger | This sentence | KEEP |
| CC03 | 234–239 | permanent failure | Do not conflate device absent, a valid negative state, a transient error, and a permanent failure. | C and C++ | none | trigger | This sentence | KEEP |
| CC04 | 241–242 | not card numbers | Use ALSA card IDs, not card numbers. | C and C++ audio | none | trigger | This sentence | KEEP |
| CC05 | 243 | `/dev/input/eventN` | Use capabilities or names, not `/dev/input/eventN`. | C and C++ input | none | trigger | This sentence | KEEP |
| CC06 | 244 | not probe order | Use persistent identifiers, not probe order. | C and C++ | none | trigger | This sentence | KEEP |
| CC07 | 246 | event-driven behavior over polling | Prefer event-driven behavior over polling. | C and C++ | none | trigger | This sentence | KEEP |
| CC08 | 248 | ownership and cleanup obvious | Keep ownership and cleanup obvious. | C and C++ | none | trigger | This sentence | KEEP |
| CC09 | 250 | makes cleanup more correct | `goto cleanup` is acceptable in C when it makes cleanup more correct. | C | Only when cleanup is more correct. | trigger | This sentence | KEEP |
| CC10 | 252 | where practical | Project-owned C and C++ should compile cleanly with at least `-Wall -Wextra` where practical. | project C and C++ | Where practical. | trigger | This sentence | KEEP |

## Runtime

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RT01 | 256 | mandatory hardware from optional | Distinguish mandatory hardware from optional features. | runtime | none | trigger | This sentence | KEEP |
| RT02 | 258 | must be diagnosable | Required storage, display, and input failures must be diagnosable. | runtime | none | universal | This sentence | KEEP |
| RT03 | 260 | when possible | Missing Wi-Fi, Bluetooth, headphones, HDMI, or USB should degrade gracefully when possible. | those optional devices | When graceful degradation is not possible. This list does not include storage, display, or input. | universal | This sentence | KEEP |
| RT04 | 262 | frontend first frame | Networking must not be required for the frontend first frame. | boot and network | none | universal | This sentence | KEEP |
| RT05 | 264 | clear reason to exist | A persistent daemon needs a clear reason to exist. | services | none | trigger | This sentence | KEEP |
| RT06 | 266 | pointless wakeups | Avoid pointless wakeups, polling, writes, and logs. | runtime | none | trigger | This sentence | KEEP |

## Performance

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PF01 | 270 | Measure it | Do not assume an optimization helps. Measure it. | performance changes | none | trigger | This sentence | KEEP |
| PF02 | 272–281 | where measurable | For runtime and emulator changes, prefer frame-time consistency, p95 and p99 frame time, audio underruns, input latency where measurable, CPU and GPU utilization, required clocks, temperature and throttling, and power consumption. | runtime and emulators | none | trigger | This list. There is no second performance policy. | KEEP |
| PF03 | 283 | Average FPS alone | Average FPS alone is insufficient. | performance claims | none | trigger | This sentence | KEEP |
| PF04 | 285 | compiler optimization policy | Do not silently change compiler optimization policy. | builds | An explicit task to change it. | universal | This sentence | KEEP |
| PF05 | 285 | governor policy | Do not silently change governor policy. | runtime | An explicit task to change it. | universal | This sentence | KEEP |
| PF06 | 285 | affinity | Do not silently change affinity. | runtime | An explicit task to change it. | universal | This sentence | KEEP |
| PF07 | 285 | voltage | Do not silently change voltage. | hardware | An explicit task to change it. | universal | This sentence | KEEP |
| PF08 | 285 | overclocking | Do not silently change overclocking. | hardware | An explicit task to change it. | universal | This sentence | KEEP |
| PF09 | 287 | specifically to revisit them | Preserve the repository's intentional performance choices unless the task is specifically to revisit them. | performance | The task specifically revisits that choice. | universal | This sentence | KEEP |

## Documentation

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DC01 | 291 | compatibility requirements | Comments explain why, hardware quirks, upstream limitations, safety constraints, and compatibility requirements. | comments | none | trigger | This sentence | KEEP |
| DC02 | 293 | merely restate code | Do not write comments that merely restate code. | comments | none | trigger | This sentence | KEEP |
| DC03 | 295 | proven obsolete | Do not remove a workaround until its original reason has been understood and proven obsolete. | workarounds | Both conditions: understood, and proven obsolete. | universal | This sentence | KEEP |
| DC04 | 297–298 | architecture | Update documentation when architecture changes. | architecture changes | none | trigger | This sentence. `docs/WRITING.md` owns the prose check. | KEEP |
| DC05 | 299 | build commands | Update documentation when build commands change. | build changes | none | trigger | This sentence | KEEP |
| DC06 | 300 | device contract | Update documentation when the device contract changes. | device contract | none | trigger | This sentence | KEEP |
| DC07 | 301 | storage/update format | Update documentation when the storage or update format changes. | storage and update | none | trigger | This sentence | KEEP |
| DC08 | 302 | runtime interfaces | Update documentation when runtime interfaces change. | runtime | none | trigger | This sentence | KEEP |
| DC09 | 303 | package layout | Update documentation when package layout changes. | packages | none | trigger | This sentence | KEEP |
| DC10 | 304 | user-visible behavior | Update documentation when user-visible behavior changes. | user-visible changes | none | trigger | This sentence | KEEP |
| DC11 | 306 | match the final source | A phase is not closed until the documents that own the changed behavior match the final source. | phase closure | none | universal | `docs/WRITING.md` describes the check. The gate stays here. | KEEP |
| DC12 | 306 | not a second pass | That check is not a second pass over every sentence after every commit. | documentation | none | universal | This qualifier | KEEP |
| DC13 | 306 | Open validation debt index | The Open validation debt index in `docs/MAINTENANCE.md` moves when a finding is fixed, accepted, superseded, or deferred. | findings | none | universal | `docs/MAINTENANCE.md` holds the index. The duty stays here. | KEEP |
| DC14 | 306 | That check is in `docs/WRITING.md` | The phase-close documentation check is the one in `docs/WRITING.md`. | phase closure | none | trigger | `docs/WRITING.md` | KEEP |

## Licensing

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LC01 | 310 | licensing understood | Every package and shipped PAK must have its licensing understood. | packages and PAKs | none | universal | This sentence | KEEP |
| LC02 | 312 | redistribution permission | Do not assume source availability means redistribution permission. | redistribution | none | universal | This sentence | KEEP |
| LC03 | 314 | copyright or license notices | Do not remove copyright or license notices. | redistribution and edits | none | universal | This sentence | KEEP |
| LC04 | 316–326 | every one of these is true | A third-party or vendor binary with no usable license text may be redistributed only when every listed condition is true: the maintainer chose that artifact, the bytes or build are identified, origin and provenance are documented, SHA-256 is recorded where practical, modified or unmodified is explicit, the purpose is documented, the metadata uses a `LicenseRef-...-unspecified` identifier rather than a known license, the provenance record says it is not a license grant and that rights are unverified, and the exception names that artifact rather than arbitrary files. | unlicensed binaries | All of those conditions. One missing condition forbids shipping. | universal | This test. `docs/UPSTREAMS.md` records the two current exceptions. It is not loaded for every task. | KEEP |
| LC05 | 328 | not a legal conclusion | Do not ship a file with no meaningful provenance. The accepted-exception wording is fixed by this sentence. That wording is a distribution decision, not a legal conclusion. | unlicensed files | none | universal | This sentence | KEEP |
| LC06 | 330 | neither exception covers any other file | The current exceptions are only `package/system/zlyme-preloader/preloader-stock.img` and the 41 files named for `package/system/portmaster-rocknix-compat`. The preloader script and checker stay MIT. Neither record is a license grant, and neither covers any other file. | redistribution | none | universal | This sentence and `docs/UPSTREAMS.md` | KEEP |

## Validation

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| VA01 | 334 | narrowest applicable checks | Run the narrowest applicable checks first. | every change | none | universal | This sentence | KEEP |
| VA02 | 336–342 | Examples | The named examples are Buildroot external-tree checks, ShellCheck, a warning-enabled compile, building the affected package before a full image when practical, confirming generated kernel and U-Boot configuration after Kconfig changes, and distinguishing build validation from real-device validation. | validation | The source introduces them as examples. They are not a closed list, and they are not optional to forget. | universal | This list | UNCERTAIN |
| VA03 | 344 | performed on the Miyoo Flip | Never claim hardware testing unless it was performed on the Miyoo Flip. | claims | none | universal | This sentence | KEEP |
| VA04 | 346 | cannot be run, say so | If a validation step cannot be run, say so. | claims | none | universal | This sentence | KEEP |
| VA05 | 348 | Never fabricate results | Never fabricate results. | claims | none | universal | This sentence | KEEP |
| VA06 | 350 | does not by itself accept | A defect investigation follows `docs/AUDITING.md`. The post-change reviewer is the change-policy step. Compiling, running a test, or explaining a path does not by itself accept behavior on the Flip. | investigations and claims | none | universal | `docs/AUDITING.md` and Change policy | KEEP |
| VA07 | 352 | current paths | Diagnostic logging follows `docs/decisions/0012-diagnostic-logging.md`. `docs/ARCHITECTURE.md` keeps the current paths. | logging | none | trigger | Those two files. The pointer stays here. | KEEP |

VA03 and the host-versus-Flip sentences in SI08 are different moments: one governs a claim, the other governs an investigation. Not duplicates.

## Hardware payload transfer

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HP01 | 356 | Wi-Fi, SSH, SCP, or rsync | Do not transfer OTAs, images, runtime archives, libraries, emulator binaries, large logs, or other bulk payloads to or from the Flip over Wi-Fi, SSH, SCP, or rsync. | any transfer | none | universal | This sentence | KEEP |
| HP02 | 356 | physical SD card | Use a physical SD card mounted on the development host for those payloads. | any transfer | none | universal | This sentence | KEEP |
| HP03 | 356 | small text diagnostics | SSH over Wi-Fi is for commands, inspection, and small text diagnostics. | SSH | Not a bulk payload. | universal | This sentence | KEEP |
| HP04 | 356 | which card and path | If the required card is not mounted, stop and say which card and path are needed. | transfers | none | universal | This sentence | KEEP |
| HP05 | 356 | Do not fall back to a network copy | Do not fall back to a network copy. | transfers | none | universal | This sentence | KEEP |
| HP06 | 356 | when a person uses it | This ban does not stop PortMaster from downloading its own catalogue or runtimes when a person uses it. | PortMaster on the device | A person using PortMaster. It is not an agent copy path. | universal | This exception, attached to HP01 | KEEP |

AB00 does not relax HP01–HP05. Authorizing a build or a release does not authorize a network copy.

## Source investigation

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SI01 | 360 | branch, and HEAD | Confirm the repository root, branch, and HEAD before substantive work. | substantive work | none | universal | This sentence | KEEP |
| SI02 | 360 | instructions in Required context | Read the Required context instructions that apply to the task. | substantive work | none | universal | Required context | KEEP |
| SI03 | 362 | path the source already established | Reuse a path the source already established. | investigation | none | universal | This sentence | KEEP |
| SI04 | 362 | `git ls-files` | Prefer `git grep` and `git ls-files` for tracked files, and keep each search inside the relevant path. | investigation | none | universal | This sentence | KEEP |
| SI05 | 362 | task-specific reason | Do not search the filesystem root or a generated output tree without a task-specific reason. | investigation | A task-specific reason. | universal | This sentence | KEEP |
| SI06 | 362 | line already in hand | Read a line range of a large file. Do not dump the whole file again to recover a line already in hand. | investigation | none | universal | This sentence | KEEP |
| SI07 | 364 | Do not invent a tool name | Use the search the environment actually provides. Do not invent a tool name. | investigation | none | universal | This sentence | KEEP |
| SI08 | 366 | different claims | Inspected source, an executed test, host validation, and hardware acceptance are different claims. | claims | none | universal | This sentence | KEEP |
| SI09 | 366 | did not pass | A test that was only read did not pass. | claims | none | universal | This sentence | KEEP |
| SI10 | 366 | acquires and releases | Trace a lock to the resource it covers and the owner that acquires and releases it. | concurrency | none | trigger | This sentence | KEEP |
| SI11 | 366 | does not need its result | A background command is independent only when later work does not need its result. | investigation | Later work needs the result, so it is not independent. | universal | This sentence | KEEP |
| SI12 | 366 | reachable path and an observation | A plausible execution story is a hypothesis until a reachable path and an observation support it. | claims | none | universal | This sentence | KEEP |
| SI13 | 368 | evidence is missing | Stop when the bounded task has its evidence, or when further calls will not produce it. Say which evidence is missing. | investigation | This stop does not cancel SI02 or any other named read. | universal | This sentence | KEEP |
| SI14 | 368 | standard for a defect investigation | `docs/AUDITING.md` remains the standard for a defect investigation. | investigations | none | trigger | `docs/AUDITING.md` | KEEP |

## Agent behavior

AB00 is not in the baseline. Worktree line 372.

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AB00 | worktree 372 | Explicit maintainer authorization is required | Explicit maintainer authorization is required before an agent builds or installs a firmware image or OTA, dispatches a remote firmware build, publishes a release, flashes or changes boot media, performs a destructive or potentially destructive Flip operation, or modifies persistent device state outside an explicitly authorized test. | those operations | Source inspection, host validation, and explicitly requested non-destructive development work need no extra authorization. An authorized operation stays allowed. Authorization does not change HP01–HP05 or the release mechanics in `docs/MAINTENANCE.md`. | universal | This paragraph. `docs/MAINTENANCE.md` `## Releases` and `### Integrating a phase onto main` own release mechanics. `docs/OPERATIONS.md` owns the device procedures. | KEEP |
| AB01 | 372 | source can answer it | Do not guess repository behavior when source can answer it. | universal | none | universal | This sentence | KEEP |
| AB02 | 374 | Search before adding | Search before adding a new implementation. | new code | none | universal | This sentence | KEEP |
| AB03 | 376 | silently upgrade dependencies | Do not silently upgrade dependencies. | dependencies | none | universal | This sentence | KEEP |
| AB04 | 378 | kernel | Do not silently change the kernel architecture. | kernel | The task explicitly changes it. | universal | This sentence | KEEP |
| AB05 | 378 | bootloader | Do not silently change the bootloader architecture. | boot | The task explicitly changes it. | universal | This sentence | KEEP |
| AB06 | 378 | init | Do not silently change the init architecture. | init | The task explicitly changes it. | universal | This sentence | KEEP |
| AB07 | 378 | graphics | Do not silently change the graphics architecture. | graphics | The task explicitly changes it. | universal | This sentence | KEEP |
| AB08 | 378 | audio | Do not silently change the audio architecture. | audio | The task explicitly changes it. | universal | This sentence | KEEP |
| AB09 | 378 | update | Do not silently change the update architecture. | update | The task explicitly changes it. | universal | This sentence | KEEP |
| AB10 | 378 | storage | Do not silently change the storage architecture. | storage | The task explicitly changes it. | universal | This sentence | KEEP |
| AB11 | 378 | package architecture | Do not silently change the package architecture. | packages | The task explicitly changes it. | universal | This sentence | KEEP |
| AB12 | 380 | demonstrated requirement | Do not replace a small implementation with a framework without a demonstrated requirement. | design | A demonstrated requirement. | universal | This sentence | KEEP |
| AB13 | 382 | hypothetical future hardware | Do not add compatibility code for hypothetical future hardware. | hardware | none | universal | This sentence | KEEP |
| AB14 | 384 | until a second device actually exists | Do not add a second-device code path until a second device actually exists. | devices | A second device exists. | universal | This sentence | KEEP |
| AB15 | 386 | unused generic machinery | When preparing for future devices, isolate current Flip assumptions behind explicit board or runtime contracts instead of adding unused generic machinery. | future-device preparation | none | universal | This sentence | KEEP |
| AB16 | 388–392 | Miyoo Flip hardware testing | The completion report says what changed, why, the validation actually performed, and anything that still needs Miyoo Flip hardware testing. | every completion | none | universal | This list | KEEP |

AB01–AB16 use baseline line numbers. In the worktree they are two lines later because AB00 was inserted above them.

## Rule precedence

| ID | Lines | Excerpt | Obligation | Scope | Exceptions | Always | Owner | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RP01 | 396 | Zlyme-specific constraint wins | If a general engineering principle conflicts with a documented Zlyme architecture or hardware-safety constraint, the Zlyme constraint wins. | conflicts | none | universal | This sentence. Required context does not state it. | KEEP |
| RP02 | 398 | unless the maintainer explicitly asks | Use `docs/ROADMAP.md` to sequence major migrations. Do not execute multiple roadmap phases in one task unless the maintainer explicitly asks. | multi-phase work | The maintainer explicitly asks for more than one phase. | universal | This sentence | KEEP |

RC24 forbids starting a later phase the task did not ask for. RP02 forbids running more than one phase in one task unless the maintainer asks. Both stay.

## High-risk index

| Topic | Rows |
| --- | --- |
| Miyoo Flip only | P02, INV02 |
| Wiki and source order | P04, P05, P06, P07, P08 |
| `BR2_EXTERNAL` | INV01 |
| Read-only root and `/storage` | INV10a, INV10b, SS06c, SS06d, SS06e |
| Boot and persistent data | SS08a–SS08e, SS09a–SS09e, SH09, AB05 |
| OTA and release authorization | AB00, RC12, HP01 |
| Dangerous device operations | AB00, SH09 |
| No bulk firmware transfer | HP01–HP06 |
| Licensing and the two exceptions | INV13, LC01–LC06 |
| NextUI pin | INV14a–INV14g, DB07 |
| Direct KMS and temporary Weston | INV03, INV04, INV05, INV06, SS07a–SS07c |
| PipeWire and InputPlumber | INV09a–INV09g, SS01a–SS01d, SS02b, SS02c, RC06–RC09 |
| Device boundary and hypothetical devices | DB01–DB10, P03, AB13, AB14, AB15 |
| Reviewer, fresh context, cadence | CP08–CP28 |
| Audit versus ordinary review | RC19, RC20, CP11, CP12 |
| Evidence versus executed tests | VA03, VA05, VA06, SI08, SI09, SI12 |
| Host validation versus Flip acceptance | VA02, VA03, VA06, SI08, AB16 |
| Upstream-first | CP01 |
| Source-inspection limits | SI01–SI14 |
| Rule precedence and one phase | RP01, RP02, RC24 |
| Audio route | RC06, RC07, RC08, RC09 |

## Routes checked against the 17C1 map

The map in [phase-17c-agent-instruction-map.md](phase-17c-agent-instruction-map.md) is a proposal. This ledger does not adopt its routes. No row is ROUTE.

| Map proposal | Ledger result |
| --- | --- |
| Shell, C, and Buildroot text could load when those files change. | Unsafe. The obligations are SH, CC, and BR. `docs/DEVELOPMENT.md` `## Shell` is a partial overlap and is not required for every shell edit. No document contains the C rules or BR13. There is no loader. Removing them from `AGENTS.md` fails open. |
| Performance metrics could leave the always-loaded file. | Unsafe. PF02 and PF03 have no second owner. PF04–PF09 are universal bans. |
| License artifact names could be read from `docs/UPSTREAMS.md`. | Unsafe for a sole copy. LC04 and LC06 have to be visible on a task that does not match RC11 or RC12. `docs/UPSTREAMS.md` is the record, not the agent gate. |
| Audio detail loads from `docs/architecture/audio.md`. | The detailed contract is already there. RC06–RC09 stay. INV09 and SS01 stay. A mixer change still opens `docs/ARCHITECTURE.md`. |
| Graphics could follow the audio pattern. | No graphics document exists. INV03–INV06 and SS07 stay, and graphics work still reads the whole architecture document. |
| Boot, storage, update, and recovery could use selected headings. | Unsafe. SS08, SS09, INV07, INV08, INV10, and AB00 stay universal. The map's own boot row already requires the whole architecture and operations documents. That category must not depend on a skill. |
| Release work had no publication ban in `AGENTS.md`. | True at the 17C1 baseline. AB00 is that ban. `docs/MAINTENANCE.md` still owns how a release is built. The map's release cell is updated in this same documentation change so it does not deny AB00. |
| `.cursor/rules/zlyme-core.mdc` is a sufficient index. | Unsafe. RC02 says it defers. It does not name `docs/architecture/audio.md` or AB00. An agent that treats the short list as complete skips both. This task does not edit that rule. |
| Mixed scope, or an unclear scope. | Load the union of the matching categories, and load the whole architecture and operations documents when boot, storage, update, recovery, firmware, or device safety might be involved. Unclear scope stays on the full `AGENTS.md` text. There is no new routing mechanism. |

## Uncertain dispositions

| ID | Why it is uncertain | What stays |
| --- | --- | --- |
| VA02 | The source calls the list examples, so it is not a closed required set. It is also the only list of those checks in `AGENTS.md`. | The six examples stay until a separate decision says which are mandatory. |

No other row is UNCERTAIN. No row is ROUTE. No row is DUPLICATE.

## Counts

263 clauses. 262 are KEEP, including AB00. 0 are ROUTE. 0 are DUPLICATE. 1 is UNCERTAIN: VA02. The baseline file accounts for 262 of those clauses. AB00 is the addition.

## What this ledger does not do

It does not prove that Cursor or OpenCode load a file. It does not shorten `AGENTS.md`. It does not edit `docs/decisions/0007-pipewire-audio.md`. That decision still calls `docs/ARCHITECTURE.md` the running contract. Section 9 of that file still links to `docs/architecture/audio.md`. It does not start 17D or Phase 18.
