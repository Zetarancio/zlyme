# Art Book mask

`system-art-mask.svg` is the mask from Art Book Next, commit `d772d07109701d9bd7c9fda305bfef6601105ab8`, file `resources/artwork-masks/system-art-mask.svg`. Anthony Caccese. License CC BY-NC-SA 2.0, the same statement as the rest of that theme. The viewBox is 453×1080. The path data is the upstream file, unchanged.

`system-art-alpha.png` is the alpha channel shared by the nine Tool backgrounds in this package. It is 454×1080, with 122,128 fully transparent pixels and 2,290 partially transparent pixels. It was copied from those PNGs. It is not a render of the SVG. An SVG rasterizer does not produce the same edge pixels.

The two agree on the parallelogram: upper left near x=112, upper right near x=452, lower left at x=0, lower right near x=340.

The compositor clips a 454×1080 tool background to this alpha. A pixel that is already inside the shape keeps its color and its alpha. This directory is the reference for a new picture. The upstream system-art library is not stored here.
