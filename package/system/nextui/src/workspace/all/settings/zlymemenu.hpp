#pragma once

#include "menu.hpp"

// Compiled into settings.elf so these are not Tools paks.
InputReactionHint Zlyme_cycleHdmi(AbstractMenuItem &item);
void Zlyme_appendDisplayItems(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendNetworkItems(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendStatusLed(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendSystemItems(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendBackupItem(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendFactoryResetItem(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendStorageItems(std::vector<AbstractMenuItem *> &items);
void Zlyme_appendAboutLogs(std::vector<AbstractMenuItem *> &items);
