# Zlyme color notes

Panel fill / charging / splash letterbox: `#050608`.

Faithful pack v4 oranges (from the SVG fills): beaker `#FA7C08` / `#EC2A01`,
horizontal `#FC9C14` / `#FA4D02`. Palette uses the beaker pair.

NextUI palette (`res/palettes/Zlyme.txt`), packed as `0xRRGGBBAA`. Roles
match Catppuccin Macchiato layout (orange fill, dark pills, contrasting
glyphs) with the new orange:

| Role | Hex | NextUI |
|------|-----|--------|
| Main (selected pill / buttons) | `#FA7C08` | color1 |
| Primary accent (unselected pill) | `#050608` | color2 |
| Secondary accent (glyph on buttons) | `#050608` | color3 |
| List text | `#F2F3F5` | color4 |
| List text selected | `#050608` | color5 |
| Hint (wifi/battery/footer icons) | `#EC2A01` | color6 |
| Background | `#050608` | color7 |

color2 and color6 must not share a hex: hardware-group icons blit color6
on a color2 pill.

The looping lockup is `zlyme_slime_loop.gif` (do not edit). Splash is
every frame, 75% of max-fit, centered on 640×480 `#050608`:
`splash.rgb565` (frame 0) in initramfs plus `splash.anim` on FAT
(33 ms ZLYA, 30 FPS). Galaxy `zlyme_galaxy_loop.gif` (do not edit)
is the same size and place as `progress.rgb565` + `progress.anim` for
resize / OTA. README uses `zlyme_slime_loop.gif` as-is.

- `zlyme_slime_loop.gif` → `../background.png`, initramfs
  `splash.rgb565`, FAT `splash.anim`, GitHub README
- `zlyme_galaxy_loop.gif` → initramfs `progress.rgb565`, FAT `progress.anim`
- `zlyme_charge_loop.gif` → `../charging-640-480.png` (mid-loop still)
- `Z.png` / `zlyme_beaker-exact.svg` → `../logo.png` and PortMaster
  `zlyme-theme/logo.png` (512×512)

Rebuild bitmaps from the files in this folder:

`python3 scripts/rasterize-zlyme-branding.py`
