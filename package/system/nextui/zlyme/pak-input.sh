# SDL in a pak should see InputPlumber xb360 targets and not the
# physical Flip pad. SDL drops every joystick whose id is not 045e:028e,
# so the virtual pad is joystick 0. Do not export this for nextui.elf:
# NextUI still needs the physical pad before InputPlumber is up, and
# for Settings maintenance.
export SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT="${SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:-0x045e/0x028e}"
export SDL_GAMECONTROLLERCONFIG_FILE="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"
