#!/usr/bin/env python3
"""Stars loop: firework disc in Ref-window, on Base, then glass."""
from __future__ import annotations

import numpy as np
from PIL import Image

from gif89a import N_FRAMES, render_kind
from stack import WIN_D, disc_grid, disc_layer


def envelope(t: float, start: float, dur: float) -> float:
    x = (t - start) % 1.0
    if x >= dur:
        return 0.0
    u = x / dur
    if u < 0.10:
        return float((u / 0.10) ** 0.45)
    if u < 0.70:
        return 1.0
    return float(((1.0 - u) / 0.30) ** 1.35)


def flash(t: float, start: float) -> float:
    x = (t - start) % 1.0
    if x > 0.08:
        return 0.0
    return float(np.exp(-(x / 0.028) ** 2))


class Stars:
    def __init__(self) -> None:
        self.nx, self.ny, self.rad, self.circ = disc_grid(WIN_D)
        rng = np.random.default_rng(11)
        stops: list[dict] = []

        def place() -> tuple[float, float, float]:
            for _ in range(40):
                p = rng.uniform(-1.0, 1.0, 3)
                r = float(np.linalg.norm(p))
                if 0.08 < r < 0.78:
                    return float(p[0]), float(p[1]), float(p[2])
            return 0.0, 0.0, 0.2

        def add_stop(x, y, z, start, dur, sig, gain, color, hue):
            stops.append(
                {
                    "x": float(x),
                    "y": float(y),
                    "z": float(z),
                    "start": float(start) % 1.0,
                    "dur": float(dur),
                    "sig": float(sig),
                    "gain": float(gain),
                    "color": color,
                    "hue": float(hue),
                }
            )

        for _ in range(12):
            t0 = float(rng.random())
            ox, oy, oz = place()
            color = "orange" if rng.random() < 0.5 else "green"
            n = int(rng.integers(3, 7))
            for k in range(n):
                j = rng.normal(0.0, 0.16, 3)
                x, y, z = ox + j[0], oy + j[1], oz + j[2]
                if x * x + y * y + z * z > 0.82:
                    continue
                big = k == 0 and rng.random() < 0.50
                sig = (
                    float(rng.uniform(0.070, 0.125))
                    if big
                    else float(rng.uniform(0.016, 0.034))
                )
                add_stop(
                    x,
                    y,
                    z,
                    t0 + float(rng.uniform(0.0, 0.05)),
                    rng.uniform(0.20, 0.58),
                    sig,
                    rng.uniform(0.85, 1.35),
                    color,
                    rng.uniform(-0.08, 0.10),
                )
        for i in range(16):
            x, y, z = place()
            big = i < 5
            add_stop(
                x,
                y,
                z,
                rng.random(),
                rng.uniform(0.16, 0.52),
                rng.uniform(0.068, 0.130) if big else rng.uniform(0.014, 0.028),
                rng.uniform(0.75, 1.25),
                "orange" if rng.random() < 0.5 else "green",
                rng.uniform(-0.10, 0.12),
            )
        self.stops = stops

    def _splat(self, cx: float, cy: float, sig: float) -> np.ndarray:
        d2 = (self.nx - cx) ** 2 + (self.ny - cy) ** 2
        halo = np.exp(-d2 / (2.0 * (sig * 1.15) ** 2))
        core = np.exp(-d2 / (2.0 * (sig * 0.32) ** 2))
        return np.clip(halo * 0.28 + core, 0.0, 1.0) * self.circ

    def composite(self, t: float) -> np.ndarray:
        rgb = np.zeros((WIN_D, WIN_D, 3), dtype=np.float32)
        rgb[..., 0] = 16.0
        rgb[..., 1] = 20.0
        rgb[..., 2] = 26.0
        rgb *= self.circ[..., None]
        for s in self.stops:
            env = envelope(t, s["start"], s["dur"])
            if env <= 1e-4:
                continue
            fl = flash(t, s["start"])
            depth = np.clip(0.55 + 0.55 * s["z"], 0.35, 1.15)
            blob = self._splat(s["x"], s["y"], s["sig"] * (0.85 + 0.25 * s["z"]))
            h = np.clip(1.0 + s["hue"], 0.85, 1.12)
            if s["color"] == "orange":
                halo_c = np.array([190.0 * h, 58.0, 8.0], dtype=np.float32)
                core_c = np.array([255.0, 168.0 * h, 48.0], dtype=np.float32)
                flash_c = np.array([255.0, 230.0, 175.0], dtype=np.float32)
            else:
                halo_c = np.array([20.0, 170.0 * h, 36.0], dtype=np.float32)
                core_c = np.array([160.0, 255.0, 150.0 * h], dtype=np.float32)
                flash_c = np.array([230.0, 255.0, 210.0], dtype=np.float32)
            amt = env * s["gain"] * depth
            rgb += blob[..., None] * (halo_c * (0.45 * amt) + core_c * (1.25 * amt))
            if fl > 0.02:
                rgb += (blob**0.7)[..., None] * flash_c * (fl * 1.15 * s["gain"])
        rgb = np.clip(rgb, 0.0, 255.0)
        layer = np.dstack([rgb, self.circ * 255.0])
        im = Image.fromarray(np.clip(layer, 0, 255).astype(np.uint8), "RGBA")
        return disc_layer(im)

    def sprite(self, t: float) -> Image.Image:
        return self.composite(t)


def main() -> None:
    scene = Stars()
    render_kind("stars", N_FRAMES, scene.sprite, "stars")


if __name__ == "__main__":
    main()
