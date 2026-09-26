# Index of the first InputPlumber xb360 target in SDL joystick order.
# SDL numbers /dev/input/js* in directory order. The index is derived
# from the evdev name and a /devices/virtual/ sysfs node, not from a
# fixed jsN. Empty output means no virtual target was found.
# Optional argument is a fixture root for tests.
zlyme_virtpad_js_index() {
	root=${1:-}
	dev=$root/dev/input
	sys=$root/sys/class/input
	idx=0
	found=
	js=

	for js in "$dev"/js*; do
		base=${js##*/}
		name=
		link=
		[ -e "$js" ] || continue
		[ -r "$sys/$base/device/name" ] && name=$(cat "$sys/$base/device/name")
		link=$(readlink "$sys/$base" 2>/dev/null || true)
		if [ "$name" = "Microsoft X-Box 360 pad" ]; then
			case "$link" in
			*/devices/virtual/*)
				[ -n "$found" ] || found=$idx
				;;
			esac
		fi
		idx=$((idx + 1))
	done
	printf '%s' "$found"
}
