#!/usr/bin/env python3
"""Compose Zlyme Art Book wallpapers from Art Book Next sources.

The ES-DE theme draws one tall transparent strip per system and a
separate white logo. NextUI draws the menu on the left, so the strip
is anchored to the right and the logo sits on that strip. The list
view keeps only a small logo on black so the names stay readable.

Source commit d772d07109701d9bd7c9fda305bfef6601105ab8, directory
_inc/systems/artwork (the original style, not noir, outline, circuit,
or screenshots). Logos are _inc/systems/logos. rsvg-convert rasterizes
the SVG. Pillow composites. Neither runs on the Flip.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin

SOURCE_COMMIT = "d772d07109701d9bd7c9fda305bfef6601105ab8"
WIDTH = 640
HEIGHT = 480
BLACK = (0, 0, 0, 255)
# dark-original system background is #000000. The list field stays black
# so names drawn over it remain readable.
LIST_LOGO_MAX = (240, 42)
SYSTEM_LOGO_MAX = (300, 78)

# Zlyme tag -> ES-DE artwork/logo stem. None is a Zlyme wordmark.
# PICO and P8 are both Pico-8. MKXPZ has no file in this commit.
TAG_SOURCE = {
    "GB": "gb",
    "GBC": "gbc",
    "GBA": "gba",
    "FC": "nes",
    "SFC": "snes",
    "MD": "genesis",
    "MS": "mastersystem",
    "GG": "gamegear",
    "32X": "sega32x",
    "PS": "psx",
    "PSP": "psp",
    "DC": "dreamcast",
    "N64": "n64",
    "NDS": "nds",
    "PCE": "pcengine",
    "NGP": "ngp",
    "WS": "wonderswan",
    "VB": "virtualboy",
    "LYNX": "atarilynx",
    "A26": "atari2600",
    "A5200": "atari5200",
    "A78": "atari7800",
    "A800": "atari800",
    "ST": "atarist",
    "COLECO": "colecovision",
    "INTV": "intellivision",
    "MSX": "msx",
    "O2": "odyssey2",
    "SG1000": "sg-1000",
    "SGX": "supergrafx",
    "VEC": "vectrex",
    "PKM": "pokemini",
    "FBNEO": "fbneo",
    "MAME": "mame",
    "DOS": "dos",
    "3DO": "3do",
    "NEOCD": "neogeocd",
    "SATURN": "saturn",
    "AMIGA": "amiga",
    "DOOM": "doom",
    "TIC": "tic80",
    "PICO": "pico8",
    "FLASH": "flash",
    "P8": "pico8",
    "PORTS": "ports",
    "EASYRPG": "easyrpg",
    "MKXPZ": None,
    "SCUMMVM": "scummvm",
    "OPENBOR": "openbor",
    "DAPHNE": "daphne",
    "WINE": "windows",
    "PS2": "ps2",
    "GC": "gc",
    "WII": "wii",
}

WORDMARK = {
    "MKXPZ": "RPG MAKER",
    "Tools": "TOOLS",
    "Collections": "COLLECTIONS",
    "Recently Played": "RECENTLY\nPLAYED",
}

HERE = Path(__file__).resolve().parent
ROM_DIRS = Path(os.environ.get("ARTBOOK_ROM_DIRS", HERE.parent / "rom-dirs.txt"))


def fail(msg: str) -> None:
    print("artbook: " + msg, file=sys.stderr)
    raise SystemExit(1)


def rom_tags() -> list[str]:
    tags = []
    for line in ROM_DIRS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.search(r"\(([^)]+)\)$", line)
        if not match:
            fail("rom dir has no tag: " + line)
        tags.append(match.group(1))
    return tags


def outputs() -> list[tuple[str, str]]:
    """(directory, filename) under the artbook root."""
    rows = []
    for tag in rom_tags():
        rows.append(("system", "(%s).png" % tag))
        rows.append(("list", "(%s)-list.png" % tag))
    for name in ("Tools", "Collections", "Recently Played"):
        rows.append(("system", "%s.png" % name))
        rows.append(("list", "%s-list.png" % name))
    return rows


def source_files() -> list[str]:
    names = sorted({stem for stem in TAG_SOURCE.values() if stem})
    rows = ["fonts/DejaVuSans-Bold.ttf", "fonts/LICENSE"]
    for name in names:
        rows.append("artwork/%s.png" % name)
        rows.append("logos/%s.svg" % name)
    return rows


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_sums(src: Path) -> None:
    lines = []
    for rel in source_files():
        path = src / rel
        if not path.is_file():
            fail("missing source " + rel)
        lines.append("%s  %s" % (sha256(path), rel))
    (src / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")


def check_sums(src: Path) -> None:
    sums = src / "SHA256SUMS"
    if not sums.is_file():
        fail("SHA256SUMS is missing")
    seen = []
    for line in sums.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, rel = line.split("  ", 1)
        path = src / rel
        if not path.is_file():
            fail("missing source " + rel)
        got = sha256(path)
        if got != digest:
            fail("checksum changed for " + rel)
        seen.append(rel)
    expect = source_files()
    if seen != expect:
        fail("SHA256SUMS does not match the source list")


def vendor(upstream: Path, src: Path) -> None:
    art = upstream / "_inc" / "systems" / "artwork"
    logos = upstream / "_inc" / "systems" / "logos"
    if not art.is_dir() or not logos.is_dir():
        fail("upstream artwork directories are missing")
    for rel in source_files():
        if rel.startswith("fonts/"):
            continue
        kind, name = rel.split("/", 1)
        origin = (art if kind == "artwork" else logos) / name
        if not origin.is_file():
            fail("upstream has no " + rel)
        dest = src / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(origin.read_bytes())
    write_sums(src)


def render_svg(path: Path, max_w: int, max_h: int) -> Image.Image:
    try:
        proc = subprocess.run(
            ["rsvg-convert", "-f", "png", "-h", str(max_h), os.fspath(path)],
            check=True,
            capture_output=True,
        )
    except FileNotFoundError:
        fail("rsvg-convert is not installed")
    except subprocess.CalledProcessError as exc:
        fail("rsvg-convert failed for %s: %s" % (path.name, exc.stderr.decode()[-200:]))
    image = Image.open(__import__("io").BytesIO(proc.stdout)).convert("RGBA")
    if image.width > max_w:
        height = max(1, round(image.height * max_w / image.width))
        image = image.resize((max_w, height), Image.Resampling.LANCZOS)
    return image


def wordmark(text: str, max_w: int, max_h: int, font_path: Path) -> Image.Image:
    if not font_path.is_file():
        fail("DejaVu Sans Bold is missing")
    size = max_h
    image = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    while size > 8:
        font = ImageFont.truetype(os.fspath(font_path), size)
        box = draw.multiline_textbbox((0, 0), text, font=font, align="center", spacing=2)
        width = int(box[2] - box[0])
        height = int(box[3] - box[1])
        if width <= max_w and height <= max_h:
            break
        size -= 1
    font = ImageFont.truetype(os.fspath(font_path), size)
    box = draw.multiline_textbbox((0, 0), text, font=font, align="center", spacing=2)
    width = int(box[2] - box[0]) + 2
    height = int(box[3] - box[1]) + 2
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(image).multiline_text(
        (int(1 - box[0]), int(1 - box[1])),
        text,
        font=font,
        fill=(255, 255, 255, 255),
        align="center",
        spacing=2,
    )
    return image


def logo_for(src: Path, key: str, max_w: int, max_h: int) -> Image.Image:
    stem = TAG_SOURCE.get(key, None)
    if key in WORDMARK:
        return wordmark(WORDMARK[key], max_w, max_h, src / "fonts" / "DejaVuSans-Bold.ttf")
    if not stem:
        fail("no artwork mapping for " + key)
    return render_svg(src / "logos" / ("%s.svg" % stem), max_w, max_h)


def fit_art(path: Path) -> Image.Image:
    art = Image.open(path).convert("RGBA")
    width = max(1, round(art.width * HEIGHT / art.height))
    return art.resize((width, HEIGHT), Image.Resampling.LANCZOS)


def compose_system(art: Image.Image | None, logo: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), BLACK)
    if art is not None:
        canvas.alpha_composite(art, (WIDTH - art.width, 0))
        left = WIDTH - art.width
        x = left + (art.width - logo.width) // 2
        x = max(int(WIDTH * 0.34), min(x, WIDTH - logo.width - 8))
    else:
        x = WIDTH - logo.width - 28
    y = (HEIGHT - logo.height) // 2
    canvas.alpha_composite(logo, (x, y))
    return canvas


def compose_list(logo: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), BLACK)
    x = (WIDTH - logo.width) // 2
    y = HEIGHT - logo.height - 22
    canvas.alpha_composite(logo, (x, y))
    return canvas


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Opaque RGB, no text chunks. optimize is deterministic for this encoder.
    image.convert("RGB").save(
        path,
        "PNG",
        optimize=True,
        pnginfo=PngImagePlugin.PngInfo(),
    )


def render_tree(src: Path, out: Path) -> None:
    check_sums(src)
    tags = rom_tags()
    missing = [tag for tag in tags if tag not in TAG_SOURCE]
    if missing:
        fail("rom-dirs tags without a mapping: " + ", ".join(missing))
    extra = sorted(set(TAG_SOURCE) - set(tags))
    if extra:
        fail("mappings that are not rom-dirs tags: " + ", ".join(extra))
    art_cache: dict[str, Image.Image] = {}
    for tag in tags:
        stem = TAG_SOURCE[tag]
        art = None
        if stem:
            if stem not in art_cache:
                art_cache[stem] = fit_art(src / "artwork" / ("%s.png" % stem))
            art = art_cache[stem]
        system_logo = logo_for(src, tag, *SYSTEM_LOGO_MAX)
        list_logo = logo_for(src, tag, *LIST_LOGO_MAX)
        save_png(compose_system(art, system_logo), out / "system" / ("(%s).png" % tag))
        save_png(compose_list(list_logo), out / "list" / ("(%s)-list.png" % tag))
    for name in ("Tools", "Collections", "Recently Played"):
        system_logo = logo_for(src, name, *SYSTEM_LOGO_MAX)
        list_logo = logo_for(src, name, *LIST_LOGO_MAX)
        save_png(compose_system(None, system_logo), out / "system" / ("%s.png" % name))
        save_png(compose_list(list_logo), out / "list" / ("%s-list.png" % name))


def clean_outputs(out: Path) -> None:
    keep = {out / directory / name for directory, name in outputs()}
    for directory in ("system", "list"):
        folder = out / directory
        if not folder.is_dir():
            continue
        for path in folder.glob("*.png"):
            if path not in keep:
                path.unlink()


def contact_sheet(out: Path, dest: Path) -> None:
    names = [out / "system" / name for directory, name in outputs() if directory == "system"]
    columns = 6
    thumb_w, thumb_h = 160, 120
    rows = (len(names) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * thumb_w, rows * thumb_h), (0, 0, 0))
    for index, path in enumerate(names):
        thumb = Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.BOX)
        sheet.paste(thumb, ((index % columns) * thumb_w, (index // columns) * thumb_h))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest, "PNG", optimize=True)


def compare_trees(left: Path, right: Path) -> None:
    for directory, name in outputs():
        a = left / directory / name
        b = right / directory / name
        if not a.is_file() or not b.is_file():
            fail("missing " + directory + "/" + name)
        if a.read_bytes() != b.read_bytes():
            fail("output differs: " + directory + "/" + name)
    for directory in ("system", "list"):
        have = sorted(p.name for p in (right / directory).glob("*.png"))
        want = sorted(name for d, name in outputs() if d == directory)
        if have != want:
            fail("unexpected files in " + directory)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", type=Path, default=HERE / "src")
    parser.add_argument("--out", type=Path, default=HERE)
    parser.add_argument("--vendor", type=Path)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--contact", type=Path)
    args = parser.parse_args()
    if args.vendor:
        vendor(args.vendor, args.src)
    if args.write:
        render_tree(args.src, args.out)
        clean_outputs(args.out)
    if args.check:
        with tempfile.TemporaryDirectory() as tmp:
            render_tree(args.src, Path(tmp))
            compare_trees(Path(tmp), args.out)
    if args.contact:
        contact_sheet(args.out, args.contact)
    if not any((args.vendor, args.write, args.check, args.contact)):
        fail("pass --vendor, --write, --check, or --contact")


if __name__ == "__main__":
    main()
