#ifndef ZLYME_HOTKEY_LOGIC_H
#define ZLYME_HOTKEY_LOGIC_H

/*
 * Exit chord is MENU+START on one virtual controller.
 * Buttons from two controllers must not combine.
 */
#include <linux/input.h>

static inline void zlyme_hotkey_reset(int *menu, int *start)
{
	*menu = 0;
	*start = 0;
}

/* down is nonzero for press and autorepeat. Returns 1 when this
 * controller now has both buttons down. */
static inline int zlyme_hotkey_apply(int *menu, int *start, unsigned code, int down)
{
	if (code == BTN_MODE)
		*menu = down ? 1 : 0;
	else if (code == BTN_START)
		*start = down ? 1 : 0;
	return *menu && *start;
}

#endif
