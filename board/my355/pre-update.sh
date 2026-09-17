#!/bin/sh
# OTA hook. Runs from zlyme-update boot-apply after the tar is extracted
# and before kernel files are copied to /boot. Intentionally empty so a
# later image can replace this file without changing the updater.
exit 0
