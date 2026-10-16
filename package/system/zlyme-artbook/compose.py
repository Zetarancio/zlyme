#!/usr/bin/env python3
"""Compose transparent Zlyme Art Book overlays on the build host.

System strips come from the pinned Art Book Next archive. Tool pictures
come from tools/<Name>.pak/background.png. A 454x1080 tool picture is
clipped to the canonical alpha. The logo is the pak name, with a black
contour and a 16px black shadow at 50% opacity. Artwork stays in the
right half so scrolling names stay clear.
"""

from __future__ import annotations

import argparse
import html
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

WIDTH = 640
HEIGHT = 480
SAFE_X = 320
LOGO_MAX_W = 291
SHADOW = 16
OUTLINE = 2
REGION_W = WIDTH - SAFE_X
MASK_SIZE = (454, 1080)


def fail(msg: str) -> None:
    raise SystemExit("zlyme-artbook: " + msg)


def load_rgba(path: Path) -> Image.Image:
    try:
        image = Image.open(path)
        image.load()
    except Exception as exc:
        fail("cannot read %s (%s)" % (path, exc))
    return image.convert("RGBA")


def load_alpha_mask(path: Path) -> Image.Image:
    try:
        image = Image.open(path)
        image.load()
    except Exception as exc:
        fail("cannot read mask %s (%s)" % (path, exc))
    if image.size != MASK_SIZE:
        fail("canonical mask is %s, not %dx%d" % (image.size, MASK_SIZE[0], MASK_SIZE[1]))
    if image.mode == "L":
        return image
    if image.mode == "RGBA":
        return image.getchannel("A")
    fail("canonical mask must be L or RGBA")


def silhouette_edges(alpha: Image.Image):
    pixels = alpha.load()
    width, height = alpha.size

    def first(y: int):
        for x in range(width):
            if pixels[x, y]:
                return x
        return None

    return first(0), first(height // 2), first(height - 1)


def validate_mask(mask: Image.Image) -> None:
    """The mask is a parallelogram, not a rectangle."""
    if mask.mode != "L" or mask.size != MASK_SIZE:
        fail("canonical mask has the wrong mode or size")
    top, mid, bottom = silhouette_edges(mask)
    if top is None or not 100 <= top <= 130:
        fail("mask top edge is not the Art Book diagonal")
    if bottom != 0:
        fail("mask bottom edge does not reach x=0")
    if mid is None or not bottom < mid < top:
        fail("mask is not a diagonal parallelogram")


def respects_mask(image: Image.Image, mask: Image.Image) -> bool:
    """True when every visible pixel is inside the silhouette."""
    if image.size != mask.size or image.mode != "RGBA" or mask.mode != "L":
        return False
    src = image.getchannel("A")
    outside = ImageChops.subtract(src, mask)
    return outside.getextrema() == (0, 0)


def apply_canonical_mask(image: Image.Image, mask: Image.Image) -> Image.Image:
    """Clip alpha to the silhouette. Interior color and interior alpha stay."""
    if image.size != mask.size:
        fail(
            "tool background must be %dx%d, got %dx%d"
            % (mask.size[0], mask.size[1], image.size[0], image.size[1])
        )
    bands = list(image.convert("RGBA").split())
    bands[3] = ImageChops.darker(bands[3], mask)
    return Image.merge("RGBA", bands)


def fit(image: Image.Image, max_w: int, max_h: int) -> Image.Image:
    if image.width <= max_w and image.height <= max_h:
        return image
    scale = min(max_w / image.width, max_h / image.height)
    size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", compress_level=9, optimize=False)


def content_box(image: Image.Image):
    pixels = image.convert("RGBA").load()
    minx, miny, maxx, maxy = WIDTH, HEIGHT, -1, -1
    transparent = 0
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y][3] == 0:
                transparent += 1
                continue
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)
    return minx, miny, maxx, maxy, transparent


def styled_logo(image: Image.Image) -> Image.Image:
    """Black 16px shadow at 50%, then a 2px black contour, then the mark."""
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    pad = SHADOW
    big = Image.new("L", (image.width + pad * 2, image.height + pad * 2), 0)
    big.paste(alpha, (pad, pad))
    shadow = big.filter(ImageFilter.MaxFilter(SHADOW * 2 + 1))
    outline = big.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1))
    canvas = Image.new("RGBA", big.size, (0, 0, 0, 0))
    shadow_rgba = Image.new("RGBA", big.size, (0, 0, 0, 0))
    shadow_rgba.putalpha(shadow.point(lambda value: value * 128 // 255))
    outline_rgba = Image.new("RGBA", big.size, (0, 0, 0, 255))
    outline_rgba.putalpha(outline)
    canvas.alpha_composite(shadow_rgba)
    canvas.alpha_composite(outline_rgba)
    canvas.alpha_composite(image, (pad, pad))
    return canvas


def svg_text(label: str) -> str:
    return html.escape(label, quote=True)


def render_svg(rsvg: str, svg_text_body: str, width: int, height: int, work: Path) -> Image.Image:
    svg = work / "mark.svg"
    png = work / "mark.png"
    svg.write_text(svg_text_body, encoding="utf-8")
    subprocess.run([rsvg, "-w", str(width), "-h", str(height), "-o", str(png), str(svg)], check=True)
    return load_rgba(png)


def wordmark(label: str, font: Path, rsvg: str, work: Path) -> Image.Image:
    """Shrink, then wrap on spaces, until the styled logo fits the frame."""
    words = label.split()
    if not words:
        fail("empty logo")
    layouts = [[label]]
    if len(words) > 1:
        mid = max(1, len(words) // 2)
        layouts.append([" ".join(words[:mid]), " ".join(words[mid:])])
    for lines in layouts:
        size = 48
        while size >= 16:
            tspans = []
            for index, line in enumerate(lines):
                dy = 0 if index == 0 else int(size * 1.2)
                tspans.append('<tspan x="0" dy="%d">%s</tspan>' % (dy, svg_text(line)))
            body = (
                '<svg xmlns="http://www.w3.org/2000/svg" width="520" height="220">'
                '<style>@font-face { font-family: ZlymeWord; src: url("%s"); }</style>'
                '<text x="0" y="%d" font-family="ZlymeWord" font-size="%d" fill="#ffffff">%s</text>'
                '</svg>'
            ) % (font.resolve().as_uri(), size, size, "".join(tspans))
            rendered = render_svg(rsvg, body, 520, 220, work)
            bbox = rendered.getbbox()
            if bbox is None:
                size -= 2
                continue
            logo = styled_logo(rendered.crop(bbox))
            if logo.width <= LOGO_MAX_W and logo.height <= 220:
                return logo
            size -= 2
    fail("logo does not fit the safe frame: %s" % label)


def logo_origin(mark: Image.Image) -> tuple[int, int]:
    """Center the styled logo in the right-hand 320x480 region.

    Systems and tools both use this. The mark's own box includes the
    contour and the shadow. The background artwork is not part of it.
    """
    if mark.width > LOGO_MAX_W:
        fail("logo wider than %d" % LOGO_MAX_W)
    x = SAFE_X + (REGION_W - mark.width) // 2
    y = (HEIGHT - mark.height) // 2
    if x < SAFE_X or x + mark.width > WIDTH or y < 0 or y + mark.height > HEIGHT:
        fail("logo leaves the safe frame")
    return x, y


def place(canvas: Image.Image, mark: Image.Image) -> None:
    canvas.alpha_composite(mark, logo_origin(mark))


def blank() -> Image.Image:
    return Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))


def place_art(canvas: Image.Image, art: Image.Image) -> None:
    fitted = fit(art, REGION_W, HEIGHT)
    x = WIDTH - fitted.width
    y = (HEIGHT - fitted.height) // 2
    if x < SAFE_X:
        fail("artwork enters the name column")
    canvas.alpha_composite(fitted, (x, y))


def prepare_system_logo(logo_svg: Path, font: Path, rsvg: str, work: Path) -> Image.Image:
    logo = render_svg(rsvg, logo_svg.read_text(encoding="utf-8").replace(
        "FONTFILE", font.resolve().as_uri()), 400, 120, work)
    bbox = logo.getbbox()
    if bbox:
        logo = logo.crop(bbox)
    logo = styled_logo(fit(logo, LOGO_MAX_W - SHADOW * 2, 160))
    return fit(logo, LOGO_MAX_W, 220)


def compose_system(art_png: Path, logo_svg: Path, font: Path, rsvg: str, work: Path) -> Image.Image:
    art = load_rgba(art_png)
    # The strip is tall. Fit by height, then anchor to the right.
    scale = HEIGHT / art.height
    size = (max(1, int(art.width * scale)), HEIGHT)
    if size[0] > REGION_W:
        size = (REGION_W, max(1, int(art.height * REGION_W / art.width)))
    strip = art.resize(size, Image.Resampling.LANCZOS)
    canvas = blank()
    canvas.alpha_composite(strip, (WIDTH - strip.width, (HEIGHT - strip.height) // 2))
    place(canvas, prepare_system_logo(logo_svg, font, rsvg, work))
    return canvas


def compose_tool(
    background: Path,
    label: str,
    font: Path,
    rsvg: str,
    work: Path,
    mask: Image.Image | None = None,
) -> Image.Image:
    art = load_rgba(background)
    if mask is not None:
        art = apply_canonical_mask(art, mask)
    canvas = blank()
    place_art(canvas, art)
    logo = wordmark(label, font, rsvg, work)
    place(canvas, logo)
    return canvas


# Folder name is the wordmark. The file name is the firmware asset.
# Recently Played is not a Tool pak.
SPECIALS = (("Recently Played", "recent.png"),)


def compose_specials(mask: Image.Image, font: Path, rsvg: str, work: Path, stage: Path):
    root = Path(__file__).resolve().parent / "special"
    if not root.is_dir():
        fail("special artwork directory is missing")
    found = sorted(path.name for path in root.iterdir() if path.is_dir())
    wanted = sorted(name for name, _filename in SPECIALS)
    if found != wanted:
        fail("special artwork inventory does not match: " + ", ".join(found))
    images = []
    for name, filename in SPECIALS:
        background = root / name / "background.png"
        if not background.is_file():
            fail("missing special background for " + name)
        image = compose_tool(background, name, font, rsvg, work, mask)
        save_png(image, stage / filename)
        images.append((name, image))
    return images


def load_map(path: Path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(maxsplit=2)
        tag, stem = parts[0], parts[1]
        label = parts[2] if len(parts) > 2 else tag
        rows.append((tag, None if stem == "-" else stem, label))
    return rows


def tool_sources(tools: Path) -> list[Path]:
    return sorted(p for p in tools.iterdir() if p.is_dir() and p.name.endswith(".pak"))


def check_tools(tools: Path, paks: Path) -> list[Path]:
    found = tool_sources(tools)
    names = [p.name for p in found]
    stock = sorted(n for n in (p.name for p in paks.iterdir()) if n.endswith(".pak"))
    missing = [name for name in stock if name not in names]
    extra = [name for name in names if name not in stock]
    if missing:
        fail("shipped tool has no background: " + ", ".join(missing))
    if extra:
        fail("tool background has no shipped pak: " + ", ".join(extra))
    for folder in found:
        backs = list(folder.glob("background.png"))
        if len(backs) != 1:
            fail("%s needs exactly background.png" % folder.name)
    return found


def publish_tree(stage: Path, dest: Path) -> None:
    """Replace dest with a finished stage. An old filename does not remain."""
    parent = dest.parent
    parent.mkdir(parents=True, exist_ok=True)
    incoming = parent / (".%s.incoming" % dest.name)
    if incoming.exists():
        shutil.rmtree(incoming)
    shutil.copytree(stage, incoming)
    if dest.exists():
        shutil.rmtree(dest)
    incoming.rename(dest)


def contact(images: list[tuple[str, Image.Image]], dest: Path, light: bool) -> None:
    columns = 6
    tw, th = 160, 120
    rows_n = (len(images) + columns - 1) // columns
    bg = (236, 232, 224, 255) if light else (16, 16, 18, 255)
    sheet = Image.new("RGBA", (columns * tw, rows_n * th), bg)
    for index, (_name, image) in enumerate(images):
        thumb = image.resize((tw, th), Image.Resampling.BOX)
        ox = (index % columns) * tw
        oy = (index // columns) * th
        sheet.alpha_composite(thumb, (ox, oy))
    save_png(sheet, dest)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument("--tools", type=Path, required=True)
    parser.add_argument("--paks", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--rsvg", default="rsvg-convert")
    parser.add_argument("--contact", type=Path)
    args = parser.parse_args()
    art_dir = args.upstream / "_inc" / "systems" / "artwork"
    logo_dir = args.upstream / "_inc" / "systems" / "logos"
    if not art_dir.is_dir() or not logo_dir.is_dir():
        fail("upstream artwork is missing")
    mask_path = Path(__file__).resolve().parent / "resources" / "system-art-alpha.png"
    mask = load_alpha_mask(mask_path)
    validate_mask(mask)
    folders = check_tools(args.tools, args.paks)
    with tempfile.TemporaryDirectory(prefix="zlyme-artbook-") as tmp:
        work = Path(tmp)
        stage_system = work / "system"
        stage_tools = work / "tools"
        systems = []
        for tag, stem, label in load_map(args.map):
            if stem is None:
                custom = args.tools / "custom" / tag / "background.png"
                if not custom.is_file():
                    fail("missing custom background for " + tag)
                image = compose_tool(custom, label, args.font, args.rsvg, work)
            else:
                image = compose_system(
                    art_dir / ("%s.png" % stem),
                    logo_dir / ("%s.svg" % stem),
                    args.font,
                    args.rsvg,
                    work,
                )
            save_png(image, stage_system / ("(%s).png" % tag))
            systems.append((tag, image))
        tools = []
        for folder in folders:
            label = folder.name[:-4]
            image = compose_tool(folder / "background.png", label, args.font, args.rsvg, work, mask)
            save_png(image, stage_tools / ("%s.png" % label))
            tools.append((label, image))
        specials = compose_specials(mask, args.font, args.rsvg, work, work / "special")
        # The stages are complete. Replacing now drops a renamed or removed entry.
        publish_tree(stage_system, args.out / "system")
        publish_tree(stage_tools, args.out / "tools")
        publish_tree(work / "special", args.out / "special")
        if args.contact:
            contact(systems, args.contact / "systems-light.png", True)
            contact(systems, args.contact / "systems-dark.png", False)
            contact(tools, args.contact / "tools-light.png", True)
            contact(tools, args.contact / "tools-dark.png", False)
            contact(specials, args.contact / "special-light.png", True)
            contact(specials, args.contact / "special-dark.png", False)
    print("systems", len(systems), "tools", len(tools), "special", len(specials))


if __name__ == "__main__":
    main()
