/* The pinned player lists libtinyalsa.so.2 and does not call it.
 * Playback goes through SDL. This only satisfies the dynamic linker. */
void zlyme_tinyalsa_unused(void) {}
