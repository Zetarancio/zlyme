#!/usr/bin/env python3
"""Updater loop: the 3D galaxy rotation clip behind empty glass.

The source is already a 90-frame, 30 FPS circular disc. Scale it to the
lockup porthole and overlay the empty-glass PNG (rim + window) plus the
same magician-ball wisps as the fog still. No Hubble reprojection.

    python3 NOTES/LOGOANIM/render_galaxy_loop.py --preview
    python3 NOTES/LOGOANIM/render_galaxy_loop.py --encode
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from glass import (
    OUT,
    REFS,
    VIEW_CX,
    VIEW_CY,
    VIEW_R,
    Glass,
    _over,
    apply_clouds,
    encode_apng_gif,
)

GALAXY_GIF = REFS / "zlyme_galaxy_3d_rotation_3s_200px_30fps.gif"
FRAMES = OUT / "galaxy_frames"
FPS = 30
N_FRAMES = 90  # source is 3 s × 30 FPS
# Source major axis is ~35° from horizontal. Clockwise roll; -20 then
# another 30° in the same direction.
ROLL_DEG = -50.0


def _load_src_frames(path: Path) -> list[Image.Image]:
    im = Image.open(path)
    n = getattr(im, "n_frames", 1)
    frames: list[Image.Image] = []
    for i in range(n):
        im.seek(i)
        im.load()
        frames.append(im.convert("RGBA").copy())
    if len(frames) < 2:
        raise RuntimeError(f"{path} has {len(frames)} frame(s); need the rotation clip")
    return frames


class Galaxy:
    def __init__(self) -> None:
        self.g = Glass()
        src = _load_src_frames(GALAXY_GIF)
        # Map the 200px circular disc onto the lockup porthole (diameter 2·VIEW_R).
        d = int(round(2.0 * VIEW_R))
        self.d = d
        self.ox = int(round(VIEW_CX - d / 2.0 - self.g.x0))
        self.oy = int(round(VIEW_CY - d / 2.0 - self.g.y0))
        self.frames = [
            fr.resize((d, d), Image.Resampling.LANCZOS).rotate(
                ROLL_DEG,
                resample=Image.Resampling.BICUBIC,
                fillcolor=(0, 0, 0, 0),
            )
            for fr in src
        ]
        self.n = len(self.frames)

    def _placed(self, i: int) -> np.ndarray:
        g = self.g
        canvas = Image.new("RGBA", (g.x1 - g.x0, g.y1 - g.y0), (0, 0, 0, 0))
        canvas.alpha_composite(self.frames[i % self.n], (self.ox, self.oy))
        return np.asarray(canvas, dtype=np.float32)

    def composite(self, t: float) -> np.ndarray:
        """Galaxy in the hole; wisps in the clear pane; rim and window on top."""
        i = int(t * self.n + 1e-9) % self.n
        gal = self._placed(i)
        g = self.g
        gal_a = (gal[..., 3] / 255.0) * g.aa

        out = g.orig.copy()
        y0, y1, x0, x1 = g.y0, g.y1, g.x0, g.x1
        patch = out[y0:y1, x0:x1]
        hole = g.aa * (1.0 - g.drip)
        bg_a = np.clip(patch[..., 3] / 255.0, 0.0, 1.0) * (1.0 - hole)
        mid_rgb, mid_a = _over(patch[..., :3], bg_a, gal[..., :3], gal_a)
        eg = g.empty_glass
        eg_a = np.clip(eg[..., 3] / 255.0, 0.0, 1.0) * (1.0 - g.drip)
        top_rgb, top_a = _over(mid_rgb, mid_a, eg[..., :3], eg_a)
        top_rgb, top_a = apply_clouds(g, top_rgb, top_a)
        patch[..., :3] = top_rgb
        patch[..., 3] = np.clip(top_a * 255.0, 0.0, 255.0)
        out[y0:y1, x0:x1] = patch
        return out


def main() -> None:
    global N_FRAMES
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--encode", action="store_true")
    ap.add_argument("--frames", type=int, default=N_FRAMES)
    args = ap.parse_args()
    N_FRAMES = 8 if args.preview else args.frames

    scene = Galaxy()
    if FRAMES.exists() and not args.preview:
        shutil.rmtree(FRAMES)
    FRAMES.mkdir(parents=True, exist_ok=True)

    n = 8 if args.preview else N_FRAMES
    for i in range(n):
        t = i / n
        arr = scene.composite(t)
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
        im.save(FRAMES / f"frame_{i:04d}.png", compress_level=1)
        if i % 10 == 0 or args.preview:
            print(f"galaxy {i+1}/{n}")

    if args.preview:
        wrap = Image.fromarray(
            np.clip(scene.composite(1.0), 0, 255).astype(np.uint8), "RGBA"
        )
        first = Image.open(FRAMES / "frame_0000.png")
        d = np.abs(np.array(first, dtype=np.int16) - np.array(wrap, dtype=np.int16))
        print(f"loop seam max|Δ|={int(d.max())} mean|Δ|={float(d.mean()):.4f}")
        first.save(OUT / "galaxy_still.png")

    print(f"wrote {n} frames to {FRAMES}")
    if args.encode and not args.preview:
        encode_apng_gif(FRAMES, OUT / "zlyme_galaxy_loop.gif", FPS)


if __name__ == "__main__":
    main()
