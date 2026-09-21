#!/usr/bin/env python3
"""Looping Zlyme viewport slime.

Composites the viscous orange goo from the close-up still into the
circular glass of the no-biohazard lockup. Fog / glass stay a true
alpha overlay (not an opaque milky disc). Motion is a no-slip roll
inside the bulb so the contact line does not sway like a tank.

    python3 tools/branding/experimental/render_slime_loop.py --preview
    python3 tools/branding/experimental/render_slime_loop.py --encode

Outputs in tools/branding/experimental/out/:
  zlyme_slime_loop.gif   APNG with pinned lockup, real PNG alpha
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from glass import (
    Glass,
    MASK_CX,
    MASK_CY,
    MASK_SCALE,
    VIEW_CX,
    VIEW_CY,
    VIEW_R,
    encode_apng_gif,
    load_luma_mask,
    GLASS_MASK,
)

HERE = Path(__file__).resolve().parent
REFS = HERE / "refs"
OUT = HERE / "out"
FRAMES = OUT / "frames"

STATIC = REFS / "static_fog.png"
SLIME = REFS / "slime_ref.png"

# Glass-mask centroid; nx=1 maps to the glass edge (not the metal groove).
SLIME_CX = MASK_CX
SLIME_CY = MASK_CY
SLIME_R = VIEW_R / MASK_SCALE

N_FRAMES = 240  # 8s at 30fps: same motion, half speed
FPS = 30
MOTION_BLUR_SAMPLES = 2

# Visual knobs
FOG_CENTER = 0.035
FOG_RIM = 0.16
SPEC_GAIN = 1.05
FRESNEL_GAIN = 0.30
CAUSTIC_AMP = 0.13
SWIRL_AMP = 0.24
WARP_AMP = 0.078
BREATHE_AMP = 0.018
DRIP_SAT = 0.42


def load_rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"), dtype=np.float32)


def save_rgba(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(path)


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def bilinear(tex: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = tex.shape[:2]
    x = np.clip(x, 0.0, w - 1.001)
    y = np.clip(y, 0.0, h - 1.001)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    ax = (x - x0)[..., None]
    ay = (y - y0)[..., None]
    ia = tex[y0, x0]
    ib = tex[y0, x1]
    ic = tex[y1, x0]
    id_ = tex[y1, x1]
    return (ia * (1.0 - ax) + ib * ax) * (1.0 - ay) + (ic * (1.0 - ax) + id_ * ax) * ay


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


class Scene:
    def __init__(self) -> None:
        g = Glass()
        self.g = g
        self.orig = g.orig
        self.slime = load_rgba(SLIME)[..., :3]
        self.h, self.w = g.h, g.w
        self.y0, self.y1, self.x0, self.x1 = g.y0, g.y1, g.x0, g.x1
        self.dx, self.dy, self.dist = g.dx, g.dy, g.dist
        self.nx, self.ny, self.rad, self.z = g.nx, g.ny, g.rad, g.z
        self.aa = g.aa
        self.inside = g.aa > 0.05
        self.drip = g.drip
        self.drip_put = g.drip_put
        patch_a = g.orig[g.y0 : g.y1, g.x0 : g.x1, 3]
        # Full glass disk (not drip-punched). Drips are laid back on top.
        self.interior = g.aa * (patch_a > 20.0)
        self.spec = g.spec
        self.fog_rgb = g.fog_rgb
        self.fog_lum = g.fog_rgb.mean(axis=2)
        self.rim_shadow = g.rim_shadow
        self.liquid = g.liquid

        # Suppress the close-up's own window so we do not get two panes.
        s_h, s_w = self.slime.shape[:2]
        syy, sxx = np.ogrid[:s_h, :s_w]
        sdx = (sxx - SLIME_CX) / SLIME_R
        sdy = (syy - SLIME_CY) / SLIME_R
        srad = np.hypot(sdx, sdy)
        slum = self.slime.mean(axis=2)
        ssat = saturation(self.slime)
        window = smoothstep(195.0, 235.0, slum) * (1.0 - smoothstep(0.22, 0.48, ssat))
        window *= np.clip(1.05 - srad, 0.0, 1.0)
        orange = np.array([252.0, 118.0, 28.0], dtype=np.float32)
        self.slime = self.slime * (1.0 - window[..., None] * 0.75) + orange * (
            window[..., None] * 0.75
        )
        sharp = Image.fromarray(np.clip(self.slime, 0, 255).astype(np.uint8), "RGB")
        sharp = sharp.filter(ImageFilter.UnsharpMask(radius=2.2, percent=70, threshold=2))
        self.slime = np.array(sharp, dtype=np.float32)
        self.slime_valid = load_luma_mask(GLASS_MASK) > 0.45

        # Motion stays inside the liquid inset; the glass lip is pinned.
        slip = (self.rad ** 2) * ((1.0 - np.clip(self.rad, 0.0, 1.0)) ** 2) * 16.0
        pin = np.clip((0.965 - self.rad) / 0.12, 0.0, 1.0)
        self.motion = np.clip(0.18 + 0.82 * slip, 0.0, 1.0) * pin * self.liquid

    def uv_at(self, t: float) -> tuple[np.ndarray, np.ndarray]:
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
            + 0.22 * np.sin(tau + 8.0 * nx * ny)
        )
        wy = mot * WARP_AMP * (
            0.86 * np.cos(tau + 1.18 * nx - 0.52 * ny)
            + 0.46 * np.cos(2.0 * tau + 2.25 * ny)
            + 0.30 * np.sin(tau + 3.6 * nx * ny)
            + 0.20 * np.cos(tau + 6.4 * rad)
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

    def sample_slime(self, sx: np.ndarray, sy: np.ndarray) -> np.ndarray:
        px = SLIME_CX + sx * SLIME_R
        py = SLIME_CY + sy * SLIME_R
        rgb = bilinear(self.slime, px, py)
        valid = bilinear(self.slime_valid.astype(np.float32)[..., None], px, py)[..., 0]
        # Outside the glass mask, keep the last in-goo color from clipping
        # bilinear; just fade it so metal never composites.
        return rgb * valid[..., None]

    def bubbles(self, t: float) -> tuple[np.ndarray, np.ndarray]:
        """Return (rgb add, alpha) in the viewport patch."""
        tau = 2.0 * np.pi * t
        hh, ww = self.nx.shape
        rgb = np.zeros((hh, ww, 3), dtype=np.float32)
        alpha = np.zeros((hh, ww), dtype=np.float32)
        # seed, orbit, size (in disc units), depth, revs, phase
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
        for orbit, size, yscale, revs, phase in specs:
            ang = tau * revs + phase
            bx = orbit * np.cos(ang)
            by = orbit * np.sin(ang) * yscale
            if (bx * bx + by * by) ** 0.5 > 0.76:
                continue
            d = np.hypot(self.nx - bx, self.ny - by)
            core = np.clip((size - d) / size, 0.0, 1.0)
            if core.max() <= 0:
                continue
            ball = core * core * (3.0 - 2.0 * core)
            lx = (self.nx - bx) / np.maximum(size, 1e-4)
            ly = (self.ny - by) / np.maximum(size, 1e-4)
            fade = self.interior * np.clip((0.84 - self.rad) / 0.16, 0.0, 1.0)
            rim = np.exp(-((d - size * 0.78) ** 2) / (2.0 * (size * 0.10) ** 2))
            a = np.clip(ball * 0.38 + rim * 0.55, 0.0, 1.0) * fade
            col = np.stack(
                [
                    np.full_like(ball, 255.0),
                    np.full_like(ball, 170.0),
                    np.full_like(ball, 70.0),
                ],
                axis=-1,
            )
            spec = np.clip(size * 0.22 - np.hypot(lx + 0.32, ly + 0.40), 0.0, 1.0)
            spec = spec * spec * fade
            rgb += col * a[..., None]
            rgb += np.array([255.0, 253.0, 248.0]) * spec[..., None]
            alpha = np.clip(alpha + a * 0.65 + spec * 0.8, 0.0, 1.0)
        return rgb, alpha

    def render_patch(self, t: float) -> np.ndarray:
        sx, sy = self.uv_at(t)
        goo = self.sample_slime(sx, sy)

        tau = 2.0 * np.pi * t
        caust = 1.0 + CAUSTIC_AMP * self.motion * (
            0.70 * np.sin(tau + 6.8 * sx + 5.1 * sy)
            + 0.45 * np.sin(2.0 * tau - 4.2 * self.nx + 7.5 * self.ny)
            + 0.28 * np.cos(tau + 10.5 * self.rad)
        )
        goo = np.clip(goo * caust[..., None], 0.0, 255.0)

        # Grade toward the lockup oranges. Dark veins go darker and stay
        # uneven; highlights stay wet so it still reads as living goo.
        g = np.clip(goo / 255.0, 0.0, 1.0)
        lum = g.mean(axis=2)
        vein = smoothstep(0.66, 0.22, lum)
        deep = smoothstep(0.38, 0.11, lum)
        g = np.power(g, (1.0 + 0.38 * vein + 0.28 * deep)[..., None])
        g = g * (1.0 - (0.12 * vein + 0.14 * deep)[..., None])
        hi = smoothstep(0.68, 0.90, lum)
        g = g + (1.0 - g) * (hi * 0.07)[..., None]
        g[..., 0] = np.clip(g[..., 0] * 1.05, 0.0, 1.0)
        g[..., 1] = np.clip(g[..., 1] * 0.91, 0.0, 1.0)
        g[..., 2] = np.clip(g[..., 2] * 0.64, 0.0, 1.0)
        goo = np.clip(g * 255.0, 0.0, 255.0)
        goo *= (1.0 - 0.50 * self.rim_shadow)[..., None]

        bub_rgb, bub_a = self.bubbles(t)
        goo = goo * (1.0 - bub_a[..., None] * 0.55) + bub_rgb

        # Thin condensation: almost clear in the centre, a little fog at the rim.
        fog_a = FOG_CENTER + (FOG_RIM - FOG_CENTER) * smoothstep(0.38, 1.0, self.rad)
        fog_a = fog_a * (1.0 + 0.06 * np.sin(tau)) * self.interior
        fog_col = self.fog_rgb * 0.70 + np.array([255.0, 210.0, 170.0]) * 0.30
        goo = goo * (1.0 - fog_a[..., None]) + fog_col * fog_a[..., None]

        # Glass fresnel rim (silver, slightly cool).
        fres = (1.0 - self.z) ** 2.65
        fres *= self.interior
        glass = np.array([214.0, 224.0, 232.0], dtype=np.float32)
        goo = goo * (1.0 - fres * FRESNEL_GAIN)[..., None] + glass * (
            fres * FRESNEL_GAIN
        )[..., None]

        # Original window specular, static (environment on the glass).
        spec_col = np.array([255.0, 250.0, 244.0], dtype=np.float32)
        goo = screen_blend(goo, spec_col * self.spec[..., None], self.spec * SPEC_GAIN)

        # Extra moving wet highlight on the liquid only (under the glass).
        wet = smoothstep(0.08, 0.0, np.hypot(self.nx + 0.38 + 0.04 * np.sin(tau), self.ny + 0.46))
        wet *= self.interior * (1.0 - self.drip) * 0.22
        goo = screen_blend(goo, spec_col, wet)

        return np.clip(goo, 0.0, 255.0)

    def composite(self, t: float) -> np.ndarray:
        samples = []
        for k in range(MOTION_BLUR_SAMPLES):
            tk = (t + k * (0.42 / N_FRAMES)) % 1.0
            samples.append(self.render_patch(tk))
        goo = np.mean(samples, axis=0)

        out = self.orig.copy()
        patch = out[self.y0 : self.y1, self.x0 : self.x1]
        cover = self.interior
        rgb = patch[..., :3] * (1.0 - cover[..., None]) + goo * cover[..., None]
        # Goo is opaque; never keep the original fog alpha in the hole.
        alpha = np.maximum(patch[..., 3] * (1.0 - cover), 255.0 * cover)
        patch[..., :3] = rgb
        patch[..., 3] = alpha
        # Drips sit on top of slime, only where the lockup is actually orange.
        d = self.drip_put
        orig_p = self.orig[self.y0 : self.y1, self.x0 : self.x1]
        patch[..., :3] = patch[..., :3] * (1.0 - d[..., None]) + orig_p[..., :3] * d[
            ..., None
        ]
        patch[..., 3] = np.maximum(patch[..., 3], orig_p[..., 3] * d)
        out[self.y0 : self.y1, self.x0 : self.x1] = patch
        return out

    def save_debug(self) -> None:
        dbg = OUT / "debug"
        dbg.mkdir(parents=True, exist_ok=True)
        vis = self.orig.copy()
        overlay = vis[self.y0 : self.y1, self.x0 : self.x1]
        ring = (np.abs(self.dist - VIEW_R) < 1.4).astype(np.float32)
        overlay[..., 0] = np.clip(overlay[..., 0] + ring * 80, 0, 255)
        overlay[..., 1] = np.clip(overlay[..., 1] + ring * 220, 0, 255)
        vis[self.y0 : self.y1, self.x0 : self.x1] = overlay
        crop = vis[
            int(VIEW_CY - VIEW_R - 40) : int(VIEW_CY + VIEW_R + 40),
            int(VIEW_CX - VIEW_R - 40) : int(VIEW_CX + VIEW_R + 40),
        ]
        save_rgba(crop, dbg / "view_circle.png")
        save_rgba(
            np.stack([self.interior * 255] * 3 + [np.full_like(self.interior, 255)], axis=-1),
            dbg / "interior.png",
        )
        save_rgba(
            np.stack([self.drip * 255] * 3 + [np.full_like(self.drip, 255)], axis=-1),
            dbg / "drips.png",
        )
        save_rgba(
            np.stack([self.spec * 255] * 3 + [np.full_like(self.spec, 255)], axis=-1),
            dbg / "spec.png",
        )
        # Slime sample circle
        slim = Image.open(SLIME).convert("RGBA")
        dr = ImageDraw.Draw(slim)
        dr.ellipse(
            [SLIME_CX - SLIME_R, SLIME_CY - SLIME_R, SLIME_CX + SLIME_R, SLIME_CY + SLIME_R],
            outline=(0, 255, 80, 255),
            width=3,
        )
        slim.save(dbg / "slime_circle.png")


def checkerboard(im: Image.Image, cell: int = 24) -> Image.Image:
    w, h = im.size
    bg = Image.new("RGBA", (w, h))
    pix = np.zeros((h, w, 4), dtype=np.uint8)
    yy, xx = np.ogrid[:h, :w]
    chk = ((xx // cell) + (yy // cell)) % 2
    pix[chk == 0] = (38, 38, 42, 255)
    pix[chk == 1] = (22, 22, 24, 255)
    bg = Image.fromarray(pix, "RGBA")
    return Image.alpha_composite(bg, im.convert("RGBA"))


def encode(framerate: int) -> None:
    encode_apng_gif(FRAMES, OUT / "zlyme_slime_loop.gif", framerate)


def main() -> None:
    global N_FRAMES
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true", help="8 frames + stills only")
    ap.add_argument("--encode", action="store_true", help="gif / webp / apng after frames")
    ap.add_argument("--frames", type=int, default=N_FRAMES)
    args = ap.parse_args()

    if not STATIC.exists() or not SLIME.exists():
        sys.exit(f"missing refs in {REFS}")

    N_FRAMES = 8 if args.preview else args.frames

    OUT.mkdir(parents=True, exist_ok=True)
    if FRAMES.exists() and not args.preview:
        shutil.rmtree(FRAMES)
    FRAMES.mkdir(parents=True, exist_ok=True)

    scene = Scene()
    if args.preview:
        scene.save_debug()

    n = N_FRAMES
    times = [i / n for i in range(n)]

    stills: list[Image.Image] = []
    for i, t in enumerate(times):
        arr = scene.composite(t)
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
        dest = FRAMES / f"frame_{i:04d}.png"
        im.save(dest, compress_level=1)
        if args.preview:
            stills.append(im)
        if i % 10 == 0 or args.preview:
            print(f"frame {i+1}/{len(times)} t={t:.3f}")

    if args.preview:
        stills[0].save(OUT / "still_t0.png")
        checkerboard(stills[0]).save(OUT / "still_t0_checker.png")
        crops = []
        for im in stills[:8]:
            c = im.crop(
                (
                    int(VIEW_CX - VIEW_R - 24),
                    int(VIEW_CY - VIEW_R - 24),
                    int(VIEW_CX + VIEW_R + 24),
                    int(VIEW_CY + VIEW_R + 24),
                )
            )
            crops.append(c)
        sheet_w = sum(c.width for c in crops)
        sheet = Image.new("RGBA", (sheet_w, crops[0].height), (0, 0, 0, 0))
        x = 0
        for c in crops:
            sheet.paste(c, (x, 0))
            x += c.width
        sheet.save(OUT / "glass_strip.png")

    print(f"wrote {len(times)} frames to {FRAMES}")
    if args.encode and not args.preview:
        encode(FPS)


if __name__ == "__main__":
    main()
