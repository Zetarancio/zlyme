#ifndef ZLYME_PAD_POLICY_H
#define ZLYME_PAD_POLICY_H

/* maintenance: Settings is using the physical Flip.
 * any_virtual: at least one application xb360 controller is open.
 * External and built-in virtual pads share a name, so maintenance is
 * the explicit exception that still opens the physical pad. */
static inline int zlyme_allow_physical(int maintenance, int any_virtual)
{
	return maintenance || !any_virtual;
}

/* Normal mode must not keep the physical pad open beside a virtual pad.
 * Maintenance may keep the physical pad open while an external virtual
 * pad remains. */
static inline int zlyme_builtin_duplicate(int maintenance, int physical_open,
					 int any_virtual)
{
	if (maintenance)
		return 0;
	return physical_open && any_virtual;
}

/* SDL keeps SDL_CONTROLLER_BUTTON_GUIDE down for at least
 * SDL_MINIMUM_GUIDE_BUTTON_DELAY_MS (250). NextUI uses that same
 * window to tell a menu tap from a brightness hold, so a short tap
 * arrives as a hold. MENU follows the raw guide button. The delayed
 * controller Guide event must not also change BTN_MENU. */
static inline int zlyme_accept_menu_event(int from_controller_guide, int raw_is_guide)
{
	if (from_controller_guide)
		return 0;
	return raw_is_guide ? 1 : 0;
}

#endif
