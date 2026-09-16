#!/usr/bin/env python3
"""Rasterize branding onto 640x480 #050608 (and a 512x512 logo).

Prefers the PNGs in package/system/nextui/res/branding/ (Logo.png =
wordmark, Z.png = mark). Falls back to the SVGs via rsvg-convert.
Near-black pixels are treated as transparent so the #050608 panel fill
shows through.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

from PIL import Image

BG = (0x05, 0x06, 0x08, 255)
W, H = 640, 480
LOGO = 512
SCALE_MUL = 0.72
Y_CENTER_FRAC = 1.0 / 3.0
BLACK_CUTOFF = 24


def rsvg_png(svg: Path, dest: Path, width: int) -> None:
    subprocess.check_call(
        ["rsvg-convert", "-w", str(width), "-o", str(dest), str(svg)]
    )


def knock_out_black(src: Image.Image) -> Image.Image:
    im = src.convert("RGBA")
    pix = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if a == 0:
                continue
            if r <= BLACK_CUTOFF and g <= BLACK_CUTOFF and b <= BLACK_CUTOFF:
                pix[x, y] = (r, g, b, 0)
    return im


def load_art(branding: Path, names: list[str], svg_width: int) -> Image.Image:
    for name in names:
        path = branding / name
        if not path.is_file():
            continue
        if path.suffix.lower() in {".png", ".webp"}:
            return knock_out_black(Image.open(path))
        if path.suffix.lower() == ".svg":
            with tempfile.TemporaryDirectory() as td:
                dest = Path(td) / "art.png"
                rsvg_png(path, dest, svg_width)
                return knock_out_black(Image.open(dest))
    raise FileNotFoundError(f"none of {names} in {branding}")


def place_on_canvas(
    src: Image.Image,
    cw: int,
    ch: int,
    fill=BG,
    scale_mul: float = SCALE_MUL,
    y_center_frac: Optional[float] = Y_CENTER_FRAC,
) -> Image.Image:
    canvas = Image.new("RGBA", (cw, ch), fill)
    full = min(cw / src.width, ch / src.height)
    scale = full * scale_mul
    nw = max(1, int(src.width * scale))
    nh = max(1, int(src.height * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    x = (cw - nw) // 2
    if y_center_frac is None:
        y = (ch - nh) // 2
    else:
        y = int(ch * y_center_frac) - nh // 2
    if y < 0:
        y = 0
    if y + nh > ch:
        y = max(0, ch - nh)
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
    repo = Path("/home/ale/ZETAOS")
    branding = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else repo / "package/system/nextui/res/branding"
    )
    res = Path(
        sys.argv[2]
        if len(sys.argv) > 2
        else repo / "package/system/nextui/res"
    )
    ramfs = repo / "package/boot/zlyme-initramfs"
    pm_logo = repo / "package/system/portmaster/zlyme-theme/logo.png"

    for stale in branding.glob("*.crdownload"):
        stale.unlink()
        print(f"removed {stale}")

    wordmark = load_art(
        branding,
        ["Logo.png", "zlyme-horizontal-exact.svg", "zlyme-horizontal-lockup.svg"],
        800,
    )
    mark = load_art(
        branding,
        ["Z.png", "zlyme_beaker-exact.svg", "zlyme-beaker-exact.svg"],
        512,
    )

    bg = place_on_canvas(wordmark, W, H)
    logo = place_on_canvas(mark, LOGO, LOGO, y_center_frac=None, scale_mul=SCALE_MUL)

    write_png(bg, res / "background.png")
    write_png(bg, res / "charging-640-480.png")
    write_png(logo, res / "logo.png", mode="RGBA")
    write_png(logo, pm_logo, mode="RGBA")
    write_rgb565(bg, ramfs / "splash.rgb565")


if __name__ == "__main__":
    main()
