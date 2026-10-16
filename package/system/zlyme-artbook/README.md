# Tool artwork

Each built-in Tool pak has one source image:

`tools/<Exact Pak Name>.pak/background.png`

The directory name is the pak basename, including `.pak` and spaces. `Music Player.pak` draws the logo `Music Player`. The compositor adds the black contour and the shadow. It does not modify `background.png`.

A background may be any size. It is scaled to fit the right-hand 320×480 region without cropping, and the rest of the 640×480 frame stays transparent. PNG is the source format. The result is `tools/<Name>.png` under `/usr/share/nextui/artbook/`, RGBA, 640×480.

A shipped Tool without `background.png` fails the ArtBook build and names that pak. A background whose directory is not a shipped pak fails the same way. A pak a person installed later does not need a stock image.

The pictures are Zlyme drawings. System artwork is downloaded from Art Book Next and is not stored in this tree. Its license is CC BY-NC-SA 2.0, in `NOTICE.md`.

Regenerate inside the build container:

```sh
./build.sh --config zlyme_my355_defconfig zlyme-artbook
```

The container provides `python3-pil` 11.1.0-5+deb13u4 and `librsvg2-bin` 2.60.0+dfsg-1+deb13u1. Those versions are pinned in the Dockerfile. They are not installed on the Flip.
