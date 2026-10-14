# Zlyme logo loops

Host-side scripts that composite animated discs into the Zlyme lockup
(circle above “zlyme”) and write GIF89a splash loops. They are for
making the art. Shipped splash and OTA frames come from
`package/system/nextui/res/branding/` via `scripts/rasterize-zlyme-branding.py`.

## License

Python in this folder (`stack.py`, `gif89a.py`, `render_*_loop.py`,
`align_circles.py`) is original Zlyme work under the MIT License in
the repository `LICENSE` file. Copyright (c) 2026 Zlyme contributors.

The lockup, masks, glass, slime still, galaxy clip, and any GIFs in
`out/` (gitignored) are Zlyme branding. They are not MIT. Do not treat
this folder as permission to reuse the mark, the lettering, or the
generated loops outside Zlyme.

Pillow and NumPy keep their own licenses.

## What you need

Python 3 with NumPy and Pillow:

```sh
python3 -c "import numpy, PIL; print('ok')"
```

Run everything from this directory.

## Inputs

| File | Role |
| --- | --- |
| `Base.png` | Lockup. Do not recolor it. |
| `Bases/Base_*.png` | Alternate lockups; same canvas, same window. |
| `Ref-window.png` | Luminance disc already registered on `Base.png`. Animation fills this hole. |
| `Ref-metallic-circle.png` | Outer metal ring, used to clip glass. |
| `Ref-glass.png` | Fog and window reflections. Outer chroma-key red is stripped. |
| `Ref-slime.png` | Slime still, warped into the window. |
| `zlyme_galaxy_3d_rotation_3s_200px_30fps.gif` | Galaxy rotation clip (APNG bytes, `.gif` name). |

Stack, per frame:

animation and glass inside `Ref-window`, then `Base.png` on top.

## Generate the loops

```sh
cd tools/branding/experimental
python3 render_slime_loop.py
python3 render_galaxy_loop.py
python3 render_stars_loop.py
```

Each script renders the window animation once, then stacks it onto
`Base.png` and every `Bases/Base_*.png`. Outputs go to `out/` (gitignored):

- `zlyme_slime_loop.gif`, `zlyme_galaxy_loop.gif`, `zlyme_stars_loop.gif`
- `zlyme_{slime,galaxy,stars}_loop_Base_TESTN.gif` for each alternate lockup

The GIFs are GIF89a, 1254×1254, transparency index 0, 30 FPS (delay
stored as 30 ms). Slime is 135 frames (4.5 s). Galaxy and stars are
90 frames (3 s).

`stack.py` and `gif89a.py` are imported; you do not run them directly.

The loops NextUI ships are `Bases/Base_TEST6.png` renders copied to
`package/system/nextui/res/branding/zlyme_{slime,stars}_loop.gif`. After
changing those sources, copy the TEST6 GIFs there and run
`python3 scripts/rasterize-zlyme-branding.py` from the repository root.

## Align alternate lockups (optional)

If a `Base_*.png` ring is not on `Ref-window`, move only that ring and
its drips. The word stays put:

```sh
python3 align_circles.py
```

That reads originals from
`/home/ale/Downloads/DISPOSABLE/New logo/Bases/` when that directory
exists, otherwise from `Bases/`, and writes into `Bases/`. Re-run the
three `render_*_loop.py` scripts afterwards.
