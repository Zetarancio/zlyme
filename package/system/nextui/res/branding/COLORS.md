# Zlyme color notes

Panel fill / charging / splash letterbox: `#050608`.

NextUI palette (`res/palettes/Zlyme.txt`), packed as `0xRRGGBBAA`. Roles
match Catppuccin Macchiato (peach fill, dark pills, contrasting glyphs):

| Role | Hex | NextUI |
|------|-----|--------|
| Main (selected pill / buttons) | `#F7B07C` | color1 |
| Primary accent (unselected pill) | `#050608` | color2 |
| Secondary accent (glyph on buttons) | `#050608` | color3 |
| List text | `#F2F3F5` | color4 |
| List text selected | `#050608` | color5 |
| Hint (wifi/battery/footer icons) | `#E99962` | color6 |
| Background | `#050608` | color7 |

color2 and color6 must not share a hex: hardware-group icons blit color6
on a color2 pill. Catppuccin Macchiato stays a second orange.

SVGs in this folder are the source pack (PNG-in-SVG). Regenerated bitmaps:

- `zlyme-beaker-exact.svg` → `../logo.png` (512×512 on `#050608`)
- `zlyme-horizontal-exact.svg` → `../background.png` and `../charging-640-480.png` (640×480 on `#050608`), and initramfs `splash.rgb565`

`zlyme-horizontal-lockup*.svg` and `zlyme-z-exact.svg` are unused in code; kept here.

Rebuild bitmaps: `python3 scripts/rasterize-zlyme-branding.py`
