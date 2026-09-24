#pragma once

#include "menu.hpp"

struct SDL_Surface;

void ZlymeJoystick_setScreen(SDL_Surface *screen);
void Zlyme_appendJoystickItem(std::vector<AbstractMenuItem *> &items);
