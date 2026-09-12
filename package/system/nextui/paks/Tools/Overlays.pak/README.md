# Overlays.pak

Tool pak for [NextUI](https://github.com/LoveRetro/NextUI) that browses and
installs community overlays from the
[nextui-community-overlays](https://github.com/LoveRetro/nextui-community-overlays)
repository directly on your handheld.

- Browse by system (GB, GBA, GBC, MD, FC, ...)
- See a fullscreen preview before installing
- Install installs the PNG (and any sibling `.cfg`) into `/Overlays/[CORE]/`,
  renaming the files so different authors don't overwrite each other
- The `.cfg` is rewritten so its `overlayN_overlay = ...` line points at the
  renamed PNG

## Installation

Copy the whole `Overlays.pak` folder to your SD card under:

```
/Tools/[platform]/Overlays.pak
```

Examples:

| Device                 | Path                                  |
| ---------------------- | ------------------------------------- |
| TrimUI Smart Pro       | `/Tools/tg5040/Overlays.pak`          |
| TrimUI Brick           | `/Tools/tg3040/Overlays.pak`          |
| RG35XX Plus / Cube     | `/Tools/rg35xxplus/Overlays.pak`      |
| Miyoo Mini Plus        | `/Tools/my282/Overlays.pak`           |
| Powkiddy RGB30         | `/Tools/rgb30/Overlays.pak`           |

After copying, eject the card, boot the device, open the **Tools** menu and
run **Overlays**.

## How it works

1. On launch the script detects `$PLATFORM`/`$DEVICE` and picks the matching
   resolution folder of the repo (480p, 720p or 768p).
2. It grabs `minui-list` and `minui-presenter` (used for list/preview UI):
   - first from `$PATH`
   - then from a previously cached copy in `~/.userdata/<platform>/Overlays/bin/`
   - otherwise it downloads the prebuilt for your platform from the
     [josegonzalez/minui-list](https://github.com/josegonzalez/minui-list/releases)
     and [josegonzalez/minui-presenter](https://github.com/josegonzalez/minui-presenter/releases)
     releases.
3. It pulls the repository file tree from the GitHub API in a single request
   (`/git/trees/main?recursive=1`) and parses paths with shell tools (no `jq`).
4. UI flow: pick **system** → pick **overlay** → **fullscreen preview**
   → press **A** to install or **B** to go back.
5. There is also a `[Change resolution: ...]` entry at the bottom of the
   system list - the choice is persisted under
   `~/.userdata/<platform>/Overlays/resolution`.

## Internet

The pak needs a working Wi-Fi connection on first run (and each subsequent run,
because the index is fetched fresh as you requested). If the GitHub API rate
limit becomes a problem (60 anonymous requests / hour / IP), set the
`GITHUB_TOKEN` environment variable in `auto.sh` and the script will pick it up
through the `Authorization` header in a future revision.

## Logs

Output is written to `/.userdata/<platform>/logs/Overlays.txt` so you can debug
issues from your computer.

## Caveats

- Overlays are only honoured by **libretro** cores, not standalone emulator
  paks (this is a NextUI limitation).
- The repo currently has no overlays for `720p`, so on a TrimUI Smart Pro the
  pak will offer to switch to `768p` (or `480p`) instead.
- Some platforms (`tg3040`, etc.) do not have prebuilt `minui-list`/
  `minui-presenter` binaries upstream; on those devices either install the
  binaries manually into your `$PATH` or the pak will fall back to a plain-tty
  prompt (only useful over SSH).

## Credits

- Overlay artwork: every contributor in the
  [nextui-community-overlays](https://github.com/LoveRetro/nextui-community-overlays)
  repo - check each author folder for their license.
- `minui-list` & `minui-presenter`: [@josegonzalez](https://github.com/josegonzalez).
- NextUI: [@LoveRetro](https://github.com/LoveRetro).
