#!/usr/bin/env python3
"""Rasterize the faithful SVG pack onto 640x480 #050608 (and a 512x512 logo).

The lockup is 40% smaller than a full-frame fit and sits in the upper third.
SVGs are vector traces; rsvg-convert draws them (no embedded PNG).
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

BG = (0x05, 0x06, 0x08, 255)
W, H = 640, 480
LOGO = 512
# 40% smaller than a full-canvas fit, then clamped into the upper third.
SCALE_MUL = 0.60
BAND = (0.0, 1.0 / 3.0)


def rsvg_png(svg: Path, dest: Path, width: int) -> None:
    subprocess.check_call(
        ["rsvg-convert", "-w", str(width), "-o", str(dest), str(svg)]
    )


def place_on_canvas(
    src: Image.Image,
    cw: int,
    ch: int,
    fill=BG,
    scale_mul: float = SCALE_MUL,
    band: tuple[float, float] = BAND,
) -> Image.Image:
    canvas = Image.new("RGBA", (cw, ch), fill)
    full = min(cw / src.width, ch / src.height)
    band_h = max(1, int(ch * (band[1] - band[0])))
    band_fit = min(cw / src.width, band_h / src.height)
    scale = min(full * scale_mul, band_fit)
    nw = max(1, int(src.width * scale))
    nh = max(1, int(src.height * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (cw - nw) // 2
    band_top = int(ch * band[0])
    y = band_top + (band_h - nh) // 2
    if y < 0:
        y = 0
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
    pack = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else "/home/ale/Downloads/zlyme-faithful-svg-pack-v4"
    )
    res = Path(
        sys.argv[2]
        if len(sys.argv) > 2
        else "/home/ale/ZETAOS/package/system/nextui/res"
    )
    branding = res / "branding"
    ramfs = Path("/home/ale/ZETAOS/package/boot/zlyme-initramfs")
    pm_logo = Path("/home/ale/ZETAOS/package/system/portmaster/zlyme-theme/logo.png")

    branding.mkdir(parents=True, exist_ok=True)
    for stale in branding.glob("zlyme-horizontal-lockup*.svg"):
        stale.unlink()
        print(f"removed {stale}")
    for svg in sorted(pack.glob("*.svg")):
        dest = branding / svg.name
        dest.write_bytes(svg.read_bytes())
        print(f"copied {dest}")

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        beaker_png = tmp / "beaker.png"
        horiz_png = tmp / "horiz.png"
        rsvg_png(pack / "zlyme-beaker-exact.svg", beaker_png, 512)
        rsvg_png(pack / "zlyme-horizontal-exact.svg", horiz_png, 800)
        beaker = Image.open(beaker_png).convert("RGBA")
        horiz = Image.open(horiz_png).convert("RGBA")

    bg = place_on_canvas(horiz, W, H)
    logo = place_on_canvas(beaker, LOGO, LOGO, band=(0.0, 1.0), scale_mul=SCALE_MUL)

    write_png(bg, res / "background.png")
    write_png(bg, res / "charging-640-480.png")
    write_png(logo, res / "logo.png", mode="RGBA")
    write_png(logo, pm_logo, mode="RGBA")
    write_rgb565(bg, ramfs / "splash.rgb565")


if __name__ == "__main__":
    main()
