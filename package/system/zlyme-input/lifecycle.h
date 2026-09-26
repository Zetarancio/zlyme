#ifndef ZLYME_INPUT_LIFECYCLE_H
#define ZLYME_INPUT_LIFECYCLE_H

/* Release is finished when the built-in composite and its gamepad target
 * are both gone. */
int zlyme_release_done(int composite_present, int gamepad_target_present);

/* Reclaim is finished when the built-in composite has a gamepad target. */
int zlyme_reclaim_done(int composite_present, int gamepad_target_present);

/* Owner loss returns the daemon to waiting. A new owner with a ready
 * Manager should activate again. Manager-not-ready must not be treated
 * as a fatal exit. */
int zlyme_should_activate(int has_owner, int manager_ready);
int zlyme_should_deactivate(int has_owner);

#endif
