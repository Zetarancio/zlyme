/* Fluidsynth 2.4 linked SDL3 because cmake files were in staging.
 * We do not ship SDL3. These stubs satisfy DT_NEEDED; MIDI uses ALSA. */
#include <stdarg.h>
#include <stddef.h>

int SDL_WasInit(unsigned int flags) { (void)flags; return 0; }
int SDL_SetError(const char *fmt, ...) { (void)fmt; return -1; }
void *SDL_malloc(unsigned long n) { (void)n; return 0; }
void SDL_free(void *p) { (void)p; }
int SDL_asprintf(char **strp, const char *fmt, ...) { (void)strp; (void)fmt; return -1; }
void *SDL_CreateMutex(void) { return 0; }
void SDL_LockMutex(void *m) { (void)m; }
void SDL_UnlockMutex(void *m) { (void)m; }
const char *SDL_GetAudioDeviceName(int i, int iscap) { (void)i; (void)iscap; return 0; }
const char *SDL_GetCurrentAudioDriver(void) { return 0; }
void *SDL_GetAudioPlaybackDevices(int *n) { if (n) *n = 0; return 0; }
void *SDL_OpenAudioDeviceStream(unsigned int dev, const void *spec, void *cb, void *ud)
{ (void)dev; (void)spec; (void)cb; (void)ud; return 0; }
int SDL_ResumeAudioStreamDevice(void *s) { (void)s; return -1; }
void SDL_CloseAudioDevice(unsigned int dev) { (void)dev; }
int SDL_PauseAudioDevice(unsigned int dev) { (void)dev; return -1; }
unsigned int SDL_GetAudioStreamDevice(void *s) { (void)s; return 0; }
int SDL_PutAudioStreamData(void *s, const void *buf, int len)
{ (void)s; (void)buf; (void)len; return -1; }
