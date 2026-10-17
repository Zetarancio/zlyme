#include "zlyme_drm_occupy.h"

#include <stdio.h>

static int fails;

static void check(int got, int want, const char *msg)
{
	if (got != want) {
		fprintf(stderr, "%s (got %d)\n", msg, got);
		fails++;
	}
}

int main(void)
{
	/* Atomic scanout: ACTIVE is set and the legacy framebuffer is 0. */
	check(zlyme_crtc_occupied(0, 0, 1, 0), 1, "active CRTC with no legacy fb was free");
	/* Plane owns the framebuffer. Legacy CRTC buffer is 0 and ACTIVE was read as 0. */
	check(zlyme_crtc_occupied(0, 0, 0, 1), 1, "plane framebuffer was ignored");
	/* The property or the plane list could not be read. */
	check(zlyme_crtc_occupied(0, 0, -1, 0), 1, "unread ACTIVE was treated as free");
	check(zlyme_crtc_occupied(0, 0, 0, -1), 1, "unread planes were treated as free");
	/* Legacy scanout still counts. */
	check(zlyme_crtc_occupied(4, 1, 0, 0), 1, "legacy framebuffer was ignored");
	/* Proven idle. */
	check(zlyme_crtc_occupied(0, 0, 0, 0), 0, "idle CRTC was taken");
	if (fails)
		return 1;
	printf("drm encoder pick ok\n");
	return 0;
}
