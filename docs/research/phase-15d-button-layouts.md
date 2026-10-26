# Phase 15D — Original-system button layouts

Date: 2026-10-26. This is the audit. It is not a hardware acceptance of any button.

## Physical path

The Flip silk is north X, east A, south B, west Y. The kernel reports those positions as `BTN_NORTH`, `BTN_EAST`, `BTN_SOUTH`, and `BTN_WEST` (`docs/research/phase-03-joypad-driver.md`).

`package/system/inputplumber/zlyme_miyoo_flip.yaml` sends the printed letters to the Xbox letters on the `xb360` target:

| Printed | Position | Source code | Virtual button | SDL gamecontroller | Raw index measured in Phase 4 |
| --- | --- | --- | --- | --- | --- |
| A | east | `BTN_EAST` | South | A, id 0 | 0 |
| B | south | `BTN_SOUTH` | East | B, id 1 | 1 |
| X | north | `BTN_NORTH` | North | X, id 2 | 2 |
| Y | west | `BTN_WEST` | West | Y, id 3 | 3 |

Phase 4 measured printed A as virtual button 0, B as 1, X as 2, and Y as 3 (`docs/research/phase-04-inputplumber.md`). Dolphin 2503a `SDLGamepad.h` names SDL A `Button S`, SDL B `Button E`, SDL X `Button W`, and SDL Y `Button N`. Those names are the usual Xbox positions. On this pad they are the printed letters, so `Button S` is the east button.

RetroPad, from the libretro ids and the stock autoconfig `package/emulators/retroarch/zlyme/autoconfig/sdl2/Microsoft X-Box 360 pad.cfg`:

| RetroPad | SDL id | Flip position |
| --- | --- | --- |
| A | 0 | east |
| B | 1 | south |
| X | 2 | north |
| Y | 3 | west |

`input_a_btn = "0"` is RetroPad A. It is not a second swap.

## Menu convention already in source

RetroArch 1.22.2 `menu/menu_driver.c` uses RetroPad A as OK and RetroPad B as Cancel when `input_menu_swap_ok_cancel_buttons` is false. The stock file sets that to false. OK is east and Cancel is south. Gameplay remaps are not required for the menu.

NextUI confirms on the virtual A button. That is SDL id 0, the east printed A. Settings and the tool presenter use the same A confirm and B back. This pass does not change NextUI or the capability map.

## Stock and reset

`zlyme-stock-seed` copies a stock file only when the destination is missing or empty, except `reset-ra`, which replaces the main RetroArch file. `ra-run.sh` does not write that file. Reset RetroArch core options deletes `/storage/.config/retroarch/config` and then copies packaged option files. No packaged core remap exists, so this pass does not add one. A user remap placed in that directory is removed by the existing reset. That contract stays.

Reset standalone settings deletes the standalone setting paths and then runs `zlyme-stock-seed standalones`. That restores PPSSPP, Flycast, and DraStic when their files are missing. Dolphin and AetherSX2 are recreated by their launchers the next time they start, and only when the pad section is absent. An existing pad file is kept.

## Upstream

ROCKNIX `d519b223` `controls.ini`, cited by the PPSSPP seed, binds PlayStation faces to Xbox letter codes. That is correct on a pad whose A button is south. It is the wrong position on this virtual pad. It is not copied again. Libretro cores that already name console buttons on RetroPad positions need no Zlyme remap. KNULLI and Batocera were not used as a substitute for those core descriptors.

## Matrix

Positions below are the Flip silk. "Current" is the stock Zlyme file or the pinned core descriptor, not a saved user file. Test status is the source reading. No Flip button press was part of this audit.

| System | Emulator/core | Original controls | Confirm, if defined | Flip position required | Current source mapping | Stock owner | Reset | Needed change | Source | Test |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NES | Nestopia `2cef539` | A right, B left | game-defined | A east, B south | default `bindmap_default`: A on RetroPad A, B on RetroPad B | shared autoconfig | RetroArch reset | none | `libretro/libretro.cpp` | CORRECT |
| Game Boy | Gambatte `4041d5a` | A right, B left | B often back | A east, B south | descriptor A/B on RetroPad A/B | shared autoconfig | RetroArch reset | none | `libgambatte/libretro/libretro.cpp` | CORRECT |
| Game Boy Color | Gambatte | same as Game Boy | same | same | same | shared autoconfig | RetroArch reset | none | same pin | CORRECT |
| Game Boy Advance | gpSP `8d268a6` | A right, B left | B often back | A east, B south | descriptor A/B on RetroPad A/B | shared autoconfig | RetroArch reset | none | `libretro/libretro.c` | CORRECT |
| SNES | Supafaust `e25f667` | Y west, X north, B south, A east | game-defined | same diamond | descriptor uses those RetroPad ids | shared autoconfig | RetroArch reset | none | `libretro.cpp` | CORRECT |
| Master System | Genesis Plus GX `302fe82` | 1 left, 2 right | game-defined | 1 south, 2 east | `DEVICE_PAD2B`: B on RetroPad B, C on RetroPad A | shared autoconfig | RetroArch reset | none | `libretro/libretro.c` | CORRECT |
| Game Gear | Genesis Plus GX | same two buttons | game-defined | same | same `PAD2B` path | shared autoconfig | RetroArch reset | none | same pin | CORRECT |
| SG-1000 | Genesis Plus GX | one or two buttons | none fixed | same pad path | same core | shared autoconfig | RetroArch reset | none | same pin | CORRECT |
| Mega Drive / Genesis | PicoDrive `ad936704`; alt Genesis Plus GX | A B C bottom, X Y Z top | game-defined | A west, B south, C east, Y north, X on L, Z on R | both cores label those RetroPad ids that way | shared autoconfig | RetroArch reset | none | PicoDrive `platform/libretro/libretro.c`; GPGX `libretro.c` | CORRECT |
| 32X | PicoDrive | same six-button pad | game-defined | same | same PicoDrive map | shared autoconfig | RetroArch reset | none | same pin | CORRECT |
| PC Engine | Beetle PCE Fast | I and II, plus a run button on some pads | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none until the descriptor is read | pin `cfbb094` | NOT VERIFIED |
| SuperGrafx | Beetle SuperGrafx | same family | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none until the descriptor is read | pin `a776133` | NOT VERIFIED |
| ColecoVision | Gearcoleco | two side buttons | none fixed | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `f336da7` | NOT VERIFIED |
| Intellivision | FreeIntv | keypad and side buttons | none fixed | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `85bf25a` | NOT VERIFIED |
| MSX | blueMSX | keyboard and one or two buttons | none fixed | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `572c918` | NOT VERIFIED |
| Odyssey 2 | O2EM | one action button | none fixed | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `c039e83` | NOT VERIFIED |
| Vectrex | vecx | four buttons | none fixed | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `56a99fa` | NOT VERIFIED |
| Neo Geo | FinalBurn Neo | A B C D | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `ae41c16` | NOT VERIFIED |
| Arcade | MAME 2003-Plus | per game | none | no universal layout | shared RetroPad | shared autoconfig | RetroArch reset | do not invent one | pin `5da0428` | AMBIGUOUS |
| Neo Geo CD | NeoCD | A B C D | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `5eca2c8` | NOT VERIFIED |
| Neo Geo Pocket | Beetle NGP | A B | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `139fe34` | NOT VERIFIED |
| WonderSwan | Beetle WonderSwan | X1–X4, Y1–Y4 | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `2aeb47d` | NOT VERIFIED |
| Virtual Boy | Beetle VB | A B and shoulders | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `8f837eb` | NOT VERIFIED |
| Pokémon Mini | PokeMini | A B C | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `9bf4508` | NOT VERIFIED |
| Atari 2600 | Stella | one button | none | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `4557099` | NOT VERIFIED |
| Atari 5200 | a5200 | keypad and buttons | none | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `5264040` | NOT VERIFIED |
| Atari 7800 | ProSystem | two buttons | none | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `4202ac5` | NOT VERIFIED |
| Atari 8-bit | Atari800 | keyboard and joystick button | none | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `6a18cb2` | NOT VERIFIED |
| Atari ST | Hatari | keyboard and mouse | none | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `a4c9eb0` | NOT VERIFIED |
| Atari Lynx | Handy | A B | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `65d6b86` | NOT VERIFIED |
| 3DO | Opera | A B C | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none | pin `35e1648` | NOT VERIFIED |
| DOS | DOSBox Pure | per program | none | no universal layout | shared RetroPad | shared autoconfig | RetroArch reset | do not invent one | 0.9.9 | AMBIGUOUS |
| PlayStation | PCSX ReARMed `9aefd42` | Cross south, Circle east, Square west, Triangle north | Western Cross; the game region can differ | Cross south, Circle east, Square west, Triangle north | Cross on RetroPad B, Circle on A, Triangle on X, Square on Y | shared autoconfig | RetroArch reset | none | `frontend/libretro.c` | CORRECT |
| PlayStation 2 | AetherSX2 1.0.0 | same DualShock faces | Western Cross | same | first-run `Cross = SDL-0/A`, so Cross is east | `start_aethersx2.sh`, only when `[Pad1]` is absent | delete `aethersx2/inis`, next launch | point Cross at SDL B, Circle at A, Square at Y, Triangle at X | `start_aethersx2.sh` and Dolphin's SDL names are the same letter map | INCORRECT |
| Nintendo 64 | Mupen64Plus-Next `6752836` | A right, B lower-left, C diamond, Z | game-defined | not established from the default face map | `libretro.c` shows C-button options, not the default A/B bind | shared autoconfig | RetroArch reset | none until that bind is read | pin above | NOT VERIFIED |
| GameCube | Dolphin `805307f` | A south, B west, X east, Y north | A | those positions | `Buttons/A = Button S`, and Button S is SDL A, the east button | `start_dolphin.sh` when `GCPadNew.ini` is absent | delete `dolphin-emu`, next launch | A = Button E, B = Button N, X = Button S, Y = Button W | `SDLGamepad.h` | INCORRECT |
| Wii | Dolphin | per game | none | no single scheme | no Wiimote stock profile | none | same directory delete | do not invent one | same Dolphin pin | AMBIGUOUS |
| Saturn | YabaSanshiro `39535a6` | A B C and X Y Z | game-defined | not opened | shared RetroPad | shared autoconfig | RetroArch reset | none until the descriptor is read | pin above | NOT VERIFIED |
| TIC-80 | TIC-80 libretro | its own buttons | none | no console diamond | shared RetroPad | shared autoconfig | RetroArch reset | do not invent one | pin `765b092` | AMBIGUOUS |
| Pico-8 | official runtime; alt fake-08 | its own buttons | none | no console diamond | SDL controller database, not a face remap | user `sdl_controllers.txt` | native config is deleted and not reseeded | do not invent one | `start_pico8.sh` | AMBIGUOUS |
| PSP | PPSSPP 1.19.3 | Cross south, Circle east, Square west, Triangle north | Western Cross; the game region can differ | those positions | Cross `10-189` is SDL A, the east button. Circle is south, Square is north, Triangle is west | `emu-defaults/ppsspp.ini` | standalone reset, then seed | Cross `10-190`, Circle `10-189`, Square `10-188`, Triangle `10-191` | `SDLJoystick.cpp` maps SDL A/B/X/Y to 189/190/191/188 | INCORRECT |
| Dreamcast | Flycast `5aa091f` | A south, B east, X west, Y north | A | those positions | non-arcade path maps SDL A/B/X/Y onto DC A/B/X/Y | `emu.cfg` has no face keys. The map is generated | standalone reset restores `emu.cfg` only | a mapping file named from `SDL_JoystickName`, including hats and axes | `core/sdl/sdl_gamepad.cpp` | INCORRECT |
| Nintendo DS | DraStic | Y west, X north, B south, A east | A | same diamond | `controls_b` A/B/X/Y are 1024–1027. UI select is 1024 and UI exit is 1025 | `/usr/share/drastic/config/drastic.cfg` | standalone reset | none. 1024 is button 0, east | stock `drastic.cfg` and the Phase 4 index | CORRECT |
| Amiga | Amiberry | keyboard and mouse | none | no single pad | no packaged face map | none | no stock file | do not invent one | `amiberry.mk` v7.1.0 | AMBIGUOUS |
| Doom | GZDoom g4.14.2 | per IWAD | none | no single pad | settings file is deleted and not reseeded | none | standalone reset | do not invent one | `gzdoom.mk` | AMBIGUOUS |
| Flash | Ruffle | pointer and keys | none | no pad diamond | no packaged face map | none | none | do not invent one | package | AMBIGUOUS |
| Ports | PortMaster | per port | none | no universal layout | port-owned | port config | Reset PortMaster does not rewrite port controls | do not invent one | ADR 0009 | AMBIGUOUS |
| EasyRPG | EasyRPG 0.8.1 | RPG Maker keys | game-defined | no console diamond | shared RetroPad | shared autoconfig | RetroArch reset | do not invent one | `libretro-easyrpg.mk` | AMBIGUOUS |
| mkxp-z | mkxp-z `650cb08` | RPG Maker keys | game-defined | no console diamond | shared RetroPad | shared autoconfig | RetroArch reset | do not invent one | pin above | AMBIGUOUS |
| ScummVM | ScummVM 2.9.1 | per game | none | no single pad | no packaged face map | none | no stock file | do not invent one | `scummvm.mk` | AMBIGUOUS |
| OpenBOR | OpenBOR v7533 | per game | none | no single pad | no packaged face map | none | no stock file | do not invent one | `openbor.mk` | AMBIGUOUS |
| Daphne | Hypseus Singe | per game | none | no single pad | no face change in this pass | none | no stock face file | do not invent one | `hypseus-singe.mk` | AMBIGUOUS |
| Windows | Wine | per program | none | no single pad | no packaged face map | none | prefix is not a controller reset | do not invent one | `wine-amd64.mk` | AMBIGUOUS |
| RetroArch menu | RGUI | menu, not a console | east confirm, south back | east OK, south Cancel | `input_menu_swap_ok_cancel_buttons = false` | `retroarch.cfg` | Reset RetroArch configuration | none | RetroArch `menu/menu_driver.c` | CORRECT |
| NextUI and Settings | NextUI | menu | east confirm, south back | east A, south B | virtual button 0 | NextUI and the capability map | not a controller-file reset | none | `zlyme_miyoo_flip.yaml` | CORRECT |

## Flycast blocker

`sdl_gamepad.cpp` builds the Dreamcast map from SDL button names when no mapping file is found. `emu.cfg` cannot name the four faces. A replacement file is `SDL_<SDL_JoystickName>.cfg` under the writable mappings directory, or a system config directory, and it replaces the whole map, including the hat and axis codes. Phase 4 recorded the gamecontroller name `Xbox 360 Controller` and the evdev name `Microsoft X-Box 360 pad`. Flycast calls `SDL_JoystickName`. Those two strings were not shown to be the same call. A file under the wrong name would leave the generated map in place. No Flycast face file is added.

## What this pass changes

PPSSPP, Dolphin's GameCube pad, and AetherSX2's first-run DualShock faces. Shoulders, sticks, Start, and Select stay. Existing user files stay. The global capability map and the RetroArch autoconfig stay.
