/* SPDX-License-Identifier: MIT */
#include <SDL.h>
#include <GL/gl.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned timeout_ms(void)
{
	const char *text = getenv("ZLYME_PROBE_SECONDS");
	char *end;
	long seconds;

	if (!text || text[0] == '\0')
		return 15000;
	seconds = strtol(text, &end, 10);
	if (*end != '\0' || seconds < 1 || seconds > 120)
		return 15000;
	return (unsigned)seconds * 1000U;
}

int main(void)
{
	SDL_Window *window = NULL;
	SDL_GLContext context = NULL;
	SDL_Event event;
	Uint32 started;
	unsigned long frames = 0;
	GLenum gl_error;
	int rc = 1;
	int done = 0;

	if (SDL_Init(SDL_INIT_VIDEO) != 0) {
		fprintf(stderr, "GL4ES_SDL_ERROR %s\n", SDL_GetError());
		return 1;
	}
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
	window = SDL_CreateWindow("Zlyme GL4ES probe", SDL_WINDOWPOS_UNDEFINED,
				  SDL_WINDOWPOS_UNDEFINED, 640, 480,
				  SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN);
	if (!window) {
		fprintf(stderr, "GL4ES_WINDOW_ERROR %s\n", SDL_GetError());
		goto out;
	}
	context = SDL_GL_CreateContext(window);
	if (!context) {
		fprintf(stderr, "GL4ES_CONTEXT_ERROR %s\n", SDL_GetError());
		goto out;
	}
	printf("GL4ES_READY vendor=%s renderer=%s version=%s\n",
	       (const char *)glGetString(GL_VENDOR),
	       (const char *)glGetString(GL_RENDERER),
	       (const char *)glGetString(GL_VERSION));
	fflush(stdout);
	started = SDL_GetTicks();
	while (!done && SDL_GetTicks() - started < timeout_ms()) {
		float phase = (float)(SDL_GetTicks() - started) / 500.0f;
		float offset = sinf(phase) * 0.2f;

		while (SDL_PollEvent(&event))
			if (event.type == SDL_QUIT || event.type == SDL_KEYDOWN ||
			    event.type == SDL_CONTROLLERBUTTONDOWN)
				done = 1;
		glViewport(0, 0, 640, 480);
		glClearColor(0.03f, 0.06f, 0.14f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		glBegin(GL_TRIANGLES);
		glColor3f(1.0f, 0.3f, 0.2f);
		glVertex2f(offset, 0.7f);
		glColor3f(0.2f, 1.0f, 0.4f);
		glVertex2f(-0.7f + offset, -0.6f);
		glColor3f(0.2f, 0.4f, 1.0f);
		glVertex2f(0.7f + offset, -0.6f);
		glEnd();
		SDL_GL_SwapWindow(window);
		frames++;
	}
	gl_error = glGetError();
	printf("GL4ES_DONE frames=%lu error=0x%x\n", frames, gl_error);
	rc = frames > 0 && gl_error == GL_NO_ERROR ? 0 : 2;
out:
	if (context)
		SDL_GL_DeleteContext(context);
	if (window)
		SDL_DestroyWindow(window);
	SDL_Quit();
	return rc;
}
