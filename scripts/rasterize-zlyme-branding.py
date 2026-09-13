#!/usr/bin/env python3
"""Rasterize the PNG-in-SVG pack onto 640x480 #050608 (and a 512x512 logo)."""
from __future__ import annotations

import base64
import re
import sys
from pathlib import Path

from PIL import Image

BG = (0x05, 0x06, 0x08, 255)
W, H = 640, 480
LOGO = 512

def embedded_png(svg: Path) -> Image.Image:
    text = svg.read_text(errors="ignore")
    m = re.search(r"data:image/png;base64,([A-Za-z0-9+/=\s]+)", text)
    if not m:
        sys.exit(f"no embedded png in {svg}")
    raw = base64.b64decode(re.sub(r"\s+", "", m.group(1)))
    from io import BytesIO
    im = Image.open(BytesIO(raw)).convert("RGBA")
    return im

def fit_on_canvas(src: Image.Image, cw: int, ch: int, fill=BG) -> Image.Image:
    canvas = Image.new("RGBA", (cw, ch), fill)
    scale = min(cw / src.width, ch / src.height)
    nw, nh = max(1, int(src.width * scale)), max(1, int(src.height * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (cw - nw) // 2
    y = (ch - nh) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas

def write_png(im: Image.Image, path: Path, mode: str = "RGB") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert(mode).save(path, "PNG", optimize=True)
    print(f"wrote {path} {im.size}")

def write_rgb565(im: Image.Image, path: Path) -> None:
    rgb = im.convert("RGB")
    out = bytearray()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = rgb.getpixel((x, y))
            pix = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
            out.append(pix & 0xFF)
            out.append((pix >> 8) & 0xFF)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))
    print(f"wrote {path} {len(out)} bytes")

def main() -> None:
    pack = Path(sys.argv[1] if len(sys.argv) > 1 else "/home/ale/Downloads/zlyme_exact_svg_pack")
    res = Path(sys.argv[2] if len(sys.argv) > 2 else "/home/ale/ZETAOS/package/system/nextui/res")
    branding = res / "branding"
    ramfs = Path("/home/ale/ZETAOS/package/boot/zlyme-initramfs")

    branding.mkdir(parents=True, exist_ok=True)
    for svg in sorted(pack.glob("*.svg")):
        dest = branding / svg.name
        dest.write_bytes(svg.read_bytes())
        print(f"copied {dest}")

    beaker = embedded_png(pack / "zlyme-beaker-exact.svg")
    horiz = embedded_png(pack / "zlyme-horizontal-exact.svg")

    bg = fit_on_canvas(horiz, W, H)
    logo = fit_on_canvas(beaker, LOGO, LOGO, fill=(0, 0, 0, 0))
    # If the beaker is already opaque, give it the same panel fill behind alpha.
    logo_bg = Image.new("RGBA", (LOGO, LOGO), BG)
    logo_bg.alpha_composite(logo)

    write_png(bg, res / "background.png")
    write_png(bg, res / "charging-640-480.png")
    write_png(logo_bg, res / "logo.png", mode="RGBA")
    write_rgb565(bg, ramfs / "splash.rgb565")

if __name__ == "__main__":
    main()
