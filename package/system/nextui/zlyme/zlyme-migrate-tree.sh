# Sourced. Move a legacy directory onto a new path once.
# Absent destination: rename the source.
# Both exist: move only missing entries. Identical files are dropped
# from the source. A different destination file is left in place and
# the source directory stays.
# zlyme_migrate_tree SRC DST

zlyme_migrate_dir() {
	_ms=$1
	_md=$2
	mkdir -p "$_md" || return 1
	find "$_ms" -mindepth 1 -maxdepth 1 2>/dev/null |
		while IFS= read -r _se; do
			[ -n "$_se" ] || continue
			_base=${_se##*/}
			_de=$_md/$_base
			if [ -d "$_se" ] && [ ! -L "$_se" ]; then
				if [ -e "$_de" ] && [ ! -d "$_de" ]; then
					echo "zlyme: migrate conflict $_de" >&2
					echo 1 >> "$_mf"
					continue
				fi
				zlyme_migrate_dir "$_se" "$_de"
			elif [ ! -e "$_de" ] && [ ! -L "$_de" ]; then
				mv "$_se" "$_de" || echo 1 >> "$_mf"
			elif cmp -s "$_se" "$_de" 2>/dev/null; then
				rm -f "$_se"
			else
				echo "zlyme: migrate conflict $_de" >&2
				echo 1 >> "$_mf"
			fi
		done
	rmdir "$_ms" 2>/dev/null || true
}

zlyme_migrate_tree() {
	_src=$1
	_dst=$2
	[ -n "$_src" ] && [ -n "$_dst" ] || return 1
	[ "$_src" != "$_dst" ] || return 0
	[ -d "$_src" ] || return 0
	if [ ! -e "$_dst" ]; then
		mkdir -p "$(dirname "$_dst")" || return 1
		mv "$_src" "$_dst"
		return $?
	fi
	if [ ! -d "$_dst" ]; then
		echo "zlyme: migrate conflict $_dst exists and is not a directory" >&2
		return 1
	fi
	_mf=$(mktemp)
	: > "$_mf"
	zlyme_migrate_dir "$_src" "$_dst"
	if [ -s "$_mf" ]; then
		rm -f "$_mf"
		return 1
	fi
	rm -f "$_mf"
	if [ -d "$_src" ]; then
		find "$_src" -depth -type d -exec rmdir {} + 2>/dev/null || true
	fi
	if [ -d "$_src" ]; then
		echo "zlyme: migrate left $_src" >&2
		return 1
	fi
	return 0
}
