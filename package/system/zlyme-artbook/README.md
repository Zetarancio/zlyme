# Tool artwork

Each built-in Tool pak has one source image:

`tools/<Exact Pak Name>.pak/background.png`

The directory name is the pak basename, including `.pak` and spaces. `Music Player.pak` draws the logo `Music Player`. The compositor adds the black contour and the shadow, then centers that whole mark in the right-hand half of the 640×480 frame. System logos use the same center. It does not modify `background.png`. There is no per-tool logo file. A new pak needs a picture and a directory; the name on the picture comes from the directory.

A tool background is a 454×1080 RGBA PNG. The compositor clips its alpha to `resources/system-art-alpha.png`, then scales it into the right-hand 320×480 region without cropping. The rest of the 640×480 frame stays transparent. The result is `tools/<Name>.png` under `/usr/share/nextui/artbook/`.

The mask, the copyable generation prompt, and how to add another picture are in [ARTWORK_GENERATION_PROMPT.md](ARTWORK_GENERATION_PROMPT.md). The SVG and the raster alpha are in [resources/README.md](resources/README.md).

A shipped Tool without `background.png` fails the ArtBook build and names that pak. A background whose directory is not a shipped pak fails the same way. A pak a person installed later does not need a stock image.

The finished PNGs are installed into the squashfs at `/usr/share/nextui/artbook`. NextUI selects this package. The full image and the normal OTA both carry that squashfs. The Flip does not download an artwork pack.

Recently Played is not a pak. Its source is `special/Recently Played/background.png`. The firmware file is `special/recent.png`, with the centered wordmark `Recently Played`. `zlyme-stock-seed` copies that file to `/storage/Recently Played/.media/bg.png` once. NextUI reads it as a folder picture, so a long name is not kept off the artwork.

The nine tool pictures are original illustrations made for these menus. RPG Maker XP is a separate picture under `tools/custom/MKXPZ/`. System artwork is downloaded from Art Book Next at build time and is not stored in this tree. Its license is CC BY-NC-SA 2.0, in `NOTICE.md`.

Regenerate inside the build container:

```sh
./build.sh --config zlyme_my355_defconfig zlyme-artbook
```

The container provides `python3-pil` 11.1.0-5+deb13u4 and `librsvg2-bin` 2.60.0+dfsg-1+deb13u1. Those versions are pinned in the Dockerfile. They are not installed on the Flip.
