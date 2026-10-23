/* SPDX-License-Identifier: MIT */
#include <SDL3/SDL.h>

#include <stdio.h>
#include <stdlib.h>

static Uint64 timeout_ms(void)
{
	const char *text = getenv("ZLYME_PROBE_SECONDS");
	char *end;
	long seconds;

	if (!text || text[0] == '\0')
		return 60000;
	seconds = strtol(text, &end, 10);
	if (*end != '\0' || seconds < 1 || seconds > 120)
		return 60000;
	return (Uint64)seconds * 1000;
}

int main(void)
{
	SDL_Window *window = NULL;
	SDL_Renderer *renderer = NULL;
	SDL_Gamepad **pads = NULL;
	SDL_JoystickID *ids = NULL;
	SDL_Event event;
	SDL_FRect rect = { 120.0f, 90.0f, 400.0f, 300.0f };
	Uint64 started, deadline;
	unsigned long frames = 0;
	int count = 0;
	int opened = 0;
	int input = 0;
	int rc = 1;
	int i;

	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
		fprintf(stderr, "SDL3_INIT_ERROR %s\n", SDL_GetError());
		return 1;
	}
	if (!SDL_CreateWindowAndRenderer("Zlyme SDL3 KMS probe", 640, 480,
					 SDL_WINDOW_FULLSCREEN, &window, &renderer)) {
		fprintf(stderr, "SDL3_WINDOW_ERROR %s\n", SDL_GetError());
		goto out;
	}
	(void)SDL_SetRenderVSync(renderer, 1);
	ids = SDL_GetGamepads(&count);
	if (count > 0) {
		pads = SDL_calloc((size_t)count, sizeof *pads);
		if (!pads)
			goto out;
		for (i = 0; i < count; i++) {
			pads[i] = SDL_OpenGamepad(ids[i]);
			if (pads[i]) {
				opened++;
				printf("SDL3_PAD %s\n", SDL_GetGamepadName(pads[i]));
			}
		}
	}
	SDL_free(ids);
	ids = NULL;
	printf("SDL3_READY video=%s renderer=%s pads=%d\n",
	       SDL_GetCurrentVideoDriver(), SDL_GetRendererName(renderer), opened);
	fflush(stdout);
	started = SDL_GetTicks();
	deadline = started + timeout_ms();
	while (SDL_GetTicks() < deadline) {
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_EVENT_QUIT)
				goto rendered;
			if (event.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
				input = 1;
				printf("SDL3_INPUT button=%u\n", event.gbutton.button);
				fflush(stdout);
				deadline = SDL_GetTicks() + 2000;
			}
		}
		SDL_SetRenderDrawColor(renderer, (Uint8)(frames & 0xff), 24, 72, 255);
		SDL_RenderClear(renderer);
		SDL_SetRenderDrawColor(renderer, 245, 205, 66, 255);
		SDL_RenderFillRect(renderer, &rect);
		SDL_RenderPresent(renderer);
		frames++;
		SDL_Delay(1);
	}

rendered:
	printf("SDL3_DONE frames=%lu input=%d\n", frames, input);
	rc = frames > 0 && opened > 0 && input ? 0 : 2;
out:
	if (pads) {
		for (i = 0; i < count; i++)
			if (pads[i])
				SDL_CloseGamepad(pads[i]);
		SDL_free(pads);
	}
	SDL_free(ids);
	if (renderer)
		SDL_DestroyRenderer(renderer);
	if (window)
		SDL_DestroyWindow(window);
	SDL_Quit();
	return rc;
}
