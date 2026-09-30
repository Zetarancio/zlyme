#!/bin/sh
# Host checks for Files.pak VTree seeding. Does not touch /storage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH="$ROOT/package/system/nextui/paks/Tools/Files.pak/launch.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
share=$work/share
run=$work/run
mkdir -p "$share/theme" "$share/fonts" "$share/res"
cat > "$share/config.ini" <<'EOF'
[General]
ShowHidden=false
FontFile=

[ActiveTheme]
ActiveTheme=Dark
EOF
printf 'theme\n' > "$share/theme/Zlyme.ini"
printf 'themeini\n' > "$share/theme.ini"

run_seed() {
	ZLYME_VTREE_TEST=1 ZLYME_VTREE_SHARE="$share" ZLYME_VTREE_RUN="$run" "$LAUNCH"
}

run_seed
grep -q '^ShowHidden=true$' "$run/config.ini"
grep -q '^ActiveTheme=Zlyme$' "$run/config.ini"
test -f "$run/.zlyme-vtree-v1"
test -f "$run/theme/Zlyme.ini"

sed -i 's|^FontFile=.*|FontFile=custom.ttf|' "$run/config.ini"
sed -i 's|^ShowHidden=.*|ShowHidden=false|' "$run/config.ini"
sed -i 's|^ActiveTheme=.*|ActiveTheme=User|' "$run/config.ini"
printf 'user-theme\n' > "$run/theme/Zlyme.ini"
run_seed
grep -q '^FontFile=custom.ttf$' "$run/config.ini"
grep -q '^ShowHidden=false$' "$run/config.ini"
grep -q '^ActiveTheme=User$' "$run/config.ini"
grep -q '^user-theme$' "$run/theme/Zlyme.ini"

# A pre-migration card (config, no marker) gets ShowHidden=true once.
rm -rf "$run"
mkdir -p "$run"
cp "$share/config.ini" "$run/config.ini"
sed -i 's|^FontFile=.*|FontFile=old.ttf|' "$run/config.ini"
sed -i 's|^ActiveTheme=.*|ActiveTheme=Dark|' "$run/config.ini"
run_seed
grep -q '^ShowHidden=true$' "$run/config.ini"
grep -q '^FontFile=old.ttf$' "$run/config.ini"
grep -q '^ActiveTheme=Dark$' "$run/config.ini"
test -f "$run/.zlyme-vtree-v1"

echo "vtree config ok"
