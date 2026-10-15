#ifndef ZLYME_LID_POLICY_H
#define ZLYME_LID_POLICY_H

/*
 * One mem request for a lid close.
 *
 * NextUI owns the screen while it is running and calls the same mem
 * helper itself. zlyme-keylidmon owns the screen only after that
 * process has been seen and has exited (a pak). Boot, before the
 * frontend has appeared, does not treat a closed lid as a pak.
 *
 * A close while already suspended for this closed period is ignored.
 * The resume guard drops both a lid edge and a power edge. Opening
 * the lid clears that period. A switch sample that reads open is the
 * same transition, so a missed open event does not stick the period.
 * Power is still an explicit mem request
 * while the pak owns the screen, including when the lid is closed.
 * Failure still counts as the one request for this closed period so
 * a queued close cannot spin.
 */

enum {
	ZLYME_LID_EV_MENU = 1,
	ZLYME_LID_EV_PAK,
	ZLYME_LID_EV_CLOSE,
	ZLYME_LID_EV_OPEN,
	ZLYME_LID_EV_POWER
};

struct zlyme_lid_policy {
	int menu_seen;
	int menu_owns;
	int in_pak;
	int pak_latched;
	int lid_closed;
	int asleep;
	int busy;
	int mem_requests;
	int power_requests;
	int lid_requests;
};

/* 1 = run the existing mem sequence once. */
static inline int zlyme_lid_apply(struct zlyme_lid_policy *p, int ev, int guard)
{
	int want = 0;

	switch (ev) {
	case ZLYME_LID_EV_MENU:
		p->menu_seen = 1;
		p->menu_owns = 1;
		p->in_pak = 0;
		p->pak_latched = 0;
		break;
	case ZLYME_LID_EV_PAK:
		p->menu_owns = 0;
		if (!p->menu_seen || p->in_pak)
			break;
		p->in_pak = 1;
		p->pak_latched = 1;
		if (p->lid_closed && !p->asleep && !guard && !p->busy)
			want = 1;
		break;
	case ZLYME_LID_EV_CLOSE:
		p->lid_closed = 1;
		if (p->menu_owns || !p->in_pak || p->asleep || guard || p->busy)
			break;
		want = 1;
		break;
	case ZLYME_LID_EV_OPEN:
		p->lid_closed = 0;
		p->asleep = 0;
		break;
	case ZLYME_LID_EV_POWER:
		if (p->menu_owns || guard || p->busy)
			break;
		want = 1;
		break;
	default:
		break;
	}
	if (want) {
		p->busy = 1;
		if (ev == ZLYME_LID_EV_POWER)
			p->power_requests++;
		else
			p->lid_requests++;
	}
	return want;
}

/*
 * closed is 1, 0, or -1 when the switch could not be read.
 * Open uses the same path as an open event. Closed only records the
 * switch and does not start a new asleep period.
 */
static inline void zlyme_lid_observe(struct zlyme_lid_policy *p, int closed)
{
	if (closed < 0)
		return;
	if (closed == 0)
		zlyme_lid_apply(p, ZLYME_LID_EV_OPEN, 0);
	else
		p->lid_closed = 1;
}

/*
 * ok is 0 when the suspend helper failed. The closed period is still
 * consumed so the next queued close does not request mem again.
 */
static inline void zlyme_lid_suspend_done(struct zlyme_lid_policy *p, int ok)
{
	(void)ok;
	p->busy = 0;
	p->mem_requests++;
	if (p->lid_closed)
		p->asleep = 1;
}

/* NextUI lid-close edge. Screen timeout is not an argument. */
static inline int zlyme_frontend_lid_wants_mem(int close_edge, int still_closed,
	int resume_guard, int slept_for_this_close)
{
	if (!close_edge || !still_closed || resume_guard || slept_for_this_close)
		return 0;
	return 1;
}

#endif
