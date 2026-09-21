#!/usr/bin/env python3
"""GIF89a encoder for zlyme-splash.

90 unique frames at 30 FPS, real GIF transparency (index 0). Empty
pixels stay alpha 0. Do not flatten onto #050608. Later frames are
dirty-rects (not full RGBA-as-GIF canvases).
"""
from __future__ import annotations

import io
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPLASH_OUT = OUT / "splash"

N_FRAMES = 90  # 3.0 s at 30 FPS (top of the 60–90 budget)
FPS = 30
DURATION_MS = 33  # 1000/30, GIF stores centiseconds so this becomes 30 ms
DURATION_CS = max(2, int(round(DURATION_MS / 10.0)))

# Reserved RGB for the transparency index. Not used in the lockup.
_TRANS_KEY = (255, 0, 255)


def rgba(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def encode_gif89a(frames: list[Image.Image], dest: Path) -> None:
    """Paletted GIF89a: 255 colors + transparent index 0, dirty-rect frames."""
    if not frames:
        raise ValueError("no frames")
    dest.parent.mkdir(parents=True, exist_ok=True)

    rgb_frames: list[Image.Image] = []
    masks: list[np.ndarray] = []
    src_rgba: list[np.ndarray] = []
    for fr in frames:
        arr = np.asarray(fr.convert("RGBA"))
        src_rgba.append(arr)
        trans = arr[..., 3] == 0
        rgb = arr[..., :3].copy()
        rgb[trans] = _TRANS_KEY
        rgb_frames.append(Image.fromarray(rgb, "RGB"))
        masks.append(trans)

    picks = rgb_frames[:: max(1, len(rgb_frames) // 8)][:8]
    w, h = rgb_frames[0].size
    sheet = Image.new("RGB", (w, h * len(picks)))
    for i, im in enumerate(picks):
        sheet.paste(im, (0, i * h))
    master = sheet.quantize(
        colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    palette = bytearray(master.getpalette() or [])
    palette.extend(b"\x00" * (768 - len(palette)))
    pal_rgb = np.frombuffer(bytes(palette[:765]), dtype=np.uint8).reshape(255, 3)
    trans_idx = int(
        np.abs(pal_rgb.astype(np.int16) - np.array(_TRANS_KEY, dtype=np.int16))
        .sum(axis=1)
        .argmin()
    )

    px_list: list[np.ndarray] = []
    for im, trans in zip(rgb_frames, masks):
        q = im.quantize(palette=master, dither=Image.Dither.NONE)
        px = np.array(q, copy=True)
        px[trans] = trans_idx
        if trans_idx != 0:
            zero = px == 0
            keyp = px == trans_idx
            px[zero] = trans_idx
            px[keyp] = 0
        px_list.append(px)

    px0 = px_list[0]
    arr0 = src_rgba[0]
    for i in range(1, len(px_list)):
        same = np.all(src_rgba[i] == arr0, axis=-1)
        px_list[i][same] = px0[same]

    swapped = bytearray(palette)
    if trans_idx != 0:
        swapped[0:3], swapped[trans_idx * 3 : trans_idx * 3 + 3] = (
            swapped[trans_idx * 3 : trans_idx * 3 + 3],
            swapped[0:3],
        )
    swapped.extend(b"\x00" * (768 - len(swapped)))
    gct = bytes(swapped[:768])

    _write_dirty_gif(px_list, gct, dest)
    _gifsicle_optimize(dest)
    _verify_gif(dest)


def _bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask)
    if xs.size == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _union(
    a: tuple[int, int, int, int], b: tuple[int, int, int, int]
) -> tuple[int, int, int, int]:
    return min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])


def _lzw_image_data(crop: Image.Image) -> bytes:
    """LZW payload (min-code-size + sub-blocks) from a paletted crop.

    Pillow's GIF saver defaults to interlaced + palette remap. Those
    indices would not match our 256-entry GCT, so force sequential
    LZW against the palette we already put on the crop.
    """
    buf = io.BytesIO()
    crop.save(buf, format="GIF", optimize=False, interlace=False)
    data = buf.getvalue()
    packed_lsd = data[10]
    off = 13
    if packed_lsd & 0x80:
        off += 3 * (2 << (packed_lsd & 7))
    while data[off] == 0x21:
        off += 2
        while True:
            n = data[off]
            off += 1
            if n == 0:
                break
            off += n
    if data[off] != 0x2C:
        raise RuntimeError("Pillow GIF had no image descriptor")
    packed = data[off + 9]
    off += 10
    if packed & 0x80:
        off += 3 * (2 << (packed & 7))
    start = off
    off += 1  # min code size
    while True:
        n = data[off]
        off += 1
        if n == 0:
            break
        off += n
    return data[start:off]


def _gce(disposal: int) -> bytes:
    # disposal 2 = restore to background. Packed: reserved, disposal, user, trans.
    packed = (disposal << 2) | 0x01
    return b"!" + b"\xf9\x04" + bytes([packed]) + struct.pack("<HB", DURATION_CS, 0) + b"\x00"


def _image_desc(x0: int, y0: int, w: int, h: int) -> bytes:
    return b"," + struct.pack("<HHHH", x0, y0, w, h) + b"\x00"


def _write_dirty_gif(px_list: list[np.ndarray], gct: bytes, dest: Path) -> None:
    """GIF89a with a global palette, trans index 0, dirty-rect frames.

    Frame 0 paints the lockup (disposal 1). Later frames share one glass
    crop and disposal 2 so restoring background cannot leave a 1px gap
    when the dirty rect shrinks.
    """
    h, w = px_list[0].shape
    box0 = _bbox(px_list[0] != 0) or (0, 0, 1, 1)
    glass = None
    for px in px_list[1:]:
        b = _bbox(px != px_list[0])
        if b is not None:
            glass = b if glass is None else _union(glass, b)
    if glass is None:
        glass = box0

    out = bytearray()
    out += b"GIF89a"
    packed_gct = 0x80 | 0x70 | 0x07  # GCT, 8-bit, 256 entries
    out += struct.pack("<HHBBB", w, h, packed_gct, 0, 0)
    out += gct
    out += b"!\xff\x0bNETSCAPE2.0\x03\x01" + struct.pack("<H", 0) + b"\x00"

    for i, px in enumerate(px_list):
        box = box0 if i == 0 else glass
        x0, y0, x1, y1 = box
        crop = Image.fromarray(px[y0:y1, x0:x1], "P")
        crop.putpalette(gct)
        out += _gce(1 if i == 0 else 2)
        out += _image_desc(x0, y0, x1 - x0, y1 - y0)
        out += _lzw_image_data(crop)
        if i % 15 == 0 or i + 1 == len(px_list):
            print(f"  gif frame {i + 1}/{len(px_list)} dirty={x1 - x0}x{y1 - y0}+{x0},{y0}")

    out += b";"
    dest.write_bytes(bytes(out))


def _gifsicle_optimize(dest: Path) -> None:
    """Squeeze LZW without remapping the reserved transparent index."""
    if shutil.which("gifsicle") is None:
        return
    with tempfile.NamedTemporaryFile(suffix=".gif", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        subprocess.check_call(
            [
                "gifsicle",
                "-O1",
                "--careful",
                "--loop=0",
                "--no-comments",
                "--no-names",
                f"--use-colormap={dest}",
                str(dest),
                "-o",
                str(tmp_path),
            ]
        )
        im = Image.open(tmp_path)
        trans = im.info.get("transparency")
        im.close()
        if trans != 0:
            return
        if tmp_path.stat().st_size and tmp_path.stat().st_size <= dest.stat().st_size:
            dest.write_bytes(tmp_path.read_bytes())
    except (subprocess.CalledProcessError, OSError):
        return
    finally:
        tmp_path.unlink(missing_ok=True)


def _verify_gif(dest: Path) -> None:
    im = Image.open(dest)
    n = getattr(im, "n_frames", 1)
    delay = im.info.get("duration")
    print(
        f"wrote {dest}  {dest.stat().st_size / 1e6:.1f} MB  "
        f"GIF89a {im.size[0]}x{im.size[1]} {n}f delay={delay}ms "
        f"format={im.format} mode={im.mode} trans={im.info.get('transparency')}"
    )
    if im.format != "GIF":
        raise RuntimeError(f"{dest} is {im.format}, not GIF")
    if im.info.get("transparency") != 0:
        raise RuntimeError(f"{dest} transparency index is {im.info.get('transparency')}, not 0")
    if dest.stat().st_size > 15 * 1000 * 1000:
        raise RuntimeError(f"{dest} is {dest.stat().st_size / 1e6:.1f} MB, over ~15 MB")
    fr = im.convert("RGBA")
    a = np.array(fr)
    if (a[..., 3] == 0).mean() < 0.1:
        raise RuntimeError(f"{dest} lost transparency")
    bg = np.all(a[..., :3] == (5, 6, 8), axis=-1) & (a[..., 3] == 255)
    if int(bg.sum()) > 0:
        raise RuntimeError(f"{dest} has opaque #050608 letterbox")


def encode_existing(src: Path, dest: Path) -> None:
    """Re-encode an already-rendered splash GIF without changing motion."""
    im = Image.open(src)
    frames: list[Image.Image] = []
    for i in range(getattr(im, "n_frames", 1)):
        im.seek(i)
        im.load()
        frames.append(im.convert("RGBA").copy())
    encode_gif89a(frames, dest)


def render_loop(composite, n: int, dest: Path, label: str) -> None:
    frames: list[Image.Image] = []
    for i in range(n):
        t = i / n
        frames.append(rgba(composite(t)))
        if i % 10 == 0 or i + 1 == n:
            print(f"{label} {i + 1}/{n}")
    encode_gif89a(frames, dest)
