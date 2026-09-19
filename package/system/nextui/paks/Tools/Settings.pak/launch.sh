#!/bin/sh
# nextui.elf saveLast() points at this pak. Restore to the card root
# or the next session opens Settings.pak as a folder (launch.sh).
printf '%s' /storage > /tmp/last.txt
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
exec /usr/bin/settings.elf
