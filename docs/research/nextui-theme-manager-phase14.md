# NextUI Theme Manager and Art Book, Phase 14

Recorded 2026-10-16. Theme Manager is not shipped. Art Book wallpapers are a separate, smaller install.

## Pins

| Tree | Commit | What it is |
|---|---|---|
| [Leviathanium/NextUI-Theme-Manager](https://github.com/Leviathanium/NextUI-Theme-Manager) `1.5.1` | `5a42fbf7d621f36a7bf87c5656daf4a2b86e1acd` | Go tool. Release 2025-09-16. Apache-2.0. `HEAD` of the default branch is this release commit. Later tags `v1.0` through `v3.0` also exist and are not this line. |
| [anthonycaccese/art-book-next-es-de](https://github.com/anthonycaccese/art-book-next-es-de) | `d772d07109701d9bd7c9fda305bfef6601105ab8` | Installed wallpaper source. Original artwork and logos. 2026-02-07. No GitHub license file. README states CC BY-NC-SA 2.0. |
| [timbueno/ArtBookNextUI.theme](https://github.com/timbueno/ArtBookNextUI.theme) | `f5fe9929148748d0d5039b993c4815818fbb921a` | Retired NextUI conversion. 2025-05-04. No longer installed. |

## Theme Manager 1.5.1

Go program (`src/cmd/theme-manager`). Release 1.5.1 disables CGO so the ARM64 build does not link the host glibc. The README says it is only for the TrimUI Brick.

It expects:

- Install path `Tools/tg5040`
- Card root `/mnt/SDCARD`
- ROM folders `/mnt/SDCARD/Roms/Name (TAG)`
- Tools at `/mnt/SDCARD/Tools/tg5040`
- Fonts at `/mnt/SDCARD/.system/res/font1.ttf` and `font2.ttf`
- Settings at `/mnt/SDCARD/.userdata/shared/minuisettings.txt`
- LED settings at `/mnt/SDCARD/.userdata/shared/ledsettings_brick.txt`

Import copies theme files onto those paths. `import.go` deletes existing wallpapers before applying a theme, including when the theme has no wallpaper of its own. System wallpapers are written to `Roms/Name (TAG)/.media/bg.png`, list wallpapers to `.media/bglist.png`, and root, Tools, Recently Played, and Collections get their own `.media/bg.png`. That replaces user art on the card.

The UI is the bundled `minui-list` / `minui-presenter` tools, not Zlyme's NextUI settings. Accent, font, LED, and overlay components assume the Brick layout.

## Why it is not a Zlyme port

Zlyme's card root is `/storage`. Libraries are independent (`/storage`, `/mnt/sd2`, `/mnt/media/<name>`), not one `/mnt/SDCARD/Roms` tree. Persistent NextUI state is `/storage/.config/nextui`. There is no `.system/res` and no Brick LED file. A faithful port would have to:

- stop deleting user `.media` and `/storage/bg.png`
- resolve every mounted library instead of one ROM root
- write nothing under `/mnt/SDCARD` or `.userdata`
- drop LED and font replacement, or retarget them at Zlyme's real files
- launch inside a Zlyme Tools pak without assuming `tg5040`

That is a later tool. It is not required to show Art Book backgrounds.

## Art Book images

Zlyme's installed wallpapers are composed from Art Book Next `d772d07109701d9bd7c9fda305bfef6601105ab8`, not from the Timothy Bueno pack. That commit's `_inc/systems/artwork` has 213 RGBA strips, mostly 454×1080. `_inc/systems/logos` has the matching SVGs. `theme.xml` draws the strip in a carousel (`staticImage` from `artworkSource`) and the logo at `systemViewLogoPos`. For the original style, `colors.xml` sets `artworkSource` to `_inc/systems/artwork` and the logo position to `0.5 0.5`. The system background is `#000000`. The list background is `#222222`.

`gen.py` keeps the strip's aspect ratio, anchors it to the right, and puts the logo on the strip so NextUI's names stay on the black left side. The list image is only the logo, near the bottom. Pico-8 and fake-08 share `pico8`. RPG Maker XP, Tools, Collections, and Recently Played have no file in that commit. Those four are DejaVu Sans Bold wordmarks. The font is not installed.

The README license is CC BY-NC-SA 2.0. There is no GitHub LICENSE file. Credit Anthony Caccese and the names in `package/system/nextui/artbook/NOTICE.md`. Dan Patrick's logos were modified for the theme's SVG support and are part of that license statement. Noir, outline, circuit, screenshot art, fonts, and genre backgrounds are not shipped.

Timothy Bueno's NextUI pack `f5fe9929148748d0d5039b993c4815818fbb921a` was the previous source. It is a partial conversion of the same theme to 1024×768 wallpapers and does not cover every Zlyme tag. Those files are no longer in the package. The README license on that pack is also CC BY-NC-SA 2.0.
