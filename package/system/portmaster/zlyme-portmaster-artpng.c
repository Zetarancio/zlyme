/*
 * JPEG to PNG for port artwork. The image's ffmpeg is built without
 * libswscale, so it cannot change a JPEG's pixel format. libjpeg and
 * libpng are already on the system.
 */
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>

#include <jpeglib.h>
#include <png.h>

#define ART_MAX_EDGE 8192

struct jpeg_fail {
	struct jpeg_error_mgr pub;
	jmp_buf jump;
};

static void jpeg_fail_exit(j_common_ptr cinfo)
{
	struct jpeg_fail *err = (struct jpeg_fail *)cinfo->err;

	longjmp(err->jump, 1);
}

static int write_png(const char *path, unsigned char *pixels, unsigned width, unsigned height)
{
	FILE *out;
	png_structp png;
	png_infop info;
	unsigned y;

	out = fopen(path, "wb");
	if (!out)
		return 1;
	png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!png) {
		fclose(out);
		return 1;
	}
	info = png_create_info_struct(png);
	if (!info) {
		png_destroy_write_struct(&png, NULL);
		fclose(out);
		return 1;
	}
	if (setjmp(png_jmpbuf(png))) {
		png_destroy_write_struct(&png, &info);
		fclose(out);
		return 1;
	}
	png_init_io(png, out);
	png_set_IHDR(png, info, width, height, 8, PNG_COLOR_TYPE_RGB,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
	png_write_info(png, info);
	for (y = 0; y < height; y++)
		png_write_row(png, pixels + (size_t)y * width * 3);
	png_write_end(png, info);
	png_destroy_write_struct(&png, &info);
	if (fclose(out) != 0)
		return 1;
	return 0;
}

int main(int argc, char **argv)
{
	FILE *in;
	struct jpeg_decompress_struct cinfo;
	struct jpeg_fail jerr;
	unsigned char *pixels = NULL;
	unsigned width;
	unsigned height;
	int rc = 1;

	if (argc != 3) {
		fprintf(stderr, "usage: zlyme-portmaster-artpng input.jpg output.png\n");
		return 2;
	}
	in = fopen(argv[1], "rb");
	if (!in) {
		fprintf(stderr, "zlyme-portmaster-artpng: cannot read JPEG\n");
		return 1;
	}
	cinfo.err = jpeg_std_error(&jerr.pub);
	jerr.pub.error_exit = jpeg_fail_exit;
	if (setjmp(jerr.jump)) {
		fprintf(stderr, "zlyme-portmaster-artpng: JPEG decode failed\n");
		jpeg_destroy_decompress(&cinfo);
		fclose(in);
		free(pixels);
		remove(argv[2]);
		return 1;
	}
	jpeg_create_decompress(&cinfo);
	jpeg_stdio_src(&cinfo, in);
	jpeg_read_header(&cinfo, TRUE);
	cinfo.out_color_space = JCS_RGB;
	jpeg_start_decompress(&cinfo);
	width = cinfo.output_width;
	height = cinfo.output_height;
	if (width == 0 || height == 0 || width > ART_MAX_EDGE || height > ART_MAX_EDGE
		|| cinfo.output_components != 3) {
		fprintf(stderr, "zlyme-portmaster-artpng: JPEG size is not usable\n");
		jpeg_destroy_decompress(&cinfo);
		fclose(in);
		return 1;
	}
	pixels = malloc((size_t)width * height * 3);
	if (!pixels) {
		jpeg_destroy_decompress(&cinfo);
		fclose(in);
		return 1;
	}
	while (cinfo.output_scanline < height) {
		unsigned char *row = pixels + (size_t)cinfo.output_scanline * width * 3;

		jpeg_read_scanlines(&cinfo, &row, 1);
	}
	jpeg_finish_decompress(&cinfo);
	jpeg_destroy_decompress(&cinfo);
	fclose(in);
	in = NULL;
	if (write_png(argv[2], pixels, width, height) != 0) {
		fprintf(stderr, "zlyme-portmaster-artpng: cannot write PNG\n");
		remove(argv[2]);
		free(pixels);
		return 1;
	}
	free(pixels);
	rc = 0;
	return rc;
}
