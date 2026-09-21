#!/usr/bin/env python3
"""Shared foggy-glass viewport on the Zlyme lockup.

Used by the slime / galaxy / charge loops. Stays in tools/branding/experimental.
"""
from __future__ import annotations

import io
import struct
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
REFS = HERE / "refs"
OUT = HERE / "out"
STATIC = REFS / "static_fog.png"
EMPTY_GLASS = REFS / "zlyme_empty_glass_transparent.png"
FOG_PNG = OUT / "zlyme_static_fog_transparent.png"
PACK = REFS / "zlyme_circle_masks"
GLASS_MASK = PACK / "zlyme_glass_mask.png"
METAL_MASK = PACK / "zlyme_metal_ring_mask.png"
LIQUID_MASK = PACK / "zlyme_liquid_animation_mask.png"

# Similarity that plants the 1254² glass mask on the lockup porthole:
#   lockup_xy = (VIEW_CX, VIEW_CY) + MASK_SCALE * (mask_xy - MASK_CENTER)
MASK_SCALE = 0.2680
VIEW_CX = 1490.30
VIEW_CY = 286.00
VIEW_R = 156.25  # lighting / crop; the hole itself is the warped mask
DRIP_SAT = 0.42


def _mask_centroid(path: Path) -> tuple[float, float]:
    m = np.array(Image.open(path).convert("L"))
    ys, xs = np.where(m > 127)
    return float(xs.mean()), float(ys.mean())


MASK_CX, MASK_CY = _mask_centroid(GLASS_MASK)


def load_rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"), dtype=np.float32)


def save_rgba(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(path)


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fract(x: np.ndarray) -> np.ndarray:
    return x - np.floor(x)


def _hash2(ix: np.ndarray, iy: np.ndarray, seed: float) -> np.ndarray:
    n = np.sin(ix * 127.1 + iy * 311.7 + seed) * 43758.5453123
    return _fract(n)


def value_noise(x: np.ndarray, y: np.ndarray, seed: float = 0.0) -> np.ndarray:
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    a = _hash2(x0, y0, seed)
    b = _hash2(x0 + 1.0, y0, seed)
    c = _hash2(x0, y0 + 1.0, seed)
    d = _hash2(x0 + 1.0, y0 + 1.0, seed)
    return (a * (1.0 - ux) + b * ux) * (1.0 - uy) + (c * (1.0 - ux) + d * ux) * uy


def fbm(x: np.ndarray, y: np.ndarray, octaves: int = 5, seed: float = 0.0) -> np.ndarray:
    tot = 0.0
    amp = 0.5
    freq = 1.0
    nrm = 0.0
    for i in range(octaves):
        tot = tot + amp * value_noise(x * freq, y * freq, seed + i * 19.2)
        nrm += amp
        amp *= 0.52
        freq *= 2.07
    return tot / nrm


def bilinear(tex: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = tex.shape[:2]
    x = np.clip(x, 0.0, w - 1.001)
    y = np.clip(y, 0.0, h - 1.001)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    ax = x - x0
    ay = y - y0
    ia = tex[y0, x0]
    ib = tex[y0, x1]
    ic = tex[y1, x0]
    id_ = tex[y1, x1]
    if tex.ndim == 2:
        return (ia * (1.0 - ax) + ib * ax) * (1.0 - ay) + (ic * (1.0 - ax) + id_ * ax) * ay
    ax = ax[..., None]
    ay = ay[..., None]
    return (ia * (1.0 - ax) + ib * ax) * (1.0 - ay) + (ic * (1.0 - ax) + id_ * ax) * ay


def load_luma_mask(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def load_glass_hole() -> np.ndarray:
    """Glass disk in mask space, clipped by the metal ring. Native AA only."""
    glass = load_luma_mask(GLASS_MASK)
    ring = load_luma_mask(METAL_MASK)
    return np.clip(glass * (1.0 - ring), 0.0, 1.0)


def saturation(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    return np.where(mx > 1.0, (mx - mn) / np.maximum(mx, 1.0), 0.0)


def screen_blend(base: np.ndarray, overlay: np.ndarray, amt: np.ndarray) -> np.ndarray:
    a = np.clip(base / 255.0, 0.0, 1.0)
    b = np.clip(overlay / 255.0, 0.0, 1.0)
    m = amt[..., None] if amt.ndim == 2 else amt
    out = 1.0 - (1.0 - a) * (1.0 - b)
    return (a * (1.0 - m) + out * m) * 255.0


def hue_rotate(rgb: np.ndarray, degrees: float) -> np.ndarray:
    """Rotate hue of an HxWx3 float RGB image in 0..255."""
    a = np.clip(rgb / 255.0, 0.0, 1.0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    df = mx - mn
    h = np.zeros_like(mx)
    mask = df > 1e-5
    rmask = mask & (mx == r)
    gmask = mask & (mx == g) & ~rmask
    bmask = mask & ~(rmask | gmask)
    h[rmask] = np.mod((g[rmask] - b[rmask]) / df[rmask], 6.0)
    h[gmask] = (b[gmask] - r[gmask]) / df[gmask] + 2.0
    h[bmask] = (r[bmask] - g[bmask]) / df[bmask] + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-5, df / np.maximum(mx, 1e-5), 0.0)
    v = mx
    h = np.mod(h + degrees / 360.0, 1.0)
    c = v * s
    x = c * (1.0 - np.abs(np.mod(h * 6.0, 2.0) - 1.0))
    m = v - c
    hi = np.floor(h * 6.0).astype(np.int32)
    out = np.zeros_like(a)
    tables = [
        (c, x, 0.0),
        (x, c, 0.0),
        (0.0, c, x),
        (0.0, x, c),
        (x, 0.0, c),
        (c, 0.0, x),
    ]
    for i, (rr, gg, bb) in enumerate(tables):
        sel = hi == i if i < 5 else hi >= 5
        if not np.any(sel):
            continue
        rch = rr if np.isscalar(rr) else rr[sel]
        gch = gg if np.isscalar(gg) else gg[sel]
        bch = bb if np.isscalar(bb) else bb[sel]
        out[sel, 0] = rch + m[sel]
        out[sel, 1] = gch + m[sel]
        out[sel, 2] = bch + m[sel]
    return np.clip(out * 255.0, 0.0, 255.0)


class Glass:
    def __init__(self, static: Path = STATIC) -> None:
        self.orig = load_rgba(static)
        self.h, self.w = self.orig.shape[:2]
        pad = 16
        self.y0 = max(0, int(VIEW_CY - VIEW_R - pad))
        self.y1 = min(self.h, int(VIEW_CY + VIEW_R + pad) + 1)
        self.x0 = max(0, int(VIEW_CX - VIEW_R - pad))
        self.x1 = min(self.w, int(VIEW_CX + VIEW_R + pad) + 1)

        ys = np.arange(self.y0, self.y1, dtype=np.float32)
        xs = np.arange(self.x0, self.x1, dtype=np.float32)
        yy, xx = np.meshgrid(ys, xs, indexing="ij")
        self.dx = xx - VIEW_CX
        self.dy = yy - VIEW_CY
        self.dist = np.hypot(self.dx, self.dy)
        self.nx = self.dx / VIEW_R
        self.ny = self.dy / VIEW_R
        self.rad = np.hypot(self.nx, self.ny)
        r2 = np.clip(self.nx * self.nx + self.ny * self.ny, 0.0, 1.0)
        self.z = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))

        mx = MASK_CX + self.dx / MASK_SCALE
        my = MASK_CY + self.dy / MASK_SCALE
        self.mx, self.my = mx, my
        self.aa = bilinear(load_glass_hole(), mx, my)
        self.liquid = bilinear(load_luma_mask(LIQUID_MASK), mx, my)
        self.empty_glass = bilinear(load_rgba(EMPTY_GLASS), mx, my)
        # PNG fringe along the inner hole is a thin red matte. Keep drips.
        eg = self.empty_glass
        r, gc, b = eg[..., 0], eg[..., 1], eg[..., 2]
        ea = eg[..., 3] / 255.0
        fringe = (
            (r > 70.0)
            & ((r - np.maximum(gc, b)) > 35.0)
            & (ea < 0.72)
            & (ea > 0.01)
        )
        eg[..., 3] = np.where(fringe, 0.0, eg[..., 3])
        self.empty_glass = eg

        patch = self.orig[self.y0 : self.y1, self.x0 : self.x1]
        rgb = patch[..., :3]
        a = patch[..., 3]
        lum = rgb.mean(axis=2)
        sat = saturation(rgb)
        drip = (
            (sat > DRIP_SAT)
            & (rgb[..., 0] > 140.0)
            & ((rgb[..., 0] - rgb[..., 2]) > 70.0)
            & (a > 140.0)
        )
        drip_img = Image.fromarray((drip.astype(np.uint8) * 255), "L").filter(
            ImageFilter.GaussianBlur(radius=0.8)
        )
        self.drip = np.clip(np.array(drip_img, dtype=np.float32) / 255.0, 0.0, 1.0)
        self.drip_put = drip.astype(np.float32)
        self.interior = self.aa * (1.0 - self.drip) * (a > 20.0)
        spec = (
            smoothstep(226.0, 248.0, lum)
            * (1.0 - smoothstep(0.16, 0.38, sat))
            * self.aa
        )
        self.spec = spec * (1.0 - self.drip)
        self.fog_rgb = rgb
        rim = smoothstep(0.72, 0.99, self.rad)
        self.rim_shadow = np.clip(1.0 - lum / 210.0, 0.0, 1.0) * rim * (1.0 - self.drip)

        # Volumetric wisps for the magician-ball interior.
        u = self.nx * 1.85 + self.z * 0.95
        v = self.ny * 1.85 - self.z * 0.70
        w1 = fbm(u * 1.15 + 3.1, v * 1.15, octaves=4, seed=1.0)
        w2 = fbm(u * 1.15, v * 1.15 + 4.7, octaves=4, seed=5.0)
        c1 = fbm(u * 2.35 + w1 * 1.7, v * 2.35 - w2 * 1.5, octaves=5, seed=9.0)
        c2 = fbm(u * 3.9 - w2 * 0.9, v * 3.9 + w1 * 0.8, octaves=4, seed=14.0)
        raw = 0.62 * c1 + 0.38 * c2
        wisps = smoothstep(0.36, 0.74, raw)
        wisps = (wisps * wisps) * (0.50 + 0.50 * raw)
        wisps *= smoothstep(1.02, 0.70, self.rad)
        self.clouds = np.clip(wisps, 0.0, 1.0)
        self.cloud_lit = np.clip(
            0.48 + 0.62 * (-self.nx * 0.32 - self.ny * 0.68 + self.z * 0.42),
            0.35,
            1.20,
        )

    def polish(
        self,
        rgb: np.ndarray,
        fog_center: float = 0.08,
        fog_rim: float = 0.26,
        spec_gain: float = 1.05,
        fresnel_gain: float = 0.30,
        fog_pulse: float = 0.0,
    ) -> np.ndarray:
        """Fog, bezel shadow, fresnel and the original window specular."""
        out = rgb * (1.0 - 0.48 * self.rim_shadow)[..., None]
        fog_a = fog_center + (fog_rim - fog_center) * smoothstep(0.34, 1.0, self.rad)
        fog_a = np.clip(fog_a * (1.0 + fog_pulse), 0.0, 0.7) * self.interior
        fog_col = self.fog_rgb * 0.62 + np.array([236.0, 214.0, 198.0]) * 0.38
        out = out * (1.0 - fog_a[..., None]) + fog_col * fog_a[..., None]
        fres = ((1.0 - self.z) ** 2.65) * self.interior
        glass = np.array([214.0, 224.0, 232.0], dtype=np.float32)
        out = out * (1.0 - fres * fresnel_gain)[..., None] + glass * (
            fres * fresnel_gain
        )[..., None]
        spec_col = np.array([255.0, 250.0, 244.0], dtype=np.float32)
        out = screen_blend(out, spec_col * self.spec[..., None], self.spec * spec_gain)
        return np.clip(out, 0.0, 255.0)

    def composite(
        self,
        interior_rgb: np.ndarray,
        interior_alpha: np.ndarray | None = None,
    ) -> np.ndarray:
        """Paste the viewport. interior_alpha is 0..255; default is opaque disc."""
        out = self.orig.copy()
        patch = out[self.y0 : self.y1, self.x0 : self.x1]
        cover = self.interior
        rgb = patch[..., :3] * (1.0 - cover[..., None]) + interior_rgb * cover[..., None]
        if interior_alpha is None:
            new_a = np.maximum(patch[..., 3], cover * 255.0)
        else:
            new_a = patch[..., 3] * (1.0 - cover) + interior_alpha * cover
        patch[..., :3] = rgb
        patch[..., 3] = new_a
        d = self.drip
        orig_p = self.orig[self.y0 : self.y1, self.x0 : self.x1]
        patch[..., :3] = patch[..., :3] * (1.0 - d[..., None]) + orig_p[..., :3] * d[
            ..., None
        ]
        patch[..., 3] = patch[..., 3] * (1.0 - d) + orig_p[..., 3] * d
        out[self.y0 : self.y1, self.x0 : self.x1] = patch
        return out

    def foggy_static(self, spec_a: float = 0.76) -> np.ndarray:
        """Lockup with empty glass + magician-ball cloud wisps."""
        return build_glass_lockup(clouds=True, spec_a=spec_a)

    def glass_crop(self, im: Image.Image, pad: int = 24) -> Image.Image:
        return im.crop(
            (
                int(VIEW_CX - VIEW_R - pad),
                int(VIEW_CY - VIEW_R - pad),
                int(VIEW_CX + VIEW_R + pad),
                int(VIEW_CY + VIEW_R + pad),
            )
        )


def _over(
    bg_rgb: np.ndarray,
    bg_a: np.ndarray,
    fg_rgb: np.ndarray,
    fg_a: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """Unpremultiplied alpha over. Alphas are 0..1."""
    out_a = np.clip(fg_a + bg_a * (1.0 - fg_a), 0.0, 1.0)
    num = fg_rgb * fg_a[..., None] + bg_rgb * (bg_a * (1.0 - fg_a))[..., None]
    out_rgb = np.divide(
        num,
        np.maximum(out_a[..., None], 1e-5),
        out=np.zeros_like(num),
        where=out_a[..., None] > 1e-5,
    )
    return out_rgb, out_a


def apply_empty_glass(g: Glass, rgb: np.ndarray, alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Punch the milky disc and overlay the empty-glass PNG (rim + window)."""
    hole = g.aa * (1.0 - g.drip)
    bg_a = np.clip(alpha / 255.0, 0.0, 1.0) * (1.0 - hole)
    eg = g.empty_glass
    fg_a = np.clip(eg[..., 3] / 255.0, 0.0, 1.0) * (1.0 - g.drip)
    out_rgb, out_a = _over(rgb, bg_a, eg[..., :3], fg_a)
    d = g.drip_put
    orig_p = g.orig[g.y0 : g.y1, g.x0 : g.x1]
    out_rgb = out_rgb * (1.0 - d)[..., None] + orig_p[..., :3] * d[..., None]
    out_a = np.maximum(out_a * (1.0 - d), orig_p[..., 3] / 255.0 * d)
    return out_rgb, out_a


def apply_clouds(g: Glass, rgb: np.ndarray, a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Magician-ball wisps in the clear interior. Window/rim stay on top."""
    hole = g.aa * (1.0 - g.drip)
    glass_a = np.clip(g.empty_glass[..., 3] / 255.0, 0.0, 1.0) * (1.0 - g.drip)
    clear = hole * (1.0 - glass_a)
    k = np.clip(g.clouds * g.cloud_lit, 0.0, 1.0)
    mist_hi = np.array([236.0, 242.0, 248.0], dtype=np.float32)
    mist_lo = np.array([168.0, 180.0, 196.0], dtype=np.float32)
    mist = mist_lo * (1.0 - k)[..., None] + mist_hi * k[..., None]
    base_a = 0.02 + 0.08 * (g.rad**1.8)
    cloud_a = g.clouds * 0.30
    fres = ((1.0 - g.z) ** 2.5) * 0.10
    fog_a = np.clip(base_a + cloud_a + fres, 0.0, 0.55) * clear
    rgb, a = _over(rgb, a, mist, fog_a)
    d = g.drip_put
    orig_p = g.orig[g.y0 : g.y1, g.x0 : g.x1]
    rgb = rgb * (1.0 - d)[..., None] + orig_p[..., :3] * d[..., None]
    a = np.maximum(a * (1.0 - d), orig_p[..., 3] / 255.0 * d)
    return rgb, a


def build_glass_lockup(clouds: bool = True, spec_a: float = 0.76) -> np.ndarray:
    """High-res lockup with the empty glass and optional magician-ball wisps.

    Slime/charge still read static_fog.png. Fog still and galaxy use this.
    """
    (spec_a,)  # window lives in the empty-glass PNG
    g = Glass()
    out = g.orig.copy()
    y0, y1, x0, x1 = g.y0, g.y1, g.x0, g.x1
    patch = out[y0:y1, x0:x1]
    rgb, a = apply_empty_glass(g, patch[..., :3], patch[..., 3])
    if clouds:
        rgb, a = apply_clouds(g, rgb, a)
    out[y0:y1, x0:x1, :3] = rgb
    out[y0:y1, x0:x1, 3] = np.clip(a * 255.0, 0.0, 255.0)
    return out


def write_glass_fog(dest: Path | None = None) -> Path:
    dest = dest or FOG_PNG
    dest.parent.mkdir(parents=True, exist_ok=True)
    save_rgba(build_glass_lockup(), dest)
    print(f"wrote {dest}")
    return dest


def checkerboard(im: Image.Image, cell: int = 24) -> Image.Image:
    w, h = im.size
    yy, xx = np.ogrid[:h, :w]
    chk = ((xx // cell) + (yy // cell)) % 2
    pix = np.zeros((h, w, 4), dtype=np.uint8)
    pix[chk == 0] = (38, 38, 42, 255)
    pix[chk == 1] = (22, 22, 24, 255)
    bg = Image.fromarray(pix, "RGBA")
    return Image.alpha_composite(bg, im.convert("RGBA"))


_PNG_SIG = b"\x89PNG\r\n\x1a\n"


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def _png_idat_bytes(png: bytes) -> bytes:
    assert png[:8] == _PNG_SIG
    pos = 8
    idat = bytearray()
    while pos < len(png):
        n = struct.unpack_from(">I", png, pos)[0]
        tag = png[pos + 4 : pos + 8]
        data = png[pos + 8 : pos + 8 + n]
        if tag == b"IDAT":
            idat.extend(data)
        elif tag == b"IEND":
            break
        pos += 12 + n
    if not idat:
        raise RuntimeError("PNG had no IDAT")
    return bytes(idat)


def _png_idat(im: Image.Image) -> bytes:
    """Zlib image payload from a Pillow PNG (concatenated IDAT)."""
    buf = io.BytesIO()
    im.save(buf, format="PNG", compress_level=9, optimize=True)
    return _png_idat_bytes(buf.getvalue())


def encode_apng_gif(frames_dir: Path, dest: Path, fps: int) -> None:
    """Lossless APNG: full first frame, later frames only the dirty glass rect.

    The lockup is pinned. Named .gif for the existing pipeline; paletted GIF
    cannot keep the fog alpha.
    """
    paths = sorted(frames_dir.glob("frame_*.png"))
    if not paths:
        raise FileNotFoundError(f"no frames in {frames_dir}")
    dest.parent.mkdir(parents=True, exist_ok=True)

    first = Image.open(paths[0]).convert("RGBA")
    canvas = first.size
    seq = 0

    def fctl(fw: int, fh: int, x: int, y: int) -> bytes:
        nonlocal seq
        # dispose 0 = none, blend 0 = source (replace the rect)
        data = struct.pack(">IIIIIHHBB", seq, fw, fh, x, y, 1, int(fps), 0, 0)
        seq += 1
        return _png_chunk(b"fcTL", data)

    def fdat(payload: bytes) -> bytes:
        nonlocal seq
        data = struct.pack(">I", seq) + payload
        seq += 1
        return _png_chunk(b"fdAT", data)

    ihdr = struct.pack(">IIBBBBB", canvas[0], canvas[1], 8, 6, 0, 0, 0)
    max_box = [0, 0]
    with dest.open("wb") as fp:
        fp.write(_PNG_SIG)
        fp.write(_png_chunk(b"IHDR", ihdr))
        fp.write(_png_chunk(b"acTL", struct.pack(">II", len(paths), 0)))
        fp.write(fctl(canvas[0], canvas[1], 0, 0))
        fp.write(_png_chunk(b"IDAT", _png_idat(first)))

        prev = first
        for i, path in enumerate(paths[1:], start=1):
            cur = Image.open(path).convert("RGBA")
            if cur.size != canvas:
                raise ValueError(f"{path.name} size {cur.size} != {canvas}")
            bbox = ImageChops.subtract_modulo(cur, prev).getbbox(alpha_only=False)
            if bbox is None:
                bbox = (0, 0, 1, 1)
            x0, y0, x1, y1 = bbox
            max_box[0] = max(max_box[0], x1 - x0)
            max_box[1] = max(max_box[1], y1 - y0)
            crop = cur.crop(bbox)
            fp.write(fctl(x1 - x0, y1 - y0, x0, y0))
            fp.write(fdat(_png_idat(crop)))
            prev = cur
            if i % 30 == 0:
                print(f"  pin {i+1}/{len(paths)} dirty={x1-x0}x{y1-y0}")
        fp.write(_png_chunk(b"IEND", b""))

    print(
        f"wrote {dest}  {dest.stat().st_size / 1e6:.1f} MB  "
        f"pinned canvas {canvas[0]}x{canvas[1]}, max dirty {max_box[0]}x{max_box[1]}"
    )
