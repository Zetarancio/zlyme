#!/usr/bin/env python3
"""Slime loop: warp Ref-slime into Ref-window, stack on Base, then glass."""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter

from gif89a import render_kind
from stack import SLIME_SRC, WIN_D, disc_grid, disc_layer

N_FRAMES = 135
SWIRL_AMP = 0.24
WARP_AMP = 0.078
BREATHE_AMP = 0.018
CAUSTIC_AMP = 0.13
MOTION_BLUR_SAMPLES = 2


def _bilinear(tex: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = tex.shape[:2]
    x = np.clip(x, 0.0, w - 1.001)
    y = np.clip(y, 0.0, h - 1.001)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    ax = (x - x0)[..., None]
    ay = (y - y0)[..., None]
    return (tex[y0, x0] * (1.0 - ax) + tex[y0, x1] * ax) * (1.0 - ay) + (
        tex[y1, x0] * (1.0 - ax) + tex[y1, x1] * ax
    ) * ay


class Scene:
    def __init__(self) -> None:
        src = np.array(Image.open(SLIME_SRC).convert("RGBA"), dtype=np.float32)
        rgb = src[..., :3]
        alpha = src[..., 3] / 255.0
        ys, xs = np.where(alpha > 0.15)
        self.cx = float(xs.mean())
        self.cy = float(ys.mean())
        # Inset from the photo's own glass shell so the window fills with goo.
        self.sr = float(np.percentile(np.hypot(xs - self.cx, ys - self.cy), 99.0)) * 0.82
        lum = rgb.mean(axis=2)
        window = np.clip((lum - 195.0) / 40.0, 0.0, 1.0)
        orange = np.array([252.0, 118.0, 28.0], dtype=np.float32)
        rgb = rgb * (1.0 - window[..., None] * 0.75) + orange * (window[..., None] * 0.75)
        sharp = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
        sharp = sharp.filter(ImageFilter.UnsharpMask(radius=2.2, percent=70, threshold=2))
        self.tex = np.array(sharp, dtype=np.float32)
        self.valid = alpha
        self.nx, self.ny, self.rad, self.circ = disc_grid(WIN_D)
        pin = np.clip((0.965 - self.rad) / 0.12, 0.0, 1.0)
        slip = (self.rad**2) * ((1.0 - np.clip(self.rad, 0.0, 1.0)) ** 2) * 16.0
        self.motion = np.clip(0.18 + 0.82 * slip, 0.0, 1.0) * pin * self.circ

    def _uv(self, t: float) -> tuple[np.ndarray, np.ndarray]:
        tau = 2.0 * np.pi * t
        nx, ny, rad, mot = self.nx, self.ny, self.rad, self.motion
        swirl = (
            SWIRL_AMP * np.sin(tau)
            + 0.07 * np.sin(2.0 * tau + 1.15)
            + 0.03 * np.sin(tau + 4.2 * rad)
        ) * mot
        c, s = np.cos(swirl), np.sin(swirl)
        rx = nx * c - ny * s
        ry = nx * s + ny * c
        wx = mot * WARP_AMP * (
            0.90 * np.sin(tau + 1.35 * ny + 0.45 * nx)
            + 0.48 * np.sin(2.0 * tau + 2.55 * nx)
            + 0.32 * np.cos(tau + 5.1 * rad)
        )
        wy = mot * WARP_AMP * (
            0.86 * np.cos(tau + 1.18 * nx - 0.52 * ny)
            + 0.46 * np.cos(2.0 * tau + 2.25 * ny)
            + 0.30 * np.sin(tau + 3.6 * nx * ny)
        )
        breathe = 1.0 + BREATHE_AMP * np.sin(tau + 2.1 * np.arctan2(ny, nx)) * mot
        sx = (rx + wx) * breathe
        sy = (ry + wy) * breathe
        sr = np.hypot(sx, sy)
        cap = 0.975
        over = sr > cap
        sx = np.where(over, sx / np.maximum(sr, 1e-6) * cap, sx)
        sy = np.where(over, sy / np.maximum(sr, 1e-6) * cap, sy)
        return sx, sy

    def _goo(self, t: float) -> np.ndarray:
        sx, sy = self._uv(t)
        px = self.cx + sx * self.sr
        py = self.cy + sy * self.sr
        rgb = _bilinear(self.tex, px, py)
        valid = _bilinear(self.valid[..., None], px, py)[..., 0]
        tau = 2.0 * np.pi * t
        caust = 1.0 + CAUSTIC_AMP * self.motion * (
            0.70 * np.sin(tau + 6.8 * sx + 5.1 * sy)
            + 0.45 * np.sin(2.0 * tau - 4.2 * self.nx + 7.5 * self.ny)
        )
        rgb = np.clip(rgb * caust[..., None] * valid[..., None], 0.0, 255.0)
        bub_rgb, bub_a = self._bubbles(t)
        rgb = rgb * (1.0 - bub_a[..., None] * 0.55) + bub_rgb
        return np.clip(rgb, 0.0, 255.0)

    def _bubbles(self, t: float) -> tuple[np.ndarray, np.ndarray]:
        tau = 2.0 * np.pi * t
        rgb = np.zeros((WIN_D, WIN_D, 3), dtype=np.float32)
        alpha = np.zeros((WIN_D, WIN_D), dtype=np.float32)
        specs = [
            (0.22, 0.055, 0.58, 1.0, 0.10),
            (0.38, 0.040, 0.72, 1.0, 2.40),
            (0.51, 0.032, 0.38, 2.0, 4.10),
            (0.17, 0.062, 0.64, 1.0, 5.50),
            (0.44, 0.026, 0.80, 2.0, 1.30),
            (0.31, 0.044, 0.50, 1.0, 3.70),
            (0.58, 0.022, 0.30, 2.0, 0.80),
            (0.26, 0.036, 0.74, 1.0, 2.90),
            (0.13, 0.048, 0.42, 1.0, 4.80),
            (0.47, 0.028, 0.18, 2.0, 1.90),
        ]
        fade = self.circ * np.clip((0.84 - self.rad) / 0.16, 0.0, 1.0)
        for orbit, size, yscale, revs, phase in specs:
            ang = tau * revs + phase
            bx = orbit * np.cos(ang)
            by = orbit * np.sin(ang) * yscale
            if (bx * bx + by * by) ** 0.5 > 0.76:
                continue
            d = np.hypot(self.nx - bx, self.ny - by)
            core = np.clip((size - d) / size, 0.0, 1.0)
            ball = core * core * (3.0 - 2.0 * core)
            lx = (self.nx - bx) / np.maximum(size, 1e-4)
            ly = (self.ny - by) / np.maximum(size, 1e-4)
            rim = np.exp(-((d - size * 0.78) ** 2) / (2.0 * (size * 0.10) ** 2))
            a = np.clip(ball * 0.38 + rim * 0.55, 0.0, 1.0) * fade
            col = np.array([255.0, 170.0, 70.0], dtype=np.float32)
            spec = np.clip(size * 0.22 - np.hypot(lx + 0.32, ly + 0.40), 0.0, 1.0)
            spec = spec * spec * fade
            rgb += col * a[..., None]
            rgb += np.array([255.0, 253.0, 248.0]) * spec[..., None]
            alpha = np.clip(alpha + a * 0.65 + spec * 0.8, 0.0, 1.0)
        return rgb, alpha

    def sprite(self, t: float) -> Image.Image:
        samples = [
            self._goo((t + k * (0.42 / N_FRAMES)) % 1.0)
            for k in range(MOTION_BLUR_SAMPLES)
        ]
        rgb = np.mean(samples, axis=0)
        layer = np.dstack([rgb, self.circ * 255.0])
        im = Image.fromarray(np.clip(layer, 0, 255).astype(np.uint8), "RGBA")
        return disc_layer(im)


def main() -> None:
    scene = Scene()
    render_kind("slime", N_FRAMES, scene.sprite, "slime")


if __name__ == "__main__":
    main()
