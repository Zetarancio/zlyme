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

SVGs in this folder are the source pack (vector traces). Regenerated bitmaps:

- `zlyme-horizontal-exact.svg` / `Logo.png` → `../background.png` and
  `../charging-640-480.png` (640×480, vertical center at 160px), and
  initramfs `splash.rgb565`
- `Z.png` / `zlyme_beaker-exact.svg` → `../logo.png` and PortMaster
  `zlyme-theme/logo.png` (512×512)

Rebuild bitmaps from the files in this folder:

`python3 scripts/rasterize-zlyme-branding.py`
