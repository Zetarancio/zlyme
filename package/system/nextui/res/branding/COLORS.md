# Zlyme color notes

Panel fill / charging / splash letterbox: `#050608`.

NextUI palette (`res/palettes/Zlyme.txt`), packed as `0xRRGGBBAA`:

| Role | Hex | NextUI |
|------|-----|--------|
| Main | `#F2F3F5` | color1 |
| Primary accent | `#F7B07C` | color2 |
| Secondary accent | `#E99962` | color3 |
| List text | `#F2F3F5` | color4 |
| List text selected | `#050608` | color5 |
| Hint | `#F7B07C` | color6 (orange; gray is unreadable on the white pills) |
| Background | `#050608` | color7 |

SVGs in this folder are the source pack (PNG-in-SVG). Regenerated bitmaps:

- `zlyme-beaker-exact.svg` → `../logo.png` (512×512 on `#050608`)
- `zlyme-horizontal-exact.svg` → `../background.png` and `../charging-640-480.png` (640×480 on `#050608`), and initramfs `splash.rgb565`

`zlyme-horizontal-lockup*.svg` and `zlyme-z-exact.svg` are unused in code; kept here.

Rebuild bitmaps: `python3 scripts/rasterize-zlyme-branding.py`
