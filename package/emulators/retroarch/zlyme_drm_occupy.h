#ifndef ZLYME_DRM_OCCUPY_H
#define ZLYME_DRM_OCCUPY_H

/* 1 when this CRTC must not be taken.
 * legacy_fb / legacy_mode_valid come from drmModeGetCrtc.
 * active is the CRTC ACTIVE property: 1 in use, 0 idle, -1 unread.
 * plane_fb is 1 when a plane on this CRTC has a framebuffer, 0 when
 * none do, and -1 when the plane list could not be read.
 * An unread ACTIVE or plane list is occupied. A zero legacy
 * framebuffer is not evidence that an atomic CRTC is free.
 */
static inline int zlyme_crtc_occupied(unsigned legacy_fb, int legacy_mode_valid,
				      int active, int plane_fb)
{
	if (legacy_fb != 0 && legacy_mode_valid)
		return 1;
	if (active != 0)
		return 1;
	if (plane_fb != 0)
		return 1;
	return 0;
}

#endif
