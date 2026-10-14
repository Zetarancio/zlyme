#!/usr/bin/env python3
"""Move/resize only the ring and its drips onto Ref-window. Text stays put."""
from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = Path("/home/ale/Downloads/DISPOSABLE/New logo/Bases")
BASES = HERE / "Bases"
WINDOW_PATH = HERE / "Ref-window.png"


def window_circle() -> tuple[float, float, float]:
    win = np.array(Image.open(WINDOW_PATH).convert("L"))
    ys, xs = np.where(win > 127)
    cx, cy = float(xs.mean()), float(ys.mean())
    r = float(np.hypot(xs.astype(np.float64) - cx, ys.astype(np.float64) - cy).max())
    return cx, cy, r


def _flood_exterior(empty: np.ndarray) -> np.ndarray:
    h, w = empty.shape
    ext = np.zeros_like(empty, dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        if empty[0, x]:
            ext[0, x] = True
            q.append((0, x))
        if empty[h - 1, x]:
            ext[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if empty[y, 0] and not ext[y, 0]:
            ext[y, 0] = True
            q.append((y, 0))
        if empty[y, w - 1] and not ext[y, w - 1]:
            ext[y, w - 1] = True
            q.append((y, w - 1))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and empty[ny, nx] and not ext[ny, nx]:
                ext[ny, nx] = True
                q.append((ny, nx))
    return ext


def porthole(a: np.ndarray, a_min: int = 40) -> tuple[float, float, float]:
    empty = a < a_min
    interior = empty & ~_flood_exterior(empty)
    ys, xs = np.where(interior)
    if xs.size < 200:
        raise RuntimeError("no porthole")
    h, w = a.shape
    labels = np.zeros((h, w), dtype=np.int32)
    best_n = 0
    best_cells: list[tuple[int, int]] = []
    for y, x in zip(ys, xs):
        if labels[y, x]:
            continue
        q: deque[tuple[int, int]] = deque([(y, x)])
        labels[y, x] = 1
        cells = [(y, x)]
        while q:
            yy, xx = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = yy + dy, xx + dx
                if 0 <= ny < h and 0 <= nx < w and interior[ny, nx] and labels[ny, nx] == 0:
                    labels[ny, nx] = 1
                    q.append((ny, nx))
                    cells.append((ny, nx))
        if len(cells) > best_n:
            best_n = len(cells)
            best_cells = cells
    cy = float(np.mean([c[0] for c in best_cells]))
    cx = float(np.mean([c[1] for c in best_cells]))
    r = float(max(np.hypot(c[1] - cx, c[0] - cy) for c in best_cells))
    if not (80.0 <= r <= 220.0):
        raise RuntimeError(f"implausible porthole r={r:.1f} at ({cx:.1f},{cy:.1f})")
    return cx, cy, r


def outer_radius(a: np.ndarray, cx: float, cy: float, a_min: int = 40) -> float:
    """Metal outer radius; skip the bottom so drips do not inflate it."""
    h, w = a.shape
    hits: list[float] = []
    for th in np.linspace(0.0, 2.0 * np.pi, 360, endpoint=False):
        if abs((th - np.pi / 2.0 + np.pi) % (2.0 * np.pi) - np.pi) < 0.85:
            continue
        cth, sth = float(np.cos(th)), float(np.sin(th))
        inner = None
        outer = None
        for rad in np.arange(40.0, 280.0, 0.5):
            xi = int(round(cx + rad * cth))
            yi = int(round(cy + rad * sth))
            if not (0 <= xi < w and 0 <= yi < h):
                break
            if a[yi, xi] > a_min:
                if inner is None:
                    inner = rad
                outer = rad
            elif inner is not None and rad > inner + 8.0:
                break
        if outer is not None:
            hits.append(outer)
    if not hits:
        raise RuntimeError("no outer radius")
    return float(np.median(hits))


def _components(mask: np.ndarray) -> list[np.ndarray]:
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out: list[np.ndarray] = []
    ys, xs = np.where(mask)
    for y, x in zip(ys, xs):
        if seen[y, x]:
            continue
        q: deque[tuple[int, int]] = deque([(y, x)])
        seen[y, x] = True
        cells = [(y, x)]
        while q:
            yy, xx = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = yy + dy, xx + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
                    cells.append((ny, nx))
        cc = np.zeros_like(mask)
        for cy, cx in cells:
            cc[cy, cx] = True
        out.append(cc)
    return out


def ring_and_word(a: np.ndarray, cx: float, cy: float, rin: float) -> tuple[np.ndarray, np.ndarray]:
    vis = a >= 40
    h, w = vis.shape
    outer = outer_radius(a, cx, cy)
    yy, xx = np.ogrid[:h, :w]
    d = np.hypot(xx - cx, yy - cy)
    annulus = vis & (d <= outer * 1.14)

    row = vis.sum(axis=1)
    wide = np.where(row > 400)[0]
    if wide.size == 0:
        raise RuntimeError("no word band")
    y_wide = int(wide[0])

    word_body = vis.copy()
    word_body[:y_wide, :] = False

    band = vis & ~annulus
    band[y_wide:, :] = False
    band[: max(0, int(cy + rin * 0.4)), :] = False

    ring = annulus.copy()
    dilated_annulus = d <= (outer * 1.14 + 2.0)
    for cc in _components(band):
        touch_ring = bool((cc & dilated_annulus).any())
        touch_word = False
        ys, xs = np.where(cc)
        for y, x in zip(ys, xs):
            if y + 1 < h and word_body[y + 1, x]:
                touch_word = True
                break
        if touch_ring and not touch_word:
            ring |= cc
        elif touch_ring and touch_word:
            # Drip merged onto a letter: take pixels that still belong to
            # the drip (reachable from the ring) and stop at the letter.
            q: deque[tuple[int, int]] = deque()
            take = np.zeros_like(cc)
            for y, x in zip(*np.where(cc & dilated_annulus)):
                take[y, x] = True
                q.append((y, x))
            while q:
                y, x = q.popleft()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if not (0 <= ny < h and 0 <= nx < w):
                        continue
                    if not cc[ny, nx] or take[ny, nx]:
                        continue
                    if word_body[ny, nx]:
                        continue
                    if ny + 1 < h and word_body[ny + 1, nx]:
                        continue
                    take[ny, nx] = True
                    q.append((ny, nx))
            ring |= take
        elif (not touch_word) and int(cc.sum()) < 400 and (d[cc].min() < outer * 1.7):
            # Isolated splashes around the circle, not letter tops.
            ring |= cc

    word = vis & ~ring
    return ring, word


def align(im: Image.Image, dst_cx: float, dst_cy: float, dst_r: float):
    arr = np.array(im.convert("RGBA"))
    a = arr[..., 3]
    cx, cy, rin = porthole(a)
    scale = dst_r / max(rin, 1e-6)
    if not (0.7 <= scale <= 1.4):
        raise RuntimeError(f"implausible scale {scale:.3f}")
    ring_m, word_m = ring_and_word(a, cx, cy, rin)
    ring = arr.copy()
    ring[~ring_m] = 0
    word = arr.copy()
    word[~word_m] = 0
    inv = 1.0 / scale
    affine = (
        inv,
        0.0,
        cx - dst_cx * inv,
        0.0,
        inv,
        cy - dst_cy * inv,
    )
    ring_im = Image.fromarray(ring, "RGBA").transform(
        im.size,
        Image.Transform.AFFINE,
        affine,
        resample=Image.Resampling.BICUBIC,
        fillcolor=(0, 0, 0, 0),
    )
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    # Word first and unmoved so lettering cannot be cut. Drips composite on top.
    out.alpha_composite(Image.fromarray(word, "RGBA"))
    out.alpha_composite(ring_im)
    return out, cx, cy, rin, scale


def main() -> None:
    dst_cx, dst_cy, dst_r = window_circle()
    print(f"target window=({dst_cx:.1f},{dst_cy:.1f}) r={dst_r:.1f}")
    src_dir = SRC if SRC.is_dir() else BASES
    for path in sorted(src_dir.glob("Base_*.png")):
        src = Image.open(path).convert("RGBA")
        cx0, cy0, r0 = porthole(np.array(src)[..., 3])
        scale0 = dst_r / max(r0, 1e-6)
        shift0 = float(np.hypot(cx0 - dst_cx, cy0 - dst_cy))
        dest = BASES / path.name
        if abs(scale0 - 1.0) < 0.012 and shift0 < 1.5:
            dest.write_bytes(path.read_bytes())
            print(
                f"{path.name}: already on window "
                f"({cx0:.1f},{cy0:.1f}) r={r0:.1f}  skip"
            )
            continue
        out, cx, cy, rin, scale = align(src, dst_cx, dst_cy, dst_r)
        ncx, ncy, nr = porthole(np.array(out)[..., 3])
        if abs(ncx - dst_cx) > 2.5 or abs(ncy - dst_cy) > 2.5 or abs(nr - dst_r) > 3.0:
            raise RuntimeError(
                f"{path.name} still off: ({ncx:.1f},{ncy:.1f}) r={nr:.1f}"
            )
        dest = BASES / path.name
        out.save(dest)
        print(
            f"{path.name}: hole ({cx:.1f},{cy:.1f}) r={rin:.1f} -> "
            f"({ncx:.1f},{ncy:.1f}) r={nr:.1f}  scale={scale:.4f}"
        )


if __name__ == "__main__":
    main()
