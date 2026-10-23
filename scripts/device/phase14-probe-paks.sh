#!/bin/sh
# SPDX-License-Identifier: MIT
# Install or remove disposable Tools entries for normal NextUI launch of
# the image's Phase 14 graphics probes. Run on the Flip; no game data or
# user configuration is touched.
set -eu

root=/storage/Tools/my355
sdl_name='Zlyme SDL3 Validation.pak'
gl_name='Zlyme GL4ES Validation.pak'
marker='.zlyme-phase14-probe'

die() {
	echo "phase14-probe-paks: $*" >&2
	exit 1
}

owned() {
	dir=$1
	[ -d "$dir" ] && [ ! -L "$dir" ] &&
		[ -f "$dir/$marker" ] &&
		[ "$(cat "$dir/$marker")" = phase14-graphics-v1 ]
}

remove_one() {
	dir=$1
	if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
		return 0
	fi
	owned "$dir" || die "refusing non-test entry: $dir"
	rm -rf "$dir"
}

install_one() {
	dir=$1
	program=$2
	wrapper=${3:-}
	tmp=$dir.tmp.$$

	if [ -e "$dir" ] || [ -L "$dir" ]; then
		owned "$dir" || die "entry already exists and is not owned: $dir"
		return 0
	fi
	rm -rf "$tmp"
	mkdir -p "$tmp"
	printf '%s\n' phase14-graphics-v1 > "$tmp/$marker"
	{
		printf '%s\n' '#!/bin/sh' 'set -eu' 'export ZLYME_PROBE_SECONDS=120'
		if [ -n "$wrapper" ]; then
			printf 'exec %s %s\n' "$wrapper" "$program"
		else
			printf 'exec %s\n' "$program"
		fi
	} > "$tmp/launch.sh"
	chmod 0755 "$tmp/launch.sh"
	mv "$tmp" "$dir"
}

case "${1:-}" in
install)
	[ -x /usr/libexec/zlyme-tests/zlyme-sdl3-kms-probe ] ||
		die "SDL3 probe is not installed"
	[ -x /usr/libexec/zlyme-tests/zlyme-gl4es-probe ] ||
		die "GL4ES probe is not installed"
	[ -x /usr/bin/zlyme-gl4es-run ] ||
		die "GL4ES selector is not installed"
	mkdir -p "$root"
	install_one "$root/$sdl_name" \
		/usr/libexec/zlyme-tests/zlyme-sdl3-kms-probe
	install_one "$root/$gl_name" \
		/usr/libexec/zlyme-tests/zlyme-gl4es-probe \
		/usr/bin/zlyme-gl4es-run
	echo "phase14 probe Tools installed"
	;;
remove)
	remove_one "$root/$sdl_name"
	remove_one "$root/$gl_name"
	echo "phase14 probe Tools removed"
	;;
*)
	die "usage: $0 install|remove"
	;;
esac
