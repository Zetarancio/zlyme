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
		"/storage/.system/res/font1.ttf",
		"/storage/.system/res/BPreplayBold-unhinted.otf",
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

int main(int argc, char **argv)
{
	const char *msg = (argc > 1 && argv[1][0]) ? argv[1] : "OK";
	int secs = (argc > 2) ? atoi(argv[2]) : 2;
	SDL_Window *window;
	SDL_Renderer *renderer;
	TTF_Font *font;
	SDL_Surface *text;
	SDL_Texture *tex;
	SDL_Rect dst;
	int w, h;

	if (secs < 1)
		secs = 1;
	if (secs > 8)
		secs = 8;

	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		fprintf(stderr, "show.elf: SDL_Init: %s\n", SDL_GetError());
		puts(msg);
		sleep(secs);
		return 1;
	}
	if (TTF_Init() < 0) {
		fprintf(stderr, "show.elf: TTF_Init: %s\n", TTF_GetError());
		SDL_Quit();
		puts(msg);
		sleep(secs);
		return 1;
	}
	SDL_ShowCursor(SDL_DISABLE);
	SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengles2");

	window = SDL_CreateWindow("", SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED, 640, 480, SDL_WINDOW_SHOWN);
	renderer = window ? SDL_CreateRenderer(window, -1,
		SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) : NULL;
	font = open_font(32);
	if (!window || !renderer || !font) {
		fprintf(stderr, "show.elf: init failed: %s / %s\n",
			SDL_GetError(), TTF_GetError());
		if (font)
			TTF_CloseFont(font);
		if (renderer)
			SDL_DestroyRenderer(renderer);
		if (window)
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

	SDL_RenderClear(renderer);
	if (tex)
		SDL_RenderCopy(renderer, tex, NULL, &dst);
	SDL_RenderPresent(renderer);
	SDL_Delay((Uint32)secs * 1000);

	if (tex)
		SDL_DestroyTexture(tex);
	TTF_CloseFont(font);
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	TTF_Quit();
	SDL_Quit();
	return 0;
}
