#include <SDL.h>

/* Cross-compiled against the target SDL. It is not executed here:
 * KMSDRM needs the Flip's DRM device. */
int main(void)
{
	SDL_Window *window;

	if (SDL_Init(SDL_INIT_VIDEO) != 0)
		return 1;
	window = SDL_CreateWindow("zlyme-sdl-probe",
				  SDL_WINDOWPOS_UNDEFINED,
				  SDL_WINDOWPOS_UNDEFINED,
				  640, 480, 0);
	if (window)
		SDL_DestroyWindow(window);
	SDL_Quit();
	return window ? 0 : 2;
}
