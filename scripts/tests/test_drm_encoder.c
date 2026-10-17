/* Same CRTC choice as the RetroArch unbound-connector patch:
 * the first possible_crtcs bit that is not already scanning.
 * A scanning CRTC is left alone.
 */
#include <stdio.h>

static int pick_free_crtc(unsigned possible, const int *scanning, int n, int *index)
{
	int c;

	if (!index || !scanning || n <= 0 || n > 31)
		return 0;
	for (c = 0; c < n; c++) {
		if ((possible & (1u << c)) == 0)
			continue;
		if (scanning[c])
			continue;
		*index = c;
		return 1;
	}
	return 0;
}

int main(void)
{
	int index = -1;
	int panel_busy[2] = { 1, 0 };
	int both_busy[2] = { 1, 1 };
	int hdmi_only[1] = { 0 };
	int fails = 0;

	if (!pick_free_crtc(0x3, panel_busy, 2, &index) || index != 1) {
		fprintf(stderr, "panel CRTC was taken or the free CRTC was missed\n");
		fails++;
	}
	if (pick_free_crtc(0x1, panel_busy, 2, &index)) {
		fprintf(stderr, "the only possible CRTC was the busy panel\n");
		fails++;
	}
	if (pick_free_crtc(0x3, both_busy, 2, &index)) {
		fprintf(stderr, "both scanning CRTCs were eligible\n");
		fails++;
	}
	index = -1;
	if (!pick_free_crtc(0x1, hdmi_only, 1, &index) || index != 0) {
		fprintf(stderr, "a free HDMI CRTC was refused\n");
		fails++;
	}
	if (fails)
		return 1;
	printf("drm encoder pick ok\n");
	return 0;
}
