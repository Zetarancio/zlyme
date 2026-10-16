#!/usr/bin/env python3
"""Compose transparent Zlyme Art Book overlays on the build host.

Upstream strips stay RGBA. Logos get a black contour and a 16px black
shadow at 50% opacity. Nothing is drawn under the scrolling names.
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import zlib
from pathlib import Path

WIDTH = 640
HEIGHT = 480
SAFE_X = 320
LOGO_MAX_W = 291
SHADOW = 16
OUTLINE = 2
PNG_SIG = b"\x89PNG\r\n\x1a\n"


def fail(msg: str) -> None:
    raise SystemExit("zlyme-artbook: " + msg)


def read_png(path: Path):
    data = path.read_bytes()
    if data[:8] != PNG_SIG:
        fail("not a png: " + path.name)
    pos = 8
    width = height = color = None
    idat = b""
    while pos + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit, color, comp, filt, inter = struct.unpack(">IIBBBBB", chunk)
            if bit != 8 or inter != 0 or color not in (2, 6) or comp or filt:
                fail("unsupported png: " + path.name)
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if width is None:
        fail("png has no header: " + path.name)
    raw = zlib.decompress(idat)
    bpp = 4 if color == 6 else 3
    stride = width * bpp
    rows = []
    prev = bytearray(stride)
    index = 0
    for _y in range(height):
        filt = raw[index]
        index += 1
        row = bytearray(raw[index:index + stride])
        index += stride
        if filt == 1:
            for i in range(stride):
                left = row[i - bpp] if i >= bpp else 0
                row[i] = (row[i] + left) & 255
        elif filt == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 255
        elif filt == 3:
            for i in range(stride):
                left = row[i - bpp] if i >= bpp else 0
                row[i] = (row[i] + ((left + prev[i]) // 2)) & 255
        elif filt == 4:
            for i in range(stride):
                left = row[i - bpp] if i >= bpp else 0
                up = prev[i]
                ul = prev[i - bpp] if i >= bpp else 0
                p = left + up - ul
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - ul)
                pred = left if pa <= pb and pa <= pc else up if pb <= pc else ul
                row[i] = (row[i] + pred) & 255
        elif filt != 0:
            fail("bad png filter in " + path.name)
        if color == 2:
            rgba = bytearray(width * 4)
            for x in range(width):
                rgba[x * 4:x * 4 + 3] = row[x * 3:x * 3 + 3]
                rgba[x * 4 + 3] = 255
            row = rgba
        prev = row
        rows.append(row)
    return width, height, rows


def write_png(path: Path, width: int, height: int, rows) -> None:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = PNG_SIG + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def blank():
    return [bytearray(WIDTH * 4) for _ in range(HEIGHT)]


def scale(rows, width, height, dw, dh):
    out = []
    for y in range(dh):
        sy = min(height - 1, int(y * height / dh))
        src = rows[sy]
        row = bytearray(dw * 4)
        for x in range(dw):
            sx = min(width - 1, int(x * width / dw))
            row[x * 4:x * 4 + 4] = src[sx * 4:sx * 4 + 4]
        out.append(row)
    return out


def over(dst, src, dx, dy):
    sh = len(src)
    sw = len(src[0]) // 4
    dh = len(dst)
    for y in range(sh):
        yy = dy + y
        if yy < 0 or yy >= dh:
            continue
        drow = dst[yy]
        srow = src[y]
        for x in range(sw):
            xx = dx + x
            if xx < 0 or xx >= WIDTH:
                continue
            si = x * 4
            di = xx * 4
            sa = srow[si + 3]
            if sa == 0:
                continue
            if sa == 255:
                drow[di:di + 4] = srow[si:si + 4]
                continue
            da = drow[di + 3]
            inv = 255 - sa
            out_a = sa + (da * inv + 127) // 255
            if out_a == 0:
                continue
            for c in range(3):
                drow[di + c] = (srow[si + c] * sa + drow[di + c] * da * inv // 255 + out_a // 2) // out_a
            drow[di + 3] = out_a


def alpha_of(rows):
    h = len(rows)
    w = len(rows[0]) // 4
    return w, h, bytearray(rows[y][x * 4 + 3] for y in range(h) for x in range(w))


def dilate(alpha, w, h, radius):
    """Square spread of `radius` pixels. Two passes keep it fast."""
    tmp = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            best = 0
            for xx in range(max(0, x - radius), min(w, x + radius + 1)):
                value = alpha[row + xx]
                if value > best:
                    best = value
            tmp[row + x] = best
    out = bytearray(w * h)
    for x in range(w):
        for y in range(h):
            best = 0
            for yy in range(max(0, y - radius), min(h, y + radius + 1)):
                value = tmp[yy * w + x]
                if value > best:
                    best = value
            out[y * w + x] = best
    return out


def from_alpha(alpha, w, h, rgb, scale_a):
    rows = []
    for y in range(h):
        row = bytearray(w * 4)
        for x in range(w):
            a = alpha[y * w + x]
            if scale_a != 255:
                a = a * scale_a // 255
            i = x * 4
            row[i:i + 3] = rgb
            row[i + 3] = a
        rows.append(row)
    return rows


def rsvg(binary: str, source: Path, width: int, height: int, font: Path) -> Path:
    out = source.with_suffix(".render.png")
    if source.suffix == ".svg" and "ZlymeWord" in source.read_text(encoding="utf-8"):
        # The caller already rewrote the font URL.
        pass
    subprocess.run(
        [binary, "-w", str(width), "-h", str(height), "-o", str(out), str(source)],
        check=True,
    )
    return out


def styled_logo(rows):
    """Black 16px shadow at 50%, then a 2px black contour, then the logo."""
    w, h, alpha = alpha_of(rows)
    pad = SHADOW
    pw, ph = w + pad * 2, h + pad * 2
    big = bytearray(pw * ph)
    for y in range(h):
        for x in range(w):
            big[(y + pad) * pw + (x + pad)] = alpha[y * w + x]
    shadow = dilate(big, pw, ph, SHADOW)
    outline = dilate(big, pw, ph, OUTLINE)
    canvas = [bytearray(pw * 4) for _ in range(ph)]
    over(canvas, from_alpha(shadow, pw, ph, b"\x00\x00\x00", 128), 0, 0)
    over(canvas, from_alpha(outline, pw, ph, b"\x00\x00\x00", 255), 0, 0)
    over(canvas, rows, pad, pad)
    return canvas


def fit_logo(rows, max_w):
    w = len(rows[0]) // 4
    h = len(rows)
    if w <= max_w and h <= 220:
        return rows
    scale_n = min(max_w / w, 220 / h)
    return scale(rows, w, h, max(1, int(w * scale_n)), max(1, int(h * scale_n)))


def content_box(rows):
    w = len(rows[0]) // 4
    h = len(rows)
    minx, miny, maxx, maxy = w, h, -1, -1
    transparent = 0
    for y, row in enumerate(rows):
        for x in range(w):
            a = row[x * 4 + 3]
            if a == 0:
                transparent += 1
                continue
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)
    return minx, miny, maxx, maxy, transparent


def place_logo(canvas, logo):
    lw = len(logo[0]) // 4
    lh = len(logo)
    if lw > LOGO_MAX_W:
        fail("logo wider than %d" % LOGO_MAX_W)
    region = WIDTH - SAFE_X
    x = SAFE_X + (region - lw) // 2
    y = (HEIGHT - lh) // 2
    if x < SAFE_X or x + lw > WIDTH or y < 0 or y + lh > HEIGHT:
        fail("logo leaves the safe frame")
    over(canvas, logo, x, y)
    return x, y, lw, lh


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


def render_svg(rsvg_bin, svg: Path, font: Path, width: int, height: int, work: Path):
    text = svg.read_text(encoding="utf-8")
    text = text.replace("FONTFILE", font.resolve().as_uri())
    temp = work / (svg.stem + ".svg")
    temp.write_text(text, encoding="utf-8")
    png = work / (svg.stem + ".png")
    subprocess.run([rsvg_bin, "-w", str(width), "-h", str(height), "-o", str(png), str(temp)], check=True)
    return read_png(png)


def compose_system(art_png: Path, logo_svg: Path, font: Path, rsvg_bin: str, work: Path):
    aw, ah, arows = read_png(art_png)
    dw = max(1, int(aw * HEIGHT / ah))
    art = scale(arows, aw, ah, dw, HEIGHT)
    canvas = blank()
    over(canvas, art, WIDTH - dw, 0)
    _lw, _lh, lrows = render_svg(rsvg_bin, logo_svg, font, 400, 120, work)
    logo = styled_logo(fit_logo(lrows, LOGO_MAX_W - SHADOW * 2))
    logo = fit_logo(logo, LOGO_MAX_W)
    place_logo(canvas, logo)
    return canvas


def compose_tool(icon_svg: Path, label: str, font: Path, rsvg_bin: str, work: Path):
    canvas = blank()
    _w, _h, icon = render_svg(rsvg_bin, icon_svg, font, 180, 260, work)
    icon = scale(icon, len(icon[0]) // 4, len(icon), 160, 230)
    over(canvas, icon, WIDTH - 180, 40)
    word = work / (icon_svg.stem + "-word.svg")
    word.write_text(
        """<svg xmlns="http://www.w3.org/2000/svg" width="400" height="80">
<style>@font-face { font-family: ZlymeWord; src: url("FONTFILE"); }</style>
<text x="0" y="64" font-family="ZlymeWord" font-size="42" fill="#ffffff">%s</text>
</svg>
""" % label.replace("&", "&amp;"),
        encoding="utf-8",
    )
    _lw, _lh, lrows = render_svg(rsvg_bin, word, font, 400, 80, work)
    logo = styled_logo(fit_logo(lrows, LOGO_MAX_W - SHADOW * 2))
    logo = fit_logo(logo, LOGO_MAX_W)
    lw = len(logo[0]) // 4
    lh = len(logo)
    x = SAFE_X + ((WIDTH - SAFE_X) - lw) // 2
    over(canvas, logo, x, HEIGHT - lh - 24)
    return canvas


def contact(images, dest: Path, light: bool):
    columns = 6
    tw, th = 160, 120
    rows_n = (len(images) + columns - 1) // columns
    sheet = [bytearray(columns * tw * 4) for _ in range(rows_n * th)]
    bg = (236, 232, 224, 255) if light else (16, 16, 18, 255)
    for row in sheet:
        for i in range(0, len(row), 4):
            row[i:i + 4] = bytes(bg)
    for index, (_name, rows) in enumerate(images):
        thumb = scale(rows, WIDTH, HEIGHT, tw, th)
        ox = (index % columns) * tw
        oy = (index // columns) * th
        over(sheet, thumb, ox, oy)
    # The contact sheet is an inspection image. Flatten after the overlay
    # so the checker of transparency is the chosen background, not alpha.
    write_png(dest, columns * tw, rows_n * th, sheet)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument("--tools", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--rsvg", default="rsvg-convert")
    parser.add_argument("--contact", type=Path)
    args = parser.parse_args()
    art_dir = args.upstream / "_inc" / "systems" / "artwork"
    logo_dir = args.upstream / "_inc" / "systems" / "logos"
    if not art_dir.is_dir():
        fail("upstream artwork is missing")
    work = args.out / ".work"
    work.mkdir(parents=True, exist_ok=True)
    systems = []
    for tag, stem, label in load_map(args.map):
        if stem is None:
            custom = args.tools / "custom" / (tag + ".svg")
            if not custom.is_file():
                fail("missing custom art for " + tag)
            image = compose_tool(custom, label, args.font, args.rsvg, work)
        else:
            image = compose_system(art_dir / (stem + ".png"), logo_dir / (stem + ".svg"), args.font, args.rsvg, work)
        dest = args.out / "system" / ("(%s).png" % tag)
        write_png(dest, WIDTH, HEIGHT, image)
        systems.append((tag, image))
    tools = []
    for line in (args.tools / "tools.txt").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        svg = args.tools / (line + ".svg")
        if not svg.is_file():
            fail("missing tool art " + line)
        image = compose_tool(svg, line, args.font, args.rsvg, work)
        write_png(args.out / "tools" / (line + ".png"), WIDTH, HEIGHT, image)
        tools.append((line, image))
    if args.contact:
        contact(systems, args.contact / "systems-light.png", True)
        contact(systems, args.contact / "systems-dark.png", False)
        contact(tools, args.contact / "tools-light.png", True)
        contact(tools, args.contact / "tools-dark.png", False)
    print("systems", len(systems), "tools", len(tools))


if __name__ == "__main__":
    main()
