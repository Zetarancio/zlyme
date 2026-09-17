#!/usr/bin/env python3
"""Rasterize branding onto 640x480 #050608 (and a 512x512 logo).

Splash uses every frame of `zlyme_slime_loop.gif`, max-fitted and
centered. `splash.rgb565` is frame 0; `splash.anim` is the moving
glass rect. Charging / NextUI background stay a mid-loop still.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path
import struct
from typing import Optional

from PIL import Image, ImageSequence

import numpy as np

BG = (0x05, 0x06, 0x08, 255)
W, H = 640, 480
LOGO = 512
SCALE_MUL = 0.72
Y_CENTER_FRAC = 1.0 / 3.0
BLACK_CUTOFF = 24
LOOP_NAMES = (
    "zlyme_slime_loop.gif",
    "zlyme_slime_loop.png",
    "zlyme_slime_loop.webp",
)


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


def load_loop_frames(branding: Path) -> list[Image.Image]:
    for name in LOOP_NAMES:
        path = branding / name
        if not path.is_file():
            continue
        im = Image.open(path)
        frames = [fr.convert("RGBA") for fr in ImageSequence.Iterator(im)]
        if frames:
            return frames
    return []


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


def rgb565_bytes(im: Image.Image) -> bytes:
    arr = np.asarray(im.convert("RGB"), dtype=np.uint16)
    pix = ((arr[..., 0] >> 3) << 11) | ((arr[..., 1] >> 2) << 5) | (arr[..., 2] >> 3)
    return pix.astype("<u2").tobytes()


def write_rgb565(im: Image.Image, path: Path) -> None:
    out = rgb565_bytes(im)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)
    print(f"wrote {path} {len(out)} bytes")


def write_splash_anim(frames: list[Image.Image], path: Path, delay_ms: int) -> None:
    # Keep the anim small enough for initramfs, but cover the whole lockup
    # (not only the glass dirty-rect) so the spinner reads as the logo.
    if len(frames) > 16:
        last = len(frames) - 1
        frames = [frames[round(i * last / 15)] for i in range(16)]
    rgb = [np.asarray(im.convert("RGB"), dtype=np.uint8) for im in frames]
    stack = np.stack(rgb)
    bg = np.array(BG[:3], dtype=np.uint8)
    not_bg = np.any(stack != bg, axis=(0, 3))
    ys, xs = np.where(not_bg)
    if len(xs) == 0:
        print(f"skip {path}: frames are identical")
        return
    pad = 2
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(W - 1, int(xs.max()) + pad)
    y1 = min(H - 1, int(ys.max()) + pad)
    # Full lockup, capped at 640x320 as packed into splash.anim.
    if (y1 - y0 + 1) > 320:
        cy = (y0 + y1) // 2
        y0 = max(0, cy - 160)
        y1 = min(H - 1, y0 + 319)
        if y1 - y0 + 1 < 320:
            y0 = max(0, y1 - 319)
    w = x1 - x0 + 1
    h = y1 - y0 + 1
    hdr = struct.pack(
        "<4sHHHHHHHH",
        b"ZLYA",
        1,
        x0,
        y0,
        w,
        h,
        len(frames),
        delay_ms,
        0,
    )
    out = bytearray(hdr)
    for im in frames:
        crop = im.crop((x0, y0, x0 + w, y0 + h))
        out.extend(rgb565_bytes(crop))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))
    print(f"wrote {path} {len(out)} bytes {len(frames)}f {w}x{h}+{x0},{y0} {delay_ms}ms")


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

    for stale in branding.glob("*.crdownload"):
        stale.unlink()
        print(f"removed {stale}")

    loop_frames = [
        place_on_canvas(fr, W, H, scale_mul=1.0, y_center_frac=None)
        for fr in load_loop_frames(branding)
    ]
    if loop_frames:
        wall = loop_frames[len(loop_frames) // 2]
        still = loop_frames[0]
        delay = 80
        src = Image.open(branding / LOOP_NAMES[0]) if (branding / LOOP_NAMES[0]).is_file() else None
        if src is not None:
            d = src.info.get("duration")
            if isinstance(d, (int, float)) and d > 0:
                delay = int(round(d)) if d >= 20 else 80
        write_png(wall, res / "background.png")
        write_png(wall, res / "charging-640-480.png")
        write_rgb565(still, ramfs / "splash.rgb565")
        write_splash_anim(loop_frames, ramfs / "splash.anim", delay)
    else:
        wordmark = load_art(
            branding,
            ["Logo.png", "zlyme-horizontal-exact.svg", "zlyme-horizontal-lockup.svg"],
            800,
        )
        bg = place_on_canvas(wordmark, W, H)
        write_png(bg, res / "background.png")
        write_png(bg, res / "charging-640-480.png")
        write_rgb565(bg, ramfs / "splash.rgb565")


if __name__ == "__main__":
    main()
