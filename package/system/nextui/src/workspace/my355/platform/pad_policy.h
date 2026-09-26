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

#endif
