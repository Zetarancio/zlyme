/*
 * MinUI-compatible toast: show.elf "message" [seconds]
 * NextUI paks call this after a toggle. Without it the panel only
 * shows the launching "-" and jumps back to Tools.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>

static TTF_Font *open_font(int size)
{
	static const char *paths[] = {
		"/usr/share/nextui/res/font1.ttf",
		"/usr/share/nextui/res/BPreplayBold-unhinted.otf",
		"/usr/share/minui/res/font1.ttf",
		"/usr/share/minui/res/BPreplayBold-unhinted.otf",
		NULL,
	};
	int i;

	for (i = 0; paths[i]; i++) {
		TTF_Font *font = TTF_OpenFont(paths[i], size);
		if (font)
			return font;
	}
	return NULL;
}

static int open_window(SDL_Window **window, SDL_Renderer **renderer)
{
	int tries;

	SDL_SetHint(SDL_HINT_VIDEODRIVER, "kmsdrm");
	SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengles2");
#ifdef SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER
	SDL_SetHint(SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER, "1");
#endif
	SDL_ShowCursor(SDL_DISABLE);

	for (tries = 0; tries < 80; tries++) {
		*window = SDL_CreateWindow("", SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_SHOWN);
		*renderer = *window ? SDL_CreateRenderer(*window, -1,
			SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) : NULL;
		if (*window && *renderer)
			return 0;
		if (*renderer)
			SDL_DestroyRenderer(*renderer);
		if (*window)
			SDL_DestroyWindow(*window);
		*window = NULL;
		*renderer = NULL;
		SDL_QuitSubSystem(SDL_INIT_VIDEO);
		SDL_Delay(25);
		if (SDL_InitSubSystem(SDL_INIT_VIDEO) < 0)
			return -1;
		SDL_ShowCursor(SDL_DISABLE);
	}
	return -1;
}

int main(int argc, char **argv)
{
	const char *msg = (argc > 1 && argv[1][0]) ? argv[1] : "OK";
	int secs = (argc > 2) ? atoi(argv[2]) : 2;
	SDL_Window *window = NULL;
	SDL_Renderer *renderer = NULL;
	TTF_Font *font;
	SDL_Surface *text;
	SDL_Texture *tex;
	SDL_Rect dst;
	int w, h;
	Uint32 t0;

	if (secs < 1)
		secs = 1;
	if (secs > 8)
		secs = 8;

	setenv("SDL_VIDEODRIVER", "kmsdrm", 0);

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		fprintf(stderr, "show.elf: SDL_Init: %s\n", SDL_GetError());
		puts(msg);
		sleep(secs);
		return 1;
	}
	if (TTF_Init() < 0) {
		fprintf(stderr, "show.elf: TTF_Init: %s\n", SDL_GetError());
		SDL_Quit();
		puts(msg);
		sleep(secs);
		return 1;
	}

	if (open_window(&window, &renderer) < 0) {
		fprintf(stderr, "show.elf: no KMSDRM after retries: %s\n",
			SDL_GetError());
		TTF_Quit();
		SDL_Quit();
		puts(msg);
		sleep((unsigned)secs > 3 ? 3 : (unsigned)secs);
		return 1;
	}

	font = open_font(32);
	if (!font) {
		fprintf(stderr, "show.elf: no font\n");
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
		TTF_Quit();
		SDL_Quit();
		puts(msg);
		sleep(secs);
		return 1;
	}

	SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
	text = TTF_RenderUTF8_Blended(font, msg,
		(SDL_Color){ 255, 255, 255, 255 });
	if (!text) {
		TTF_CloseFont(font);
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
		TTF_Quit();
		SDL_Quit();
		puts(msg);
		sleep(secs);
		return 1;
	}
	tex = SDL_CreateTextureFromSurface(renderer, text);
	w = text->w;
	h = text->h;
	SDL_FreeSurface(text);
	dst.w = w;
	dst.h = h;
	dst.x = (640 - w) / 2;
	dst.y = (480 - h) / 2;
	if (dst.x < 16)
		dst.x = 16;
	if (dst.y < 16)
		dst.y = 16;

	t0 = SDL_GetTicks();
	while ((SDL_GetTicks() - t0) < (Uint32)secs * 1000) {
		SDL_Event ev;

		while (SDL_PollEvent(&ev))
			;
		SDL_RenderClear(renderer);
		if (tex)
			SDL_RenderCopy(renderer, tex, NULL, &dst);
		SDL_RenderPresent(renderer);
		SDL_Delay(16);
	}

	if (tex)
		SDL_DestroyTexture(tex);
	TTF_CloseFont(font);
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	TTF_Quit();
	SDL_Quit();
	return 0;
}
