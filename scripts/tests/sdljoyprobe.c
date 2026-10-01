/* Temporary SDL joystick probe. Not installed in the image.
 * Build with the Zlyme aarch64 gcc and run under the DOOM.pak environment:
 *   SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0x045e/0x028e
 *   SDL_GAMECONTROLLERCONFIG_FILE=/usr/lib/gamecontrollerdb.txt
 *   ZLYME_JOY_MS=8000 ./sdljoyprobe
 * Press A/B, the D-pad, and a stick. event lines are SDL_JOYBUTTON/HAT.
 * poll lines are SDL_JoystickGetButton transitions.
 */
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void dump_open(int index)
{
	SDL_Joystick *j;
	SDL_JoystickGUID g;
	char guid[64];
	int b, a, h, i;

	printf("index=%d name=%s gamecontroller=%d\n", index,
		SDL_JoystickNameForIndex(index), SDL_IsGameController(index));
	j = SDL_JoystickOpen(index);
	if (!j) {
		printf("  open failed: %s\n", SDL_GetError());
		return;
	}
	g = SDL_JoystickGetGUID(j);
	SDL_JoystickGetGUIDString(g, guid, sizeof(guid));
	b = SDL_JoystickNumButtons(j);
	a = SDL_JoystickNumAxes(j);
	h = SDL_JoystickNumHats(j);
	printf("  guid=%s buttons=%d axes=%d hats=%d event_state=%d\n",
		guid, b, a, h, SDL_JoystickEventState(SDL_QUERY));
	printf("  poll-buttons");
	for (i = 0; i < b; i++)
		printf(" %d=%d", i, SDL_JoystickGetButton(j, i));
	printf("\n  poll-axes");
	for (i = 0; i < a; i++)
		printf(" %d=%d", i, SDL_JoystickGetAxis(j, i));
	printf("\n  poll-hats");
	for (i = 0; i < h; i++)
		printf(" %d=%d", i, SDL_JoystickGetHat(j, i));
	printf("\n");
	SDL_JoystickClose(j);
}

int main(void)
{
	int i, n, ms, elapsed;
	unsigned char prev[64];
	SDL_Joystick *j;
	SDL_Event ev;
	const char *wait;

	SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
	if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) != 0) {
		fprintf(stderr, "sdl init: %s\n", SDL_GetError());
		return 1;
	}
	n = SDL_NumJoysticks();
	printf("joysticks=%d event_state=%d\n", n,
		SDL_JoystickEventState(SDL_QUERY));
	for (i = 0; i < n; i++)
		dump_open(i);
	if (n < 1)
		return 0;
	j = SDL_JoystickOpen(0);
	if (!j)
		return 1;
	memset(prev, 0, sizeof(prev));
	wait = getenv("ZLYME_JOY_MS");
	ms = wait ? atoi(wait) : 1500;
	printf("watching %d ms\n", ms);
	for (elapsed = 0; elapsed < ms; elapsed += 20) {
		SDL_JoystickUpdate();
		while (SDL_PollEvent(&ev)) {
			if (ev.type == SDL_JOYBUTTONDOWN || ev.type == SDL_JOYBUTTONUP)
				printf("event %s button=%d\n",
					ev.type == SDL_JOYBUTTONDOWN ? "DOWN" : "UP",
					ev.jbutton.button);
			else if (ev.type == SDL_JOYHATMOTION)
				printf("event HAT hat=%d value=%d\n",
					ev.jhat.hat, ev.jhat.value);
			else if (ev.type == SDL_JOYAXISMOTION &&
				(ev.jaxis.value > 8000 || ev.jaxis.value < -8000))
				printf("event AXIS axis=%d value=%d\n",
					ev.jaxis.axis, ev.jaxis.value);
		}
		for (i = 0; i < SDL_JoystickNumButtons(j) && i < 64; i++) {
			unsigned char now = (unsigned char)SDL_JoystickGetButton(j, i);
			if (now != prev[i]) {
				printf("poll button %d %d -> %d\n", i, prev[i], now);
				prev[i] = now;
			}
		}
		SDL_Delay(20);
	}
	printf("watch done\n");
	SDL_JoystickClose(j);
	SDL_Quit();
	return 0;
}
