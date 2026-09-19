ZLYME — GLASS AND METAL CIRCLE MASKS

Canvas: 1254 x 1254 pixels, exactly matching the supplied PNG.
Alignment: no crop, resize, rotation or padding. Top-left origin is (0, 0).
Convention: white = selected region; black = excluded/protected region.

FILES
zlyme_glass_mask.png
  The glass disk including its bright circular lip. Protruding exterior
  orange drips are not included in the circular glass selection.
zlyme_metal_ring_mask.png
  The surrounding circular bezel: dark inner seal and the main silver/copper
  metal band. It stops at the band's outer edge; the farther rusted housing
  and protruding drips are not a separate material selection. Where slime
  covers the ring, this mask selects the underlying ring-shaped region.
zlyme_glass_and_metal_mask.png
  Filled outer disk: glass plus metal ring, for tools that want one mask
  around the complete circular assembly rather than a ring-shaped mask.
zlyme_liquid_animation_mask.png
  Optional inset motion mask. Leaves about 32 pixels of the outer glass lip
  protected, helping animation stay inside the circle. It does not isolate
  every reflection or bubble within the glass.
zlyme_mask_alignment.png
  Diagnostic outline overlay, not a mask. Cyan: glass boundary.
  Blue: outer edge of metal band. Yellow: optional inset motion boundary.

VARIANTS
Root PNGs: 8-bit grayscale, subpixel antialiasing limited to boundary pixels;
  there is no added blur or broad feathering.
binary/: strictly 0 or 255 for tools that require a hard binary mask.
inverted/: black selects / white excludes, for tools using reversed polarity.
alpha/: white selection with transparent outside, for alpha-mask inputs.
vector/: corresponding editable SVG paths on the same 1254 x 1254 canvas.

PRECISION AND OCCLUSION
The visible contours were traced at source resolution and refined against
image edges. This is an image-derived trace, not an original object-ID pass.
Parts of the lower glass and metal are obscured by orange slime; those
sections continue the local circular contour and are therefore inferred.
The outer metal is cropped by the image on all four sides; nothing is
invented beyond the source canvas. The source contains opaque RGB artwork,
so it does not supply separate original alpha mattes for glass or metal.

USE
Load the unchanged original image and the selected same-size PNG mask.
For movement confined inside the lip, start with the liquid_animation mask.
For the whole glass disk, use glass_mask. For a full outer circular mask,
use glass_and_metal_mask. Follow your target tool's mask polarity setting.
These files provide selection geometry; how strictly an AI keeps geometry
depends on whether that tool supports and enforces motion/edit masks.
