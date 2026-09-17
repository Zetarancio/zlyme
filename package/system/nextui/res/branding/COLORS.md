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

The looping lockup is `zlyme_slime_loop.gif` (README; paletted, 640×320).
Splash is every GIF frame max-fitted and centered on 640×480 `#050608`:
`splash.rgb565` (frame 0) plus `splash.anim` (moving glass). Charging /
NextUI background stay a mid-loop still.

- `zlyme_slime_loop.gif` → `../background.png`, `../charging-640-480.png`,
  initramfs `splash.rgb565` + `splash.anim`
- `Z.png` / `zlyme_beaker-exact.svg` → `../logo.png` and PortMaster
  `zlyme-theme/logo.png` (512×512)

Rebuild bitmaps from the files in this folder:

`python3 scripts/rasterize-zlyme-branding.py`
