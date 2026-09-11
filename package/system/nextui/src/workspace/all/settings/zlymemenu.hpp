#pragma once

#include "menu.hpp"

// Zlyme pages compiled into settings.elf so SSH/Samba/Syncthing/GPU/Backup
// (and HDMI under Display) are not Tools paks.
InputReactionHint Zlyme_cycleHdmi(AbstractMenuItem &item);
MenuList *Zlyme_makeMenu();
