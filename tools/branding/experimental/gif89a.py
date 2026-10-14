#!/usr/bin/env python3
"""GIF89a encoder for zlyme-splash.

90–135 unique frames at 30 FPS, real GIF transparency (index 0). Empty
pixels stay alpha 0. Do not flatten onto #050608.

Every frame is a complete lockup (same vis-bbox, disposal 1). Dirty-rect
frames with disposal 2 restore-to-background were wrong: viewers that
do not composite drop the word and ring, and GCT[0] magenta filled the
canvas as the background color.
"""
from __future__ import annotations

import io
import struct
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPLASH_OUT = OUT

N_FRAMES = 90  # 3.0 s at 30 FPS (top of the 60–90 budget)
FPS = 30
DURATION_MS = 33  # 1000/30, GIF stores centiseconds so this becomes 30 ms
DURATION_CS = max(2, int(round(DURATION_MS / 10.0)))

# GIF is 1-bit alpha. stack.py already stamps Base's solid lockup
# (a>=128) and punches everything else outside the window. Do not
# dither or grow that silhouette here.
_ALPHA_CUT = 128.0


def rgba(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def encode_gif89a(
    frames: list[Image.Image], dest: Path, palette_base: Path | None = None
) -> None:
    """Paletted GIF89a: 255 colors + transparent index 0, full lockup frames."""
    if not frames:
        raise ValueError("no frames")
    dest.parent.mkdir(parents=True, exist_ok=True)

    rgb_frames: list[Image.Image] = []
    masks: list[np.ndarray] = []
    opaque_samples: list[np.ndarray] = []
    for i, fr in enumerate(frames):
        arr = np.asarray(fr.convert("RGBA"), dtype=np.float32)
        a = arr[..., 3]
        rgb = arr[..., :3]
        # PNG RGB is already unassociated. Do not un-premultiply (that
        # brightens the fringe) and do not key "red" (that punches holes
        # in dark orange slime / galaxy). Base and glass are already
        # stripped in stack.py.
        opaque = a >= _ALPHA_CUT
        out = np.zeros_like(rgb)
        # Lockup RGB is already Base.png. Do not premultiply or dither.
        out[opaque] = rgb[opaque]
        trans = ~opaque
        rgb_frames.append(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB"))
        masks.append(trans)
        if i % max(1, len(frames) // 8) == 0 and opaque.any():
            opaque_samples.append(out[opaque].astype(np.uint8))

    # Pin the active lockup oranges and metal in the palette so
    # quantization does not drift away from that Base file.
    base_path = Path(palette_base) if palette_base is not None else HERE / "Base.png"
    if base_path.is_file():
        base = np.asarray(Image.open(base_path).convert("RGBA"), dtype=np.float32)
        keep = base[..., 3] >= _ALPHA_CUT
        if keep.any():
            opaque_samples.append(base[keep, :3].astype(np.uint8))

    # Palette from opaque lockup pixels only. Black canvas / letter holes
    # would otherwise dominate median-cut.
    pix = np.concatenate(opaque_samples, axis=0)
    if len(pix) > 180_000:
        rng = np.random.default_rng(0)
        pix = pix[rng.choice(len(pix), 180_000, replace=False)]
    side = int(np.ceil(np.sqrt(len(pix))))
    sheet = np.zeros((side, side, 3), dtype=np.uint8)
    sheet.reshape(-1, 3)[: len(pix)] = pix
    qmethod = Image.Quantize.MEDIANCUT
    if hasattr(Image.Quantize, "LIBIMAGEQUANT"):
        try:
            Image.fromarray(sheet[:32, :32], "RGB").quantize(
                colors=16, method=Image.Quantize.LIBIMAGEQUANT
            )
            qmethod = Image.Quantize.LIBIMAGEQUANT
        except Exception:
            qmethod = Image.Quantize.MEDIANCUT
    master = Image.fromarray(sheet, "RGB").quantize(
        colors=255, method=qmethod, dither=Image.Dither.NONE
    )
    pal255 = bytearray(master.getpalette() or [])
    pal255.extend(b"\x00" * (765 - len(pal255)))
    gct = bytes(3) + bytes(pal255[:765])  # index 0 = (0,0,0) reserved

    box = None
    for trans in masks:
        b = _bbox(~trans)
        if b is None:
            continue
        box = b if box is None else _union(box, b)
    if box is None:
        box = (0, 0, rgb_frames[0].size[0], rgb_frames[0].size[1])
    x0, y0, x1, y1 = box

    px_list: list[np.ndarray] = []
    for im, trans in zip(rgb_frames, masks):
        # Dither the lockup only so the black canvas does not bleed in.
        crop = im.crop((x0, y0, x1, y1))
        q = crop.quantize(palette=master, dither=Image.Dither.NONE)
        px = np.zeros(im.size[::-1], dtype=np.uint16)
        px[y0:y1, x0:x1] = np.asarray(q, dtype=np.uint16) + 1
        px[trans] = 0
        px_list.append(np.clip(px, 0, 255).astype(np.uint8))

    _write_full_gif(px_list, gct, dest)
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
    src_px = np.asarray(crop)
    buf = io.BytesIO()
    crop.save(buf, format="GIF", optimize=False, interlace=False)
    data = buf.getvalue()
    rt = Image.open(io.BytesIO(data))
    rt.load()
    if rt.mode != "P" or not np.array_equal(np.asarray(rt), src_px):
        raise RuntimeError("Pillow remapped GIF indices; LZW would not match GCT")
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
        raise RuntimeError("Pillow GIF wrote a local colormap")
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
    # disposal 1 = do not dispose. Packed: reserved, disposal, user, trans.
    packed = (disposal << 2) | 0x01
    return b"!" + b"\xf9\x04" + bytes([packed]) + struct.pack("<HB", DURATION_CS, 0) + b"\x00"


def _image_desc(x0: int, y0: int, w: int, h: int) -> bytes:
    return b"," + struct.pack("<HHHH", x0, y0, w, h) + b"\x00"


def _write_full_gif(px_list: list[np.ndarray], gct: bytes, dest: Path) -> None:
    """GIF89a, trans index 0, lockup-sized frames, disposal 1.

    Frame 0 paints the whole lockup. Later frames keep that same image
    descriptor and punch index 0 where the pixel still matches the
    previous frame, so LZW stays small without restore-to-background.
    """
    h, w = px_list[0].shape
    box = None
    for px in px_list:
        b = _bbox(px != 0)
        if b is None:
            continue
        box = b if box is None else _union(box, b)
    if box is None:
        box = (0, 0, 1, 1)
    x0, y0, x1, y1 = box

    out = bytearray()
    out += b"GIF89a"
    packed_gct = 0x80 | 0x70 | 0x07  # GCT, 8-bit, 256 entries
    out += struct.pack("<HHBBB", w, h, packed_gct, 0, 0)
    out += gct
    out += b"!\xff\x0bNETSCAPE2.0\x03\x01" + struct.pack("<H", 0) + b"\x00"

    prev = None
    for i, px in enumerate(px_list):
        painted = px
        if prev is not None:
            painted = px.copy()
            painted[px == prev] = 0
        prev = px
        crop = Image.fromarray(painted[y0:y1, x0:x1], "P")
        crop.putpalette(gct)
        out += _gce(1)
        out += _image_desc(x0, y0, x1 - x0, y1 - y0)
        out += _lzw_image_data(crop)
        if i % 15 == 0 or i + 1 == len(px_list):
            print(f"  gif frame {i + 1}/{len(px_list)} lockup={x1 - x0}x{y1 - y0}+{x0},{y0}")

    out += b";"
    dest.write_bytes(bytes(out))


def _verify_gif(dest: Path) -> None:
    data = dest.read_bytes()
    if data[:6] != b"GIF89a":
        raise RuntimeError(f"{dest} is not GIF89a")
    w, h, packed, bg, _ = struct.unpack_from("<HHBBB", data, 6)
    pos = 13
    if packed & 0x80:
        gct0 = tuple(data[pos : pos + 3])
        pos += 3 * (2 << (packed & 7))
    else:
        gct0 = None
    boxes = []
    disposals = []
    while pos < len(data) and data[pos] != 0x3B:
        if data[pos] == 0x21:
            if data[pos + 1] == 0xF9:
                disposals.append((data[pos + 3] >> 2) & 7)
                pos += 8
                continue
            pos += 2
            while True:
                n = data[pos]
                pos += 1
                if n == 0:
                    break
                pos += n
        elif data[pos] == 0x2C:
            x, y, fw, fh = struct.unpack_from("<HHHH", data, pos + 1)
            boxes.append((fw, fh, x, y))
            pos += 10
            if data[pos - 1] & 0x80:
                pos += 3 * (2 << (data[pos - 1] & 7))
            pos += 1
            while True:
                n = data[pos]
                pos += 1
                if n == 0:
                    break
                pos += n
        else:
            break
    if not boxes:
        raise RuntimeError(f"{dest} has no frames")
    if len(set(boxes)) != 1:
        raise RuntimeError(f"{dest} frame boxes differ: {sorted(set(boxes))}")
    if any(d != 1 for d in disposals):
        raise RuntimeError(f"{dest} disposal is {sorted(set(disposals))}, not 1")
    if gct0 == (255, 0, 255):
        raise RuntimeError(f"{dest} GCT[0] is magenta")

    im = Image.open(dest)
    n = getattr(im, "n_frames", 1)
    delay = im.info.get("duration")
    print(
        f"wrote {dest}  {dest.stat().st_size / 1e6:.1f} MB  "
        f"GIF89a {im.size[0]}x{im.size[1]} {n}f delay={delay}ms "
        f"format={im.format} mode={im.mode} trans={im.info.get('transparency')} "
        f"box={boxes[0]}"
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
    # Galaxy space is itself ~#050608. Fail only if that fill leaked onto
    # the empty canvas around the lockup bbox.
    if bg.any():
        vis = a[..., 3] > 0
        ys, xs = np.where(vis)
        outside = bg.copy()
        outside[int(ys.min()) : int(ys.max()) + 1, int(xs.min()) : int(xs.max()) + 1] = False
        if int(outside.sum()) > 0:
            raise RuntimeError(f"{dest} has opaque #050608 letterbox")
    if n > 1:
        from PIL import ImageSequence

        seq = ImageSequence.Iterator(im)
        first = np.array(next(seq).convert("RGBA"))
        mid = None
        last = None
        for i, fr in enumerate(seq, start=1):
            last = fr
            if i == n // 2:
                mid = fr
        for tag, other in (("mid", mid), ("last", last)):
            if other is None:
                continue
            b = np.array(other.convert("RGBA"))
            if (first[..., 3] > 0).sum() - (b[..., 3] > 0).sum() > 1000:
                raise RuntimeError(f"{dest} coalesced {tag} lost lockup pixels")


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


def render_kind(kind: str, n: int, sprite_at, label: str) -> None:
    """Render the window animation once, then stack onto every Base file."""
    from stack import each_base, gif_dest, set_base, stack

    sprites: list[Image.Image] = []
    for i in range(n):
        sprites.append(sprite_at(i / n))
        if i % 10 == 0 or i + 1 == n:
            print(f"{label} {i + 1}/{n}")
    for stem, path in each_base():
        set_base(path)
        dest = gif_dest(kind, stem)
        print(f"{label} {path.name} -> {dest.name}")
        frames = [rgba(stack(s)) for s in sprites]
        encode_gif89a(frames, dest, palette_base=path)
