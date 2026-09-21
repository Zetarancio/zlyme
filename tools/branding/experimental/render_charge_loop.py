#!/usr/bin/env python3
"""Charging loop: green firework *stops* hanging inside the glass.

Spots pop on at random places, stay lit for a random hold, then die.
No falling rain — they hang in place like firework stars.

    python3 tools/branding/experimental/render_charge_loop.py --preview
    python3 tools/branding/experimental/render_charge_loop.py --encode
"""
from __future__ import annotations

import argparse
import shutil

import numpy as np
from PIL import Image

from glass import (
    OUT,
    VIEW_CX,
    VIEW_CY,
    VIEW_R,
    Glass,
    encode_apng_gif,
    smoothstep,
)

FRAMES = OUT / "charge_frames"
FPS = 30
N_FRAMES = 120


def envelope(t: float, start: float, dur: float) -> float:
    """Wrap-aware pop / hold / fade. The hold is the firework stop."""
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


class Charge:
    def __init__(self) -> None:
        self.g = Glass()
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

        # Clustered bursts — a burst is all green or all orange.
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

        # Loners, mixed colours, a few oversized.
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

    def empty(self) -> tuple[np.ndarray, np.ndarray]:
        fog = self.g.fog_rgb * 0.18 + np.array([16.0, 20.0, 26.0]) * 0.82
        rgb = self.g.polish(
            fog,
            fog_center=0.03,
            fog_rim=0.12,
            spec_gain=1.12,
            fresnel_gain=0.32,
        )
        a = 0.08 + 0.16 * (self.g.rad**1.4)
        a = np.maximum(a, self.g.spec * 0.78)
        a = np.maximum(a, ((1.0 - self.g.z) ** 2.4) * 0.24)
        a = np.clip(a, 0.0, 1.0) * 255.0 * self.g.interior
        return rgb, a

    def splat(self, cx: float, cy: float, sig: float) -> np.ndarray:
        hh, ww = self.g.nx.shape
        px = cx * VIEW_R + VIEW_CX - self.g.x0
        py = cy * VIEW_R + VIEW_CY - self.g.y0
        rad = max(2.0, sig * VIEW_R * 4.2)
        x0 = max(0, int(px - rad))
        x1 = min(ww, int(px + rad) + 1)
        y0 = max(0, int(py - rad))
        y1 = min(hh, int(py + rad) + 1)
        blob = np.zeros((hh, ww), dtype=np.float32)
        if x1 <= x0 or y1 <= y0:
            return blob
        yy, xx = np.ogrid[y0:y1, x0:x1]
        d2 = (xx - px) ** 2 + (yy - py) ** 2
        sig_px = sig * VIEW_R
        halo = np.exp(-d2 / (2.0 * (sig_px * 1.15) ** 2))
        core = np.exp(-d2 / (2.0 * (sig_px * 0.32) ** 2))
        blob[y0:y1, x0:x1] = np.clip(halo * 0.28 + core, 0.0, 1.0)
        return blob

    def render_patch(self, t: float) -> tuple[np.ndarray, np.ndarray]:
        rgb, alpha = self.empty()
        lights = np.zeros_like(rgb)
        cover = np.zeros(self.g.nx.shape, dtype=np.float32)

        active = []
        for s in self.stops:
            env = envelope(t, s["start"], s["dur"])
            if env <= 1e-4:
                continue
            active.append((s["z"], s, env, flash(t, s["start"])))
        active.sort(key=lambda q: q[0])  # back to front

        for z, s, env, fl in active:
            depth = np.clip(0.55 + 0.55 * z, 0.35, 1.15)
            blob = self.splat(s["x"], s["y"], s["sig"] * (0.85 + 0.25 * z))
            blob *= self.g.interior
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
            lights += blob[..., None] * (halo_c * (0.45 * amt) + core_c * (1.25 * amt))
            if fl > 0.02:
                lights += (blob ** 0.7)[..., None] * flash_c * (fl * 1.15 * s["gain"])
            cover = np.maximum(cover, blob * amt)

        rgb = np.clip(rgb + lights, 0.0, 255.0)
        rgb = self.g.polish(
            rgb,
            fog_center=0.04,
            fog_rim=0.14,
            spec_gain=1.10,
            fresnel_gain=0.30,
        )
        alpha = np.maximum(alpha, np.clip(cover, 0.0, 1.0) * 255.0)
        return rgb, alpha

    def composite(self, t: float) -> np.ndarray:
        rgb, a = self.render_patch(t)
        return self.g.composite(rgb, a)


def main() -> None:
    global N_FRAMES
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--encode", action="store_true")
    ap.add_argument("--frames", type=int, default=N_FRAMES)
    args = ap.parse_args()
    N_FRAMES = 8 if args.preview else args.frames

    scene = Charge()
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
            print(f"charge {i+1}/{n}")

    print(f"wrote {n} frames to {FRAMES}")
    if args.encode and not args.preview:
        encode_apng_gif(FRAMES, OUT / "zlyme_charge_loop.gif", FPS)


if __name__ == "__main__":
    main()
