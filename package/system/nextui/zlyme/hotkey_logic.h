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

/* 1 only when pid is a living session leader of some other session.
 * A dead pid is refused: the number may be reused, and the spawn
 * helper is what reaps members after the leader exits. */
static inline int zlyme_hotkey_may_signal(int our_sid, int alive, int pid,
					  int pgid, int sid)
{
	if (!alive || pid <= 1 || our_sid <= 1)
		return 0;
	if (sid == our_sid || pgid == our_sid)
		return 0;
	if (pgid != pid || sid != pid)
		return 0;
	return 1;
}

/* Revalidate after the TERM grace. The numeric session id alone is
 * not an identity once its leader has exited. */
static inline int zlyme_hotkey_same_target(int our_sid, int alive, int pid,
					   int pgid, int sid,
					   unsigned long long starttime,
					   int old_pgid, int old_sid,
					   unsigned long long old_starttime)
{
	if (!zlyme_hotkey_may_signal(our_sid, alive, pid, pgid, sid))
		return 0;
	return pgid == old_pgid && sid == old_sid &&
	       starttime == old_starttime;
}

#endif
