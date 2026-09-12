#!/bin/sh
# NextUI minarch is not built yet. Community paks still exec minarch.elf
# with a libretro core and a ROM. Forward that to RetroArch.
core=
rom=
for a in "$@"; do
	case "$a" in
		*.so) core=$a ;;
		-*) ;;
		*)
			if [ -z "$rom" ] && [ -e "$a" ]; then
				rom=$a
			fi
			;;
	esac
done
if [ -n "$core" ]; then
	if [ -n "$rom" ]; then
		exec ra-run -L "$core" "$rom"
	fi
	exec ra-run -L "$core"
fi
exec ra-run "$@"
