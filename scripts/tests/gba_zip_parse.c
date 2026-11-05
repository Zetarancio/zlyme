/* Host harness for the pinned RetroArch ZIP directory reader.
 * It links libretro-common/file/archive_file_zlib.c. The filestream
 * calls below are the file the reader seeks. They are not a second parser.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <file/archive_file.h>
#include <streams/file_stream.h>

struct RFILE
{
	FILE *fp;
};

int64_t filestream_seek(RFILE *stream, int64_t offset, int seek_position)
{
	if (!stream || seek_position != RETRO_VFS_SEEK_POSITION_START)
		return -1;
	if (fseeko(stream->fp, (off_t)offset, SEEK_SET) != 0)
		return -1;
	return offset;
}

int64_t filestream_read(RFILE *stream, void *data, int64_t len)
{
	size_t n;

	if (!stream || len < 0)
		return -1;
	n = fread(data, 1, (size_t)len, stream->fp);
	return (int64_t)n;
}

bool filestream_write_file(const char *path, const void *data, int64_t size)
{
	(void)path;
	(void)data;
	(void)size;
	return false;
}

uint32_t encoding_crc32(uint32_t crc, const uint8_t *buf, size_t len)
{
	(void)crc;
	(void)buf;
	(void)len;
	return 0;
}

int file_archive_parse_file_iterate(
		file_archive_transfer_t *state, bool *returnerr,
		const char *file, const char *valid_exts,
		file_archive_file_cb file_cb,
		struct archive_extract_userdata *userdata)
{
	(void)state;
	(void)returnerr;
	(void)file;
	(void)valid_exts;
	(void)file_cb;
	(void)userdata;
	return -1;
}

void file_archive_parse_file_iterate_stop(file_archive_transfer_t *state)
{
	(void)state;
}

static void print_hex(const unsigned char *buf, size_t len)
{
	size_t i;

	for (i = 0; i < len; i++)
		printf("%02x", buf[i]);
	printf("\n");
}

int main(int argc, char **argv)
{
	FILE *fp;
	RFILE stream;
	file_archive_transfer_t state;
	struct archive_extract_userdata userdata;
	off_t end;
	int step;
	int count = 0;

	if (argc != 2)
		return 2;
	fp = fopen(argv[1], "rb");
	if (!fp)
		return 1;
	if (fseeko(fp, 0, SEEK_END) != 0)
		return 1;
	end = ftello(fp);
	if (end < 22)
		return 1;
	if (fseeko(fp, 0, SEEK_SET) != 0)
		return 1;

	memset(&stream, 0, sizeof(stream));
	stream.fp = fp;
	memset(&state, 0, sizeof(state));
	state.archive_file = &stream;
	state.archive_size = (int64_t)end;
	if (zlib_backend.archive_parse_file_init(&state, argv[1]) != 0)
		return 1;

	memset(&userdata, 0, sizeof(userdata));
	for (;;)
	{
		size_t len;

		step = zlib_backend.archive_parse_file_iterate_step(
				state.context, NULL, &userdata, NULL);
		if (step != 1)
			break;
		len = strlen(userdata.current_file_path);
		print_hex((const unsigned char *)userdata.current_file_path, len);
		count++;
	}
	zlib_backend.archive_parse_file_free(state.context);
	fclose(fp);
	return count > 0 && step == 0 ? 0 : 1;
}
