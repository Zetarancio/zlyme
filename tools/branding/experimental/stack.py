#!/usr/bin/env python3
"""Lockup stack for tools/branding/experimental.

Ref-window.png is already registered on Base.png. Animation fills that
disc; Ref-glass.png is scaled onto the same circle; both sit on Base.

    window animation + glass (inside the circle only)  →  Base.png on top
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
BASES_DIR = HERE / "Bases"
BASE_PATH = HERE / "Base.png"
WINDOW_PATH = HERE / "Ref-window.png"
GLASS_PATH = HERE / "Ref-glass.png"
SLIME_SRC = HERE / "Ref-slime.png"
GALAXY_GIF = HERE / "zlyme_galaxy_3d_rotation_3s_200px_30fps.gif"
ACTIVE_BASE = BASE_PATH


def _circle(vis: np.ndarray) -> tuple[float, float, float]:
    ys, xs = np.where(vis)
    if xs.size == 0:
        raise RuntimeError("empty circle mask")
    cx, cy = float(xs.mean()), float(ys.mean())
    r = float(np.hypot(xs.astype(np.float64) - cx, ys.astype(np.float64) - cy).max())
    return cx, cy, r


def _strip_red_matte(im: Image.Image) -> Image.Image:
    """Drop chroma-key red only. Keep orange metal, glass fog, and rim glow."""
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    matte = (a > 0.0) & (r > 90.0) & (g < 40.0) & (b < 24.0)
    arr[..., 3] = np.where(matte, 0.0, a)
    arr[arr[..., 3] < 8.0, 3] = 0.0
    arr[arr[..., 3] == 0.0, :3] = 0.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _clear_inner_hole(im: Image.Image) -> Image.Image:
    """Keep Ref-glass's inner opening fully transparent.

    The pane is a torus: fog and metal stay, the interior (plus leftover
    chroma-key on that lip) is punched by flooding from the centre.
    """
    from collections import deque

    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    h, w = arr.shape[:2]
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    open_px = (a < 16.0) | ((r > 90.0) & (g < 40.0) & (b < 24.0))
    cy, cx = h // 2, w // 2
    if not open_px[cy, cx]:
        found = False
        for rad in range(1, 80):
            for deg in range(0, 360, 12):
                th = np.deg2rad(deg)
                yi = int(round(cy + rad * np.sin(th)))
                xi = int(round(cx + rad * np.cos(th)))
                if 0 <= yi < h and 0 <= xi < w and open_px[yi, xi]:
                    cy, cx = yi, xi
                    found = True
                    break
            if found:
                break
        if not open_px[cy, cx]:
            return im
    hole = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque([(cy, cx)])
    hole[cy, cx] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not hole[ny, nx] and open_px[ny, nx]:
                hole[ny, nx] = True
                q.append((ny, nx))
    if int(hole.sum()) > (h * w) // 2:
        raise RuntimeError("glass inner-hole flood leaked through the torus")
    arr[hole, 3] = 0.0
    arr[arr[..., 3] == 0.0, :3] = 0.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _outer_circle(a: np.ndarray, a_min: int = 40) -> tuple[float, float, float]:
    """Geometric centre and mean radius of the outer rim, not mass centroid."""
    vis = a > a_min
    ys, xs = np.where(vis)
    if xs.size == 0:
        raise RuntimeError("empty glass")
    cx, cy = float(xs.mean()), float(ys.mean())
    h, w = a.shape
    rmax = float(np.hypot(xs.astype(np.float64) - cx, ys.astype(np.float64) - cy).max()) + 8.0
    hx, hy = [], []
    for th in np.linspace(0.0, 2.0 * np.pi, 720, endpoint=False):
        cth, sth = float(np.cos(th)), float(np.sin(th))
        hit = None
        for rad in np.arange(rmax, 8.0, -0.5):
            xi = int(round(cx + rad * cth))
            yi = int(round(cy + rad * sth))
            if not (0 <= xi < w and 0 <= yi < h):
                continue
            if a[yi, xi] > a_min:
                hit = (float(xi), float(yi))
                break
        if hit is not None:
            hx.append(hit[0])
            hy.append(hit[1])
    if len(hx) < 16:
        raise RuntimeError("glass has no outer edge")
    ocx, ocy = float(np.mean(hx)), float(np.mean(hy))
    r = float(np.hypot(np.array(hx) - ocx, np.array(hy) - ocy).mean())
    return ocx, ocy, r


def _clip_circle(im: Image.Image, cx: float, cy: float, r: float) -> Image.Image:
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    h, w = arr.shape[:2]
    yy, xx = np.ogrid[:h, :w]
    d = np.hypot(xx - cx, yy - cy)
    arr[..., 3] *= np.clip((r + 1.0 - d) / 2.0, 0.0, 1.0)
    arr[arr[..., 3] == 0.0, :3] = 0.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _base_ring_outer(cx: float, cy: float, a: np.ndarray) -> float:
    """Outer radius of Base.png's metal ring (ignores drips via median)."""
    h, w = a.shape
    hits: list[float] = []
    for th in np.linspace(0.0, 2.0 * np.pi, 360, endpoint=False):
        cth, sth = float(np.cos(th)), float(np.sin(th))
        inner = None
        outer = None
        for rad in np.arange(80.0, 230.0, 0.5):
            xi = int(round(cx + rad * cth))
            yi = int(round(cy + rad * sth))
            if not (0 <= xi < w and 0 <= yi < h):
                break
            if a[yi, xi] > 40:
                if inner is None:
                    inner = rad
                outer = rad
            elif inner is not None and rad > inner + 8.0:
                break
        if outer is not None:
            hits.append(outer)
    if not hits:
        raise RuntimeError("Base.png has no ring around the window")
    return float(np.median(hits))


def _place(
    src: Image.Image,
    src_cx: float,
    src_cy: float,
    src_r: float,
    canvas: tuple[int, int],
    dst_cx: float,
    dst_cy: float,
    dst_r: float,
) -> Image.Image:
    scale = dst_r / max(src_r, 1e-6)
    nw = max(1, int(round(src.size[0] * scale)))
    nh = max(1, int(round(src.size[1] * scale)))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = int(round(dst_cx - src_cx * scale))
    y = int(round(dst_cy - src_cy * scale))
    layer.alpha_composite(resized, (x, y))
    return layer


# Base.png is the lockup. Do not recolor or chroma-key it; the dark metal
# and orange letters are the reference. Ref-window is already registered.
_BASE = Image.open(BASE_PATH).convert("RGBA")
_CANVAS = _BASE.size
_WINDOW_L = np.array(Image.open(WINDOW_PATH).convert("L"), dtype=np.float32)
WIN_CX, WIN_CY, WIN_R = _circle(_WINDOW_L > 127.0)
WIN_D = int(round(2.0 * WIN_R))
_WINDOW_A = _WINDOW_L / 255.0
# Solid lockup only. Low-alpha fringe around the word and ring is orange
# in RGB; GIF 1-bit alpha would paint it as extra contour pixels.
_LOCKUP = (np.array(_BASE)[..., 3] >= 128) | (_WINDOW_L > 127.0)

_METAL_L = np.array(Image.open(HERE / "Ref-metallic-circle.png").convert("L"), dtype=np.float32)
RING_R = _base_ring_outer(WIN_CX, WIN_CY, _METAL_L)

# Ref-glass is a porthole: inner hole, foggy pane, metal ring. Punch the
# hole (and chroma-key) so the animation stays visible, then scale the
# outer rim onto Base's metal ring. Mapping onto the window squeezed the
# rivets over the disc and closed most of the opening.
_GLASS_SRC = _clear_inner_hole(_strip_red_matte(Image.open(GLASS_PATH)))
_G_CX, _G_CY, _G_R = _outer_circle(np.array(_GLASS_SRC)[..., 3])
GLASS_LAYER = _place(
    _GLASS_SRC, _G_CX, _G_CY, _G_R, _CANVAS, WIN_CX, WIN_CY, RING_R
)

print(
    f"stack  window=({WIN_CX:.1f},{WIN_CY:.1f}) r={WIN_R:.1f} d={WIN_D}  "
    f"glass outer=({_G_CX:.1f},{_G_CY:.1f}) r={_G_R:.1f} -> ring r={RING_R:.1f}"
)


def set_base(path: Path | None = None) -> None:
    """Swap the lockup PNG. Window/glass stay registered on Base.png."""
    global _BASE, _LOCKUP, ACTIVE_BASE
    path = BASE_PATH if path is None else Path(path)
    _BASE = Image.open(path).convert("RGBA")
    if _BASE.size != _CANVAS:
        _BASE = _BASE.resize(_CANVAS, Image.Resampling.LANCZOS)
    ACTIVE_BASE = path
    _LOCKUP = (np.array(_BASE)[..., 3] >= 128) | (_WINDOW_L > 127.0)


def each_base() -> list[tuple[str, Path]]:
    jobs = [("Base", BASE_PATH)]
    if BASES_DIR.is_dir():
        for p in sorted(BASES_DIR.glob("Base_*.png")):
            jobs.append((p.stem, p))
    return jobs


def gif_dest(kind: str, stem: str) -> Path:
    if stem == "Base":
        return OUT / f"zlyme_{kind}_loop.gif"
    return OUT / f"zlyme_{kind}_loop_{stem}.gif"


def _erode_alpha(im: Image.Image, n: int = 1) -> Image.Image:
    """Shrink coverage 1px so pane pixels cannot stick out from under Base."""
    arr = np.array(im.convert("RGBA"))
    a = arr[..., 3]
    for _ in range(n):
        m = a > 0
        nb = m.copy()
        nb[1:, :] &= m[:-1, :]
        nb[:-1, :] &= m[1:, :]
        nb[:, 1:] &= m[:, :-1]
        nb[:, :-1] &= m[:, 1:]
        a = np.where(nb, a, np.uint8(0))
    arr[..., 3] = a
    arr[a == 0, :3] = 0
    return Image.fromarray(arr, "RGBA")


def mask_to_window(layer: Image.Image) -> Image.Image:
    arr = np.array(layer.convert("RGBA"), dtype=np.float32)
    arr[..., 3] *= _WINDOW_A
    arr[arr[..., 3] == 0.0, :3] = 0.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def disc_layer(sprite: Image.Image) -> Image.Image:
    """Resize a circular sprite to the window and clip to Ref-window."""
    sprite = sprite.convert("RGBA").resize((WIN_D, WIN_D), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", _CANVAS, (0, 0, 0, 0))
    x = int(round(WIN_CX - WIN_D / 2.0))
    y = int(round(WIN_CY - WIN_D / 2.0))
    layer.alpha_composite(sprite, (x, y))
    return mask_to_window(layer)


def disc_grid(n: int) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    nx = (xx + 0.5) / n * 2.0 - 1.0
    ny = (yy + 0.5) / n * 2.0 - 1.0
    rad = np.hypot(nx, ny)
    alpha = np.clip((1.0 - rad) / 0.02, 0.0, 1.0)
    return nx, ny, rad, alpha


def stack(anim: Image.Image) -> np.ndarray:
    """Pane first, then Base.png on top.

    Animation and glass stay inside Ref-window. The word and outer ring
    are copied from Base; they are not re-masked, dithered, or redrawn.
    """
    if anim.size != _CANVAS:
        anim = disc_layer(anim)
    else:
        anim = mask_to_window(anim)
    pane = Image.new("RGBA", _CANVAS, (0, 0, 0, 0))
    pane.alpha_composite(anim)
    pane.alpha_composite(mask_to_window(GLASS_LAYER))
    pane = _erode_alpha(pane, 1)
    out = pane.copy()
    out.alpha_composite(_BASE)
    arr = np.array(out, dtype=np.float32)
    base = np.array(_BASE, dtype=np.float32)
    solid = base[..., 3] >= 128.0
    arr[solid] = base[solid]
    keep = solid | (_WINDOW_L > 127.0)
    arr[..., 3] = np.where(keep, arr[..., 3], 0.0)
    arr[arr[..., 3] == 0.0, :3] = 0.0
    return arr
