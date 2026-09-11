#!/bin/sh
# The joypad module already auto-calibrates the Miyoo UART1 stick
# about 10 s after probe. This pak just reports that.
msg="Stick autocal is in the driver"
if command -v show.elf >/dev/null 2>&1; then show.elf "$msg" 2; else echo "$msg"; sleep 2; fi
