#!/usr/bin/env python3
"""Galaxy loop: rotation clip in Ref-window, on Base, then glass."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gif89a import N_FRAMES, render_kind
from stack import GALAXY_GIF, WIN_D, disc_layer, stack

ROLL_DEG = -50.0


def _load_src_frames(path: Path) -> list[Image.Image]:
    im = Image.open(path)
    frames: list[Image.Image] = []
    for i in range(getattr(im, "n_frames", 1)):
        im.seek(i)
        im.load()
        frames.append(im.convert("RGBA").copy())
    if len(frames) < 2:
        raise RuntimeError(f"{path} has {len(frames)} frame(s)")
    return frames


class Galaxy:
    def __init__(self) -> None:
        src = _load_src_frames(GALAXY_GIF)
        self.frames = [
            fr.resize((WIN_D, WIN_D), Image.Resampling.LANCZOS).rotate(
                ROLL_DEG,
                resample=Image.Resampling.BICUBIC,
                fillcolor=(0, 0, 0, 0),
            )
            for fr in src
        ]
        self.n = len(self.frames)

    def sprite(self, t: float) -> Image.Image:
        i = int(t * self.n + 1e-9) % self.n
        return disc_layer(self.frames[i])

    def composite(self, t: float) -> np.ndarray:
        return stack(self.sprite(t))


def main() -> None:
    scene = Galaxy()
    render_kind("galaxy", N_FRAMES, scene.sprite, "galaxy")
    wrap = scene.composite(1.0)
    first = scene.composite(0.0)
    d = np.abs(first.astype(np.int16) - wrap.astype(np.int16))
    print(f"loop seam max|Δ|={int(d.max())} mean|Δ|={float(d.mean()):.4f}")


if __name__ == "__main__":
    main()
