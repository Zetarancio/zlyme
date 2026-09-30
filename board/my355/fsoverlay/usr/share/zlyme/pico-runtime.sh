# Shared native PICO-8 runtime discovery.
# A runtime is the pair pico8_64 + pico8.dat.
# Search order matches Phase 9J: the ROM library BIOS first when a
# caller sets BIOS, then every root in the library registry, then the
# main card if that registry is missing.
#
# ZLYME_PICO_LIBRARIES is a test seam for the registry path.

zlyme_pico_pair_ok() {
	[ -f "$1/pico8_64" ] && [ -f "$1/pico8.dat" ]
}

zlyme_pico_consider() {
	d=$1
	tried=$2
	[ -n "$d" ] || return 1
	if grep -Fxq -- "$d" "$tried" 2>/dev/null; then
		return 1
	fi
	printf '%s\n' "$d" >> "$tried"
	if zlyme_pico_pair_ok "$d"; then
		ZLYME_PICO_LAUNCH=$d
		return 0
	fi
	return 1
}

zlyme_pico_consider_bios() {
	root=$1
	tried=$2
	[ -n "$root" ] || return 1
	zlyme_pico_consider "$root/PICO" "$tried" && return 0
	zlyme_pico_consider "$root/PICO/aarch64" "$tried" && return 0
	zlyme_pico_consider "$root/PICO-8" "$tried" && return 0
	zlyme_pico_consider "$root" "$tried" && return 0
	return 1
}

# Sets ZLYME_PICO_LAUNCH. Optional $1 is a BIOS directory to try first
# (the ROM library). Returns 0 when a pair is found.
zlyme_pico_find() {
	first=${1:-}
	ZLYME_PICO_LAUNCH=
	tried=$(mktemp) || return 1
	if [ -n "$first" ]; then
		zlyme_pico_consider_bios "$first" "$tried" || true
	fi
	libs=${ZLYME_PICO_LIBRARIES:-/run/zlyme/libraries}
	if [ -z "$ZLYME_PICO_LAUNCH" ] && [ -r "$libs" ]; then
		while IFS= read -r lib || [ -n "$lib" ]; do
			[ -n "$lib" ] || continue
			zlyme_pico_consider_bios "$lib/Bios" "$tried" && break
		done < "$libs"
	elif [ -z "$ZLYME_PICO_LAUNCH" ]; then
		zlyme_pico_consider_bios /storage/Bios "$tried" || true
	fi
	rm -f "$tried"
	[ -n "$ZLYME_PICO_LAUNCH" ]
}

# True when any active library has a complete pair. Does not prefer a
# ROM-local BIOS; Splore visibility only cares that one exists.
zlyme_pico_any() {
	ZLYME_PICO_LAUNCH=
	tried=$(mktemp) || return 1
	libs=${ZLYME_PICO_LIBRARIES:-/run/zlyme/libraries}
	found=1
	if [ -r "$libs" ]; then
		while IFS= read -r lib || [ -n "$lib" ]; do
			[ -n "$lib" ] || continue
			if zlyme_pico_consider_bios "$lib/Bios" "$tried"; then
				found=0
				break
			fi
		done < "$libs"
	else
		zlyme_pico_consider_bios /storage/Bios "$tried" && found=0
	fi
	rm -f "$tried"
	return "$found"
}
