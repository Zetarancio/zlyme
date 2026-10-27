# ADR 0011 — Button meaning follows the screen

Status: Proposed

Date: 2026-10-26

## Context

The Flip silk is north X, east A, south B, west Y. InputPlumber turns those printed letters into the Xbox letters on one virtual pad. SDL A is therefore the east button, not the south button of a standard Xbox pad.

NextUI and Settings confirm on that east button and go back on the south button. RetroArch's menu uses the same pair when the stock swap setting is false. A game has its own layout. Swapping the virtual pad for one console would move every other program.

## Decision

Keep the capability map. Do not swap Xbox A and B globally.

NextUI and Settings confirm on the east button and go back on the south button. The RetroArch menu does the same when `menu_swap_ok_cancel_buttons` is false. RetroArch 1.22.2 does not read a file key named `input_menu_swap_ok_cancel_buttons`. Its default for the real key is true, which confirms on the south button. The stock file sets the real key to false. A configuration saved before that change keeps the ignored key until Reset RetroArch configuration, or until that line is edited.

RetroArch gameplay uses the RetroPad positions the core already assigns. A core remap is added only when that core's positions are wrong. The menu swap stays in the main configuration, separate from a core remap.

A standalone that emulates one console uses that console's face positions in its packaged default. PlayStation and PSP use the Western faces: Cross south, Circle east, Square west, Triangle north. The game's region still decides which of those buttons confirms inside the game.

A program with no single console layout confirms on the east button and goes back on the south button when it has a menu of its own. Arcade, DOS, Windows, and per-game schemes do not get an invented universal layout.

A saved configuration stays. A stock default is copied when the file is missing, or when the matching reset action replaces that file. Launch scripts do not remap buttons on every start.

MENU+START, external-controller priority, and one virtual pad per player stay as ADR 0005 describes them.

## Consequences

The RetroArch menu half of this decision was observed on installed `a26f96b` after Reset RetroArch configuration: east confirms and south goes back, in NextUI, in the standalone menu, and in the menu while a Game Boy game is loaded. Game Boy gameplay used the same faces. PPSSPP on installed `a420f0c`, after Reset standalone settings, uses that layout in the menu and in play. That built-in-pad result is accepted. The mapping in `controls.ini` stays.

Flycast generates its Dreamcast faces from SDL button names and does not yet follow the Dreamcast positions. Several libretro cores have not had their descriptors read. This decision stays proposed until those gaps are closed or explicitly left as exceptions.

`docs/research/phase-15d-button-layouts.md` is the audit. `docs/ARCHITECTURE.md` keeps the controller ownership. This file does not change InputPlumber or the kernel key codes.

## Alternatives

One global A/B swap was rejected. It would fix one console by breaking the menus and the consoles that already match the silk.

Remapping inside each `launch.sh` was rejected. It would rewrite a person's saved configuration or fight the emulator's own file.
