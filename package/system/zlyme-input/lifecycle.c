#include "lifecycle.h"

int zlyme_release_done(int composite_present, int gamepad_target_present)
{
	return !composite_present && !gamepad_target_present;
}

int zlyme_reclaim_done(int composite_present, int gamepad_target_present)
{
	return composite_present && gamepad_target_present;
}

int zlyme_should_activate(int has_owner, int manager_ready)
{
	return has_owner && manager_ready;
}

int zlyme_should_deactivate(int has_owner)
{
	return !has_owner;
}
