# Artwork generation prompt

Copy everything below the line into a new chat with an image-generation assistant. Change only the two fields. Upload these files with the prompt:

- `resources/system-art-mask.svg` (the geometry)
- `resources/system-art-alpha.png` (the exact edge pixels)
- two to four existing `tools/<Name>.pak/background.png` files, as style examples

Inspect those files. Do not claim to match a style you have not seen. You do not need the Art Book archive. You draw one source picture. The firmware draws the name and the final wallpaper.

-----

PAK_NAME: Wi-Fi Manager
PAK_DESCRIPTION: Connect to and manage wireless networks on the handheld.

You are making one source illustration for a handheld game-launcher menu. You do not need to know the operating system. Read PAK_NAME and PAK_DESCRIPTION above. Those are the only facts about the subject.

Inspect the attached pictures before you draw. Match their detailed pixel-art treatment, object scale, and how full the silhouette is. Do not copy their subject. Do not switch to a modern glossy 3D look, a flat generic icon, or a photograph.

The attached `system-art-mask.svg` is the authoritative shape. Its viewBox is 453 by 1080. The source canvas is 454 by 1080. The picture is a tall semi-oblique parallelogram that slants left toward the bottom:

- top-left boundary near x=112
- top-right boundary near x=452
- middle-left boundary near x=56
- bottom-left boundary at x=0
- bottom-right boundary near x=339

The attached `system-art-alpha.png`, when present, is the authoritative edge. It is 454 by 1080. A fully filled copy of that silhouette has 122,128 pixels at alpha 0 and 2,290 pixels with alpha from 1 to 254. Those two counts are reference expectations for that mask. Do not report them as measurements of your file unless you counted them. Compare your alpha to the raster mask. The SVG does not rasterize to those exact edge pixels.

In the pinned Art Book artwork directory this firmware builds from, there are 213 PNGs: 202 are 454 by 1080, 6 are 301 by 720, and 5 are 134 by 320. The pictures this firmware actually composes are 52 unique stems: 49 are 454 by 1080, the Wii picture is 301 by 720, and the Neo Geo Pocket and Doom pictures are 134 by 320. Your file is the standard canvas, 454 by 1080. Do not use 640 by 480. That size is the firmware's finished wallpaper, not the source.

Output one PNG file named `background.png`.

- 454 pixels wide and 1080 pixels tall
- PNG, RGBA, with a real alpha channel
- alpha 0 outside the mask
- every visible pixel inside the mask
- antialiased diagonal edges, not a hard staircase and not a halo
- no glow, shadow, or decoration outside the silhouette
- no rectangular black background and no painted checkerboard
- no text, letters, captions, logos, or watermarks
- no commercial logos and no copyrighted game characters, unless PAK_DESCRIPTION explicitly names one and says to draw it
- a recognizable picture of what PAK_DESCRIPTION says
- similar density to the attached examples
- balanced saturation and contrast
- still clear after the firmware scales the height to 480 pixels

Keep the middle of the silhouette readable enough for a wordmark drawn on top of it. Do not leave the middle blank. The examples are full illustrations, and yours should be too.

The firmware generates the words in PAK_NAME as a white wordmark with a black contour and a black shadow. It centers that wordmark in the right-hand half of a 640 by 480 frame. If you paint those words, they will be on the picture twice. Do not paint them, and do not make the 640 by 480 frame.

A person will save your file as:

tools/<PAK_NAME>.pak/background.png

The directory name includes `.pak` and keeps the spaces in PAK_NAME. Example: PAK_NAME `Wi-Fi Manager` goes to `tools/Wi-Fi Manager.pak/background.png`. Rebuilding the firmware clips this file to the canonical alpha, scales it into the right-hand side of the 640 by 480 frame, and centers the name. You do not edit the compositor to add the name.

After you produce the file, inspect that file. Report only numbers you measured:

- width, height, and color mode
- count of pixels at alpha 0
- count of pixels with alpha from 1 to 254
- whether the alpha matches the attached raster mask
- the top, middle, and bottom left edges of the opaque picture
- that no visible pixel sits outside the mask
- that the file contains no readable text

Do not assert a size or an alpha count you did not measure.

If you cannot return a downloadable PNG, say that plainly. Do not invent a filename for a file that was not produced.
