# Artwork generation prompt

Copy everything below the line into a new chat with an image-generation assistant. Change only the two fields. Upload these files with the prompt:

- `resources/system-art-mask.svg`
- `resources/system-art-alpha.png` (optional; the raster alpha to check against)
- two to four existing `tools/<Name>.pak/background.png` files from this package, as style examples

You do not need the Art Book archive. The package draws the name. You draw the picture.

-----

PAK_NAME: Wi-Fi Manager
PAK_DESCRIPTION: Connect to and manage wireless networks on the handheld.

You are making one source illustration for a handheld game-launcher menu. You do not need to know the operating system. Read PAK_NAME and PAK_DESCRIPTION above. Those are the only facts about the subject. Inspect the attached pictures and the attached mask before you draw.

The attached PNG examples are the style to match: detailed pixel art, a dark transparent surround, and a tall semi-oblique parallelogram. Match that density and that silhouette. Do not copy their subject.

The attached `system-art-mask.svg` is the shape. Its viewBox is 453 by 1080. The artwork canvas is 454 by 1080. The picture is a parallelogram:

- upper-left boundary near x=112
- lower-left boundary at x=0
- upper-right boundary near x=453
- lower-right boundary near x=340

Follow those diagonal edges. Keep the illustration inside them. If a raster alpha mask was attached, the opaque picture must sit inside that alpha. Pixels outside the parallelogram are fully transparent. A black rectangle with a diagonal drawing inside it is wrong. The transparency itself is the parallelogram.

Create a new, original illustration of what PAK_DESCRIPTION says. Make the composition detailed enough to stay readable after it is reduced to 480 pixels tall.

Output one PNG file named `background.png`.

- 454 pixels wide, 1080 pixels tall
- RGBA, with a real alpha channel
- antialiased diagonal edges, not a hard staircase and not a halo
- no text, letters, labels, logos, or watermarks
- no commercial logos and no copyrighted game characters, unless PAK_DESCRIPTION explicitly names one and says to draw it
- no black rectangular background
- not a 640 by 480 wallpaper

The menu draws the words in PAK_NAME itself, in white, with a black outline and a shadow, over the lower part of the picture. If you paint those words, they will be on the picture twice. Do not paint them.

A person will save your file as:

tools/<PAK_NAME>.pak/background.png

The directory name includes `.pak` and keeps the spaces in PAK_NAME. Example: PAK_NAME `Wi-Fi Manager` goes to `tools/Wi-Fi Manager.pak/background.png`. Rebuilding the image package clips this file to the canonical alpha, scales it into the right-hand side of a 640 by 480 frame, and adds the name. You do not make that frame, and you do not edit the compositor to add the name.

After you produce the file, inspect it. Measure the width, height, and color mode. Count pixels whose alpha is 0 and pixels whose alpha is between 1 and 254. Check that the top edge of the opaque picture starts near x=112, the bottom edge starts at x=0, and the corners outside the parallelogram are fully transparent. Report those measurements from the file you actually wrote. Do not assert a size or an alpha count you did not measure.

If you cannot return a downloadable PNG, say that plainly. Do not invent a filename for a file that was not produced.
