# Historical research dump (2026-09-10), before the curated ship list
# existed. The ship list that was current then is docs/archive/PLAN.md
# section 11. Do not treat this file as what the image builds.

Yes. After checking the current ROCKNIX, KNULLI, ArkOS and SpruceOS configurations, I would revise the earlier recommendation slightly.

The guiding principle should be: **ship one curated default per system whenever possible; install alternatives only where the RK3566 ecosystem provides evidence that they materially improve compatibility or performance.** The main exception is N64. Arcade deserves two cores because the ROM-set ecosystems are genuinely different.

ROCKNIX currently favors modern/general-purpose cores such as mGBA, Snes9x and Mupen64Plus-Next, while SpruceOS makes more RK3566/low-power-oriented choices such as gpSP, Supafaust and LudicrousN64. Spruce also deliberately supports both 64-bit and 32-bit RetroArch on the Miyoo Flip; ROCKNIX similarly defaults to 32-bit PCSX-ReARMed for PS1. ([GitHub][1])

## Updated RK3566 emulator/core set

| System                   | What I would integrate                                          | Default                                       | Why                                                                                                                                                                                                                                                 |
| ------------------------ | --------------------------------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NES / Famicom / FDS**  | `nestopia_libretro`                                             | **Nestopia**                                  | Excellent compatibility and low enough CPU cost for RK3566. ROCKNIX also defaults to Nestopia.                                                                                                                                                      |
| **GB / GBC**             | `gambatte_libretro`                                             | **Gambatte**                                  | Fast, mature, accurate enough, excellent handheld fit.                                                                                                                                                                                              |
| **GBA**                  | `mgba_libretro`, `gpsp_libretro` during testing                 | **Undecided: benchmark mGBA vs gpSP**         | ROCKNIX chooses mGBA; Spruce chooses gpSP. On RK3566, mGBA gives better accuracy while gpSP can reduce CPU load. This deserves an actual Flip benchmark before removing one. ROCKNIX currently uses mGBA; Spruce currently uses gpSP. ([GitHub][1]) |
| **SNES / Super Famicom** | `snes9x_libretro`, `mednafen_supafaust_libretro` during testing | **Undecided: benchmark Supafaust vs Snes9x**  | ROCKNIX uses Snes9x; Spruce selects Supafaust specifically on the Miyoo Flip/device group. I would not ship old Snes9x 2002/2005/2010 variants unless a real incompatibility appears. ([GitHub][1])                                                 |
| **Virtual Boy**          | `beetle_vb_libretro`                                            | **Beetle VB**                                 | Straightforward choice.                                                                                                                                                                                                                             |
| **Pokémon Mini**         | `pokemini_libretro`                                             | **PokéMini**                                  | Straightforward choice.                                                                                                                                                                                                                             |
| **Master System**        | `genesis_plus_gx_libretro`                                      | **Genesis Plus GX**                           | Excellent Sega 8/16-bit core and no need for duplication.                                                                                                                                                                                           |
| **Game Gear**            | `genesis_plus_gx_libretro`                                      | **Genesis Plus GX**                           | I would standardize Sega 8-bit on GPGX even though ROCKNIX currently prefers Gearsystem for GG/SMS.                                                                                                                                                 |
| **SG-1000**              | `genesis_plus_gx_libretro`                                      | **Genesis Plus GX**                           | Same reason.                                                                                                                                                                                                                                        |
| **Mega Drive / Genesis** | `genesis_plus_gx_libretro`                                      | **Genesis Plus GX**                           | Clear default.                                                                                                                                                                                                                                      |
| **Sega CD / Mega CD**    | `genesis_plus_gx_libretro`                                      | **Genesis Plus GX**                           | Clear default.                                                                                                                                                                                                                                      |
| **32X**                  | `picodrive_libretro`                                            | **PicoDrive**                                 | The obvious lightweight 32X option.                                                                                                                                                                                                                 |
| **PC Engine / TG16**     | `beetle_pce_fast_libretro`                                      | **Beetle PCE Fast**                           | Excellent fit for RK3566.                                                                                                                                                                                                                           |
| **PC Engine CD**         | `beetle_pce_fast_libretro`                                      | **Beetle PCE Fast**                           | Same core.                                                                                                                                                                                                                                          |
| **SuperGrafx**           | `beetle_supergrafx_libretro`                                    | **Beetle SuperGrafx**                         | Specialized and mature.                                                                                                                                                                                                                             |
| **Neo Geo AES/MVS**      | `fbneo_libretro`                                                | **FBNeo**                                     | Better choice than carrying old FBA generations.                                                                                                                                                                                                    |
| **Neo Geo CD**           | `neocd_libretro`                                                | **NeoCD**                                     | Small, focused solution.                                                                                                                                                                                                                            |
| **NGP / NGPC**           | `beetle_ngp_libretro`                                           | **Beetle NGP**                                | No real reason for several cores.                                                                                                                                                                                                                   |
| **WonderSwan**           | `beetle_wswan_libretro`                                         | **Beetle WonderSwan**                         | Straightforward.                                                                                                                                                                                                                                    |
| **Atari 2600**           | `stella_libretro`                                               | **Stella**                                    | Straightforward.                                                                                                                                                                                                                                    |
| **Atari 5200**           | `a5200_libretro`                                                | **A5200**                                     | Simple dedicated choice.                                                                                                                                                                                                                            |
| **Atari 7800**           | `prosystem_libretro`                                            | **ProSystem**                                 | Lightweight and sufficient.                                                                                                                                                                                                                         |
| **Atari 8-bit**          | `atari800_libretro`                                             | **Atari800**                                  | Standard choice.                                                                                                                                                                                                                                    |
| **Atari Lynx**           | `beetle_lynx_libretro`                                          | **Beetle Lynx**                               | Good accuracy and RK3566 has ample CPU.                                                                                                                                                                                                             |
| **Atari ST**             | `hatari_libretro`                                               | **Hatari**                                    | RetroArch integration is useful here.                                                                                                                                                                                                               |
| **ColecoVision**         | `gearcoleco_libretro`                                           | **Gearcoleco**                                | Lightweight modern option.                                                                                                                                                                                                                          |
| **Intellivision**        | `freeintv_libretro`                                             | **FreeIntv**                                  | No need for duplication.                                                                                                                                                                                                                            |
| **Vectrex**              | `vecx_libretro`                                                 | **VecX**                                      | Straightforward.                                                                                                                                                                                                                                    |
| **Odyssey² / Videopac**  | `o2em_libretro`                                                 | **O2EM**                                      | Straightforward.                                                                                                                                                                                                                                    |
| **MSX / MSX2**           | `bluemsx_libretro`                                              | **blueMSX**                                   | Broad compatibility.                                                                                                                                                                                                                                |
| **3DO**                  | `opera_libretro`                                                | **Opera**                                     | Best practical lightweight choice.                                                                                                                                                                                                                  |
| **CD-i**                 | `same_cdi_libretro`                                             | **SAME CD-i**                                 | If you want CD-i at all.                                                                                                                                                                                                                            |
| **DOS**                  | `dosbox_pure_libretro`                                          | **DOSBox Pure**                               | Much better handheld UX than manually configuring standalone DOSBox.                                                                                                                                                                                |
| **Arcade**               | `fbneo_libretro`, `mame2003_plus_libretro`                      | **FBNeo**                                     | These two are genuinely useful because they target different ROM-set/compatibility spaces. Spruce defaults to FBNeo and keeps MAME2003-Plus; ROCKNIX exposes many more MAME generations, which I would avoid. ([GitHub][2])                         |
| **PS1**                  | `pcsx_rearmed` 64-bit + **32-bit build**                        | **PCSX-ReARMed 32-bit if benchmarks confirm** | One of the few cases where AArch32 is worth maintaining. ROCKNIX currently defaults to `pcsx_rearmed32`; Spruce added a 32-bit RA option specifically for better PSX performance on the Flip. ([GitHub][3])                                         |
| **Nintendo DS**          | DraStic standalone if redistributable; otherwise `melonDS-DS`   | **DraStic**                                   | DraStic remains exceptionally efficient on low-power ARM. melonDS-DS should be the open-source fallback.                                                                                                                                            |
| **PSP**                  | PPSSPP standalone                                               | **PPSSPP standalone**                         | No reason to put RetroArch between PPSSPP and the hardware. Spruce explicitly defaults PSP to standalone PPSSPP with Performance CPU mode. ([GitHub][4])                                                                                            |
| **ScummVM**              | ScummVM standalone                                              | **Standalone**                                | Spruce has actually removed its RA ScummVM cores in favor of standalone. ([GitHub][5])                                                                                                                                                              |
| **Daphne / Singe**       | Hypseus Singe                                                   | **Standalone**                                | Purpose-built and preferable to lr-Daphne.                                                                                                                                                                                                          |
| **Amiga**                | Amiberry standalone                                             | **Amiberry**                                  | Better appliance-style experience than juggling several UAE cores.                                                                                                                                                                                  |
| **PICO-8**               | Official PICO-8 user-installed; Fake-08 fallback                | **PICO-8 native**                             | Don't redistribute the proprietary binary yourself.                                                                                                                                                                                                 |
| **GameCube / Wii**       | Dolphin standalone                                              | **Experimental only**                         | RK3566 is below where I would promise general compatibility.                                                                                                                                                                                        |
| **PS2 / 3DS**            | none in base system                                             | **Do not ship as supported platforms**        | Individual games may run, but they should not define the product.                                                                                                                                                                                   |

That gets you very close to **one emulator per platform**.

## The systems where I would deliberately not force a single implementation

**N64 is the major exception.** The current distributions disagree because different rendering/RSP/RDP paths genuinely win on different games. ROCKNIX defaults to Mupen64Plus-Next; KNULLI now defaults to ParaLLEl-N64 with glN64; Spruce defaults to KMFDManic's LudicrousN64 on the Miyoo Flip; ArkOS explicitly states that standalone Mupen64Plus will most likely provide the best performance. ([GitHub][3])

I would therefore integrate **four N64 execution paths during development**, then potentially reduce them after creating a per-game database:

| N64 backend                                                      | Role                                                                                                                       |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **KM LudicrousN64 2K22 Xtreme Amped**                            | Performance-oriented candidate; currently Spruce's Miyoo Flip default in both its 64-bit and 32-bit choices. ([GitHub][6]) |
| **Mupen64Plus-Next + GLideN64**                                  | Compatibility/general-purpose candidate; ROCKNIX default. ([GitHub][3])                                                    |
| **ParaLLEl-N64**                                                 | Alternative libretro path; KNULLI currently uses ParaLLEl as its default N64 core. ([GitHub][7])                           |
| **Mupen64Plus standalone** with **Rice + Glide64mk2 + GLideN64** | Performance escape hatch. ArkOS specifically notes that standalone Mupen tends to have the best performance. ([GitHub][8]) |

I would support **both AArch64 and AArch32 for N64 during benchmarking**. Spruce exposes exactly this choice on the Miyoo Flip: its 64-bit set includes LudicrousN64, ParaLLEl-N64, Mupen64Plus-Next and standalone Mupen; its 32-bit set includes LudicrousN64, an optimized ParaLLEl build, legacy Mupen and standalone Mupen. ([GitHub][6])

The user should **not** see that complexity. Your UI should say something like `Automatic`, `Compatibility`, and `Performance`. `Automatic` uses your game database.

## Dreamcast and Saturn need benchmark decisions before you freeze the build

These are the other two places where current distributions disagree enough that I wouldn't make the choice purely from upstream reputation.

For Dreamcast, ROCKNIX currently defaults to **Flycast2021** on RK3566, whereas current Spruce on the Miyoo Flip selects **current Flycast libretro** and also includes Flycast standalone. ([GitHub][1])

So I would initially build:

```text
Flycast current libretro
Flycast2021 libretro
Flycast current standalone
```

Run your RK3566 suite, then **delete the losers**. My expectation is that you'll end up with either current Flycast LR or Flycast2021 as your sole Dreamcast/Naomi/Atomiswave backend.

Saturn is similar. ROCKNIX defaults RK3566 to **YabaSanshiro standalone**, whereas Spruce on the Flip defaults to **YabaSanshiro libretro** and keeps standalone BIOS/HLE modes as alternatives. ([GitHub][3])

Again, benchmark first:

```text
YabaSanshiro libretro
YabaSanshiro standalone + real BIOS
```

Then keep one unless there is a reproducible compatibility reason for both.

## The two additional benchmark decisions I would make

For **GBA**, test:

```text
mGBA
vs
gpSP
```

ROCKNIX says mGBA; Spruce says gpSP. ([GitHub][1])

I suspect the decision may depend less on average FPS—both should run most games easily—and more on **required CPU frequency/battery consumption**. If gpSP can sustain the same perceived result at substantially lower clocks, it becomes compelling for a handheld.

For **SNES**, test:

```text
Snes9x current
vs
Beetle/Supafaust
```

ROCKNIX defaults to Snes9x; Spruce explicitly selects Supafaust for the Miyoo Flip class. ([GitHub][1])

I would measure demanding enhancement-chip titles rather than Mario World: Yoshi's Island, Star Fox, Super Mario RPG, Kirby Super Star, Mega Man X2/X3, etc.

---

# The integration spec I would give your AI

You can essentially give it this:

```text
TARGET
======

Target hardware:
- Rockchip RK3566
- 4x Cortex-A55
- Mali-G52
- Miyoo Flip
- 640x480 display

The emulator stack must be curated specifically for RK3566.
Do NOT integrate every available RetroArch core.

General policy:
- One default emulator/core per system.
- Alternatives are allowed only when they provide a proven compatibility
  or performance advantage on RK3566.
- N64 is explicitly exempt from the one-emulator rule.
- Arcade may contain FBNeo + MAME2003-Plus because they use different
  ROM-set ecosystems.
- Add wine, pico-8, moonlight, gzdoom, openbor, amiberry, hypseus-singe, duckstation-sa, drastic and AetherSX2. 
- We need to think about a way to make user switch between emulators.
BUILD
=====

Cross-compile from x86_64 to ARM.
Do not compile ARM packages through QEMU.

Primary target:
  aarch64
  -O2
  -mcpu=cortex-a55

Use:
- ccache
- Ninja where supported
- reproducible pinned upstream revisions
- one independently updateable artifact/pak per major emulator

Do NOT globally enable:
- -O3
- aggressive LTO
- PGO

Benchmark those independently.

Also maintain a minimal 32-bit ARM userspace/runtime for:
- PCSX-ReARMed
- N64 candidates

Do not make the complete OS 32-bit.


RETROARCH
=========

Build one 64-bit RetroArch.

Also build one minimal 32-bit RetroArch containing only cores which
actually benefit from AArch32 on RK3566.

64-bit primary core set:

NES/FDS:
  nestopia_libretro

GB/GBC:
  gambatte_libretro

GBA:
  mgba_libretro
  gpsp_libretro temporarily for benchmark
  Remove one after benchmarking.

SNES:
  snes9x_libretro
  mednafen_supafaust_libretro temporarily for benchmark
  Remove one after benchmarking.

Virtual Boy:
  mednafen_vb_libretro

Pokemon Mini:
  pokemini_libretro

Master System / Game Gear / SG-1000:
  genesis_plus_gx_libretro

Mega Drive / Genesis:
  genesis_plus_gx_libretro

Sega CD / Mega CD:
  genesis_plus_gx_libretro

32X:
  picodrive_libretro

PC Engine / PC Engine CD:
  mednafen_pce_fast_libretro

SuperGrafx:
  mednafen_supergrafx_libretro

Neo Geo AES/MVS:
  fbneo_libretro

Neo Geo CD:
  neocd_libretro

Neo Geo Pocket / Color:
  mednafen_ngp_libretro

WonderSwan / Color:
  mednafen_wswan_libretro

Atari 2600:
  stella_libretro

Atari 5200:
  a5200_libretro

Atari 7800:
  prosystem_libretro

Atari 8-bit:
  atari800_libretro

Atari Lynx:
  mednafen_lynx_libretro

Atari ST:
  hatari_libretro

ColecoVision:
  gearcoleco_libretro

Intellivision:
  freeintv_libretro

Vectrex:
  vecx_libretro

Odyssey2 / Videopac:
  o2em_libretro

MSX/MSX2:
  bluemsx_libretro

3DO:
  opera_libretro

CD-i:
  same_cdi_libretro

DOS:
  dosbox_pure_libretro


ARCADE
======

Integrate only:

  fbneo_libretro
  mame2003_plus_libretro

Default:
  FBNeo

MAME2003-Plus is a compatibility/performance fallback.

Do NOT initially integrate:
- MAME2000
- MAME2003 vanilla
- MAME2010
- MAME2015
- FBA2012
- FBA2019

Do not silently interchange ROM sets.
Track expected ROM-set version separately for FBNeo and MAME2003-Plus.


PLAYSTATION 1
=============

Integrate:

64-bit:
  pcsx_rearmed_libretro

32-bit:
  pcsx_rearmed_libretro

Prefer the 32-bit build if RK3566 benchmarks show the expected
performance advantage.

Optional later:
  PCSX-ReARMed standalone

Do not integrate SwanStation/DuckStation in the base image unless a
specific compatibility or enhanced-rendering requirement justifies it.


NINTENDO 64
===========

N64 is the main exception to the single-emulator policy.

Build and benchmark:

64-bit:
  km_ludicrousn64_2k22_xtreme_amped
  mupen64plus_next_libretro
  parallel_n64_libretro
  Mupen64Plus standalone

32-bit:
  km_ludicrousn64_2k22_xtreme_amped
  optimized parallel_n64 build if available
  mupen64plus
  Mupen64Plus standalone

Mupen64Plus standalone video plugins:
  Rice
  Glide64mk2
  GLideN64

Normal UI must NOT expose all of these directly.

Expose:
  Automatic
  Compatibility
  Performance

Create an N64 per-game override database.

Each override must support:
- ROM SHA1/CRC
- backend
- architecture (32/64)
- video plugin
- RSP/RDP configuration where relevant
- internal resolution
- frame buffer options
- CPU governor
- GPU governor
- optional emulator-specific settings

Start with no assumptions.
Benchmark against:
- SpruceOS LudicrousN64 behavior
- ROCKNIX Mupen64Plus-Next behavior
- KNULLI ParaLLEl-N64 behavior
- standalone Mupen64Plus/Rice


DREAMCAST / NAOMI / ATOMISWAVE
===============================

Temporarily integrate:

  flycast_libretro current
  flycast2021_libretro
  Flycast standalone current

Benchmark all three on Miyoo Flip.

Test at least:
- Crazy Taxi
- SoulCalibur
- Sonic Adventure
- Marvel vs Capcom 2
- Dead or Alive 2
- Ikaruga
- demanding Naomi title
- demanding Atomiswave title

Choose ONE default after benchmarking.

The final distro should ideally use the same Flycast implementation
for Dreamcast, Naomi and Atomiswave.


SATURN
======

Temporarily integrate:

  yabasanshiro_libretro
  YabaSanshiro standalone

Benchmark both.

Use real Saturn BIOS where appropriate.

Test demanding games including:
- Sega Rally
- Panzer Dragoon
- Nights
- Radiant Silvergun
- Burning Rangers
- Virtua Fighter 2

Keep one implementation if possible.


NINTENDO DS
===========

Preferred:
  DraStic standalone

Only redistribute it if licensing explicitly permits redistribution.

Open-source fallback:
  melonDS-DS

If DraStic cannot legally be distributed:
  provide user-install mechanism
  and make melonDS-DS the bundled default.


PSP
===

Use:
  PPSSPP standalone

Do NOT ship lr-PPSSPP in the base image.

Use direct GLES/Vulkan according to measured RK3566 performance.


AMIGA
=====

Use:
  Amiberry standalone

Avoid shipping multiple UAE cores unless compatibility testing
demonstrates a need.


SCUMMVM
=======

Use:
  ScummVM standalone

Do not ship the libretro core.


LASERDISC
=========

Use:
  Hypseus Singe standalone


PICO-8
======

Support:
  official PICO-8 binary installed by the user

Optional bundled fallback:
  Fake-08

Do not redistribute proprietary PICO-8 binaries.


EXPERIMENTAL
============

GameCube/Wii:
  Dolphin standalone
  Mark as experimental.
  Do not promise system-wide compatibility.

Do not include PS2 or 3DS as officially supported RK3566 systems
until testing demonstrates a worthwhile supported game set.


RUNTIME
=======

Prefer direct DRM/KMS / SDL KMSDRM where supported.

Avoid making X11 or Wayland mandatory for emulator execution.

Prefer direct ALSA where practical.

When an emulator launches:
- pause/terminate frontend rendering
- apply per-system performance profile
- configure CPU governor
- configure GPU governor if exposed
- launch emulator
- capture logs
- restore power profile on exit
- resume frontend

Do not run CPU/GPU in maximum-performance mode for systems that
do not need it.


USER EXPERIENCE
===============

The normal user should see:
  system -> game -> launch

They should not normally choose cores.

Provide an Advanced menu for manual overrides.

Support per-game override files/database.

Core/emulator names are implementation details and should not appear
in the normal launcher UI.


BENCHMARK POLICY
================

Do not select an emulator based only on average FPS.

Measure:
- average FPS
- 1% lows
- frame-time p95
- frame-time p99
- audio underruns
- input latency when measurable
- CPU utilization
- GPU utilization
- required CPU clock
- required GPU clock
- temperature after sustained load
- power consumption / battery drain
- compatibility/rendering errors

Benchmark on the actual Miyoo Flip.

For GBA compare:
  mGBA vs gpSP

For SNES compare:
  Snes9x vs Supafaust

For PS1 compare:
  PCSX-ReARMed AArch64 vs AArch32

For Dreamcast compare:
  Flycast current LR vs Flycast2021 LR vs Flycast standalone

For Saturn compare:
  YabaSanshiro LR vs YabaSanshiro standalone

For N64 compare all listed backends and build a per-game database.
```

I would make one further architectural decision: **don't package every libretro core in one giant RetroArch PAK**. Keep the RetroArch executable/runtime common, but make the cores individually replaceable, for example `cores/snes9x`, `cores/fbneo`, `cores/n64`, etc. That lets you update an N64 core or revert a bad FBNeo release without rebuilding or redistributing the whole emulation stack.

The most important change from my previous list is therefore this: **I would not yet commit to mGBA, Snes9x, Flycast2021 or standalone YabaSanshiro as unquestioned defaults.** Current RK3566 distributions disagree specifically on those four areas, and Spruce has done enough Miyoo Flip-specific work that its gpSP/Supafaust/current-Flycast/lr-YabaSanshiro choices deserve direct benchmarking rather than dismissal. Spruce's current N64 configuration is even stronger evidence for this philosophy: on the Flip it defaults to LudicrousN64 and deliberately offers 32-/64-bit variants rather than assuming the newest generic core is optimal. ([GitHub][6])

[1]: https://github.com/ROCKNIX/distribution/blob/next/documentation/PER_DEVICE_DOCUMENTATION/RK3566/SUPPORTED_EMULATORS_AND_CORES.md "distribution/documentation/PER_DEVICE_DOCUMENTATION/RK3566/SUPPORTED_EMULATORS_AND_CORES.md at next · ROCKNIX/distribution · GitHub"
[2]: https://github.com/spruceUI/spruceOS/blob/main/Emu/ARCADE/config.json "spruceOS/Emu/ARCADE/config.json at main · spruceUI/spruceOS · GitHub"
[3]: https://github.com/ROCKNIX/distribution/blob/next/documentation/PER_DEVICE_DOCUMENTATION/RK3566/SUPPORTED_EMULATORS_AND_CORES.md?utm_source=chatgpt.com "distribution/documentation/PER_DEVICE_DOCUMENTATION/RK3566/SUPPORTED_EMULATORS_AND_CORES.md at next · ROCKNIX/distribution · GitHub"
[4]: https://github.com/spruceUI/spruceOS/blob/main/Emu/PSP/config.json?utm_source=chatgpt.com "spruceOS/Emu/PSP/config.json at main · spruceUI/spruceOS · GitHub"
[5]: https://github.com/spruceUI/spruceOS/releases?utm_source=chatgpt.com "Releases · spruceUI/spruceOS · GitHub"
[6]: https://github.com/spruceUI/spruceOS/blob/main/Emu/N64/config.json "spruceOS/Emu/N64/config.json at main · spruceUI/spruceOS · GitHub"
[7]: https://github.com/knulli-cfw/knulli-linux/blob/knulli-main/knulli-Changelog.md?utm_source=chatgpt.com "knulli-linux/knulli-Changelog.md at knulli-main · knulli-cfw/knulli-linux · GitHub"
[8]: https://github.com/christianhaitian/arkos/wiki/ArkOS-Emulators-and-Ports-information/e637aaac215a3b5eb1f8327419aa0ac9262badcd?utm_source=chatgpt.com "ArkOS Emulators and Ports information · christianhaitian/arkos Wiki · GitHub"
