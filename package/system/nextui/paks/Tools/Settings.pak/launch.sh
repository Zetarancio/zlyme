#!/bin/sh
# nextui.elf saveLast() points at this pak. Restore to the card root
# or the next session opens Settings.pak as a folder (launch.sh).
printf '%s' /storage > /tmp/last.txt
exec /usr/bin/settings.elf
