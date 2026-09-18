#!/usr/bin/env python3
"""Rasterize branding onto 640x480 #050608 (and a 512x512 logo).

Splash and the OTA/resize lockup use the same centered 75% fit so a
switch does not jump. Sources stay the GIFs in branding/; this script
never writes those files. `splash.rgb565` is slime frame 0;
`splash.anim` is every slime frame. Galaxy goes to `progress.*`.
Charging is a mid-loop still from the charge GIF; NextUI background
is a mid-loop still from slime. README uses zlyme_slime_loop.gif.
Keep every unique frame. ZLYA delay is 33 ms (30 FPS).
"""
from __future__ import annotations

import shutil
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
SPLASH_SCALE = 0.75
Y_CENTER_FRAC = 1.0 / 3.0
BLACK_CUTOFF = 24
# Keep every source frame. Do not subsample a 135-frame clip to 48.
ANIM_FRAMES = 10000
ZLYA_DELAY_MS = 33
LOOP_NAMES = (
    "zlyme_slime_loop.gif",
    "zlyme_slime_loop.png",
    "zlyme_slime_loop.webp",
)
GALAXY_NAME = "zlyme_galaxy_loop.gif"
CHARGE_NAME = "zlyme_charge_loop.gif"


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


def src_delay_ms(im: Image.Image) -> float:
    d = im.info.get("duration")
    if isinstance(d, (int, float)) and d > 0:
        return float(d)
    return 1000.0 / 30.0


def frame_delay_ms(src_delay: float, n_src: int, n_keep: int) -> int:
    """Copy the source delay 1:1. Never stretch dropped frames into lag."""
    (n_src, n_keep)  # kept in the signature for call sites
    return max(20, min(65535, int(round(src_delay))))


def pick_indices(n: int, keep: int) -> list[int]:
    if n <= 1:
        return [0]
    if n <= keep:
        return list(range(n))
    # Even steps around the cycle. Do not force the last source frame;
    # that sits next to frame 0 and makes the join hitch.
    out = []
    seen = set()
    for i in range(keep):
        idx = int(i * n / keep) % n
        if idx not in seen:
            seen.add(idx)
            out.append(idx)
    return out


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


def rasterize_gif(
    path: Path,
    scale_mul: float,
    keep: int,
    cw: int = W,
    ch: int = H,
    fill=BG,
) -> tuple[list[Image.Image], Image.Image, Image.Image, int]:
    im = Image.open(path)
    n = getattr(im, "n_frames", 1)
    want = pick_indices(n, keep)
    extra = {0, n // 2}
    needed = set(want) | extra
    canvases: dict[int, Image.Image] = {}
    for i, fr in enumerate(ImageSequence.Iterator(im)):
        if i not in needed:
            continue
        canvases[i] = place_on_canvas(
            fr.convert("RGBA"),
            cw,
            ch,
            fill=fill,
            scale_mul=scale_mul,
            y_center_frac=None,
        )
    still = canvases[0]
    wall = canvases.get(n // 2, still)
    frames = [canvases[i] for i in want if i in canvases]
    delay = frame_delay_ms(src_delay_ms(im), n, len(frames))
    return frames, still, wall, delay


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
    # Union dirty-rect of non-#050608 pixels. Anims live on FAT, so do
    # not clamp the box to fit an initramfs budget.
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


def write_readme_gif(frames: list[Image.Image], path: Path, delay_ms: int) -> None:
    """Paletted GIF, real alpha, disposal 2 so GitHub is not a black box.

    Same idea as the old 640x320 README loop: punch transparent pixels to a
    reserved magenta, share one 255-color palette, mark that index
    transparent. disposal=2 restores the page between frames.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    key = (255, 0, 255)
    rgb_frames: list[Image.Image] = []
    masks: list[np.ndarray] = []
    for fr in frames:
        arr = np.asarray(fr.convert("RGBA"))
        trans = arr[..., 3] < 16
        rgb = arr[..., :3].copy()
        rgb[trans] = key
        rgb_frames.append(Image.fromarray(rgb, "RGB"))
        masks.append(trans)

    w, h = rgb_frames[0].size
    sheet = Image.new("RGB", (w, h * len(rgb_frames)))
    for i, im in enumerate(rgb_frames):
        sheet.paste(im, (0, i * h))
    master = sheet.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = bytearray(master.getpalette() or [])
    palette.extend(b"\x00" * (768 - len(palette)))
    pal_rgb = np.frombuffer(bytes(palette[:765]), dtype=np.uint8).reshape(255, 3)
    trans_idx = int(np.abs(pal_rgb.astype(np.int16) - np.array(key, dtype=np.int16)).sum(axis=1).argmin())

    pals: list[Image.Image] = []
    for im, trans in zip(rgb_frames, masks):
        q = im.quantize(palette=master, dither=Image.Dither.NONE)
        px = np.array(q, copy=True)
        px[trans] = trans_idx
        if trans_idx != 0:
            zero = px == 0
            keyp = px == trans_idx
            px[zero] = trans_idx
            px[keyp] = 0
        out = Image.fromarray(px, "P")
        pal = bytearray(palette)
        if trans_idx != 0:
            pal[0:3], pal[trans_idx * 3 : trans_idx * 3 + 3] = (
                pal[trans_idx * 3 : trans_idx * 3 + 3],
                pal[0:3],
            )
        out.putpalette(bytes(pal))
        pals.append(out)
    trans_idx = 0

    pals[0].save(
        path,
        save_all=True,
        append_images=pals[1:],
        loop=0,
        duration=int(delay_ms),
        disposal=2,
        transparency=0,
        optimize=False,
    )
    # Shrink for GitHub. Coalesce first so optimize does not flatten
    # transparent pixels into an opaque black page.
    magick = shutil.which("magick")
    if magick:
        tmp = path.with_suffix(".opt.gif")
        subprocess.check_call(
            [
                magick,
                str(path),
                "-coalesce",
                "-delay",
                str(max(2, int(round(delay_ms / 10.0)))),
                "-dispose",
                "Background",
                "-layers",
                "optimize",
                "-loop",
                "0",
                str(tmp),
            ]
        )
        tmp.replace(path)
    print(
        f"wrote {path} {path.stat().st_size} bytes {len(frames)}f "
        f"{delay_ms}ms trans={trans_idx}"
    )


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

    slime = None
    for name in LOOP_NAMES:
        cand = branding / name
        if cand.is_file():
            slime = cand
            break

    if slime is not None:
        _, _, wall, _ = rasterize_gif(slime, 1.0, 3)
        write_png(wall, res / "background.png")
        splash_frames, splash_still, _, _ = rasterize_gif(
            slime, SPLASH_SCALE, ANIM_FRAMES
        )
        write_rgb565(splash_still, ramfs / "splash.rgb565")
        write_splash_anim(splash_frames, ramfs / "splash.anim", ZLYA_DELAY_MS)
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

    charge = branding / CHARGE_NAME
    if charge.is_file():
        _, _, wall, _ = rasterize_gif(charge, 1.0, 3)
        write_png(wall, res / "charging-640-480.png")
    elif slime is not None:
        _, _, wall, _ = rasterize_gif(slime, 1.0, 3)
        write_png(wall, res / "charging-640-480.png")

    galaxy = branding / GALAXY_NAME
    if galaxy.is_file():
        g_frames, g_still, _, _ = rasterize_gif(
            galaxy, SPLASH_SCALE, ANIM_FRAMES
        )
        write_rgb565(g_still, ramfs / "progress.rgb565")
        write_splash_anim(g_frames, ramfs / "progress.anim", ZLYA_DELAY_MS)


if __name__ == "__main__":
    main()
