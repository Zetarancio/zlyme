#!/bin/sh
# Host checks for Phase 14 PortMaster validation campaign state.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATE=$ROOT/scripts/device/phase14-portmaster-validate.sh
INVENTORY=$ROOT/scripts/device/phase14-portmaster-inventory.sh
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
PROBE=$ROOT/scripts/device/phase14-probe-paks.sh

fail() {
	echo "phase14 validate: $*" >&2
	exit 1
}

[ -f "$VALIDATE" ] || fail "missing validate script"
[ -f "$INVENTORY" ] || fail "missing inventory script"
grep -q 'launch_is_ports' "$LAUNCH" || fail "pak-launch missing launch_is_ports"
grep -q 'Validation.pak/launch.sh' "$LAUNCH" ||
	fail "pak-launch does not classify the validation Tools PAK as ports"
grep -q 'exec "\$ports" "\$script"' "$VALIDATE" ||
	fail "validate does not exec canonical PORTS.pak"
if grep -q 'run_ports_like' "$VALIDATE"; then
	fail "validate still embeds a duplicated ports setup"
fi
grep -q 'kill -TERM "\$waiter_pid"' "$VALIDATE" ||
	fail "validate timeout does not signal the pak waiter"
grep -q 'NEXTUI_RESTORED' "$VALIDATE" ||
	fail "validate has no post-exit NextUI observer"
grep -q 'install_pm_validation' "$PROBE" ||
	fail "probe-paks does not install the ports-exec validation entry"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_PHASE14_VALIDATE_DIR=$work/state
export ZLYME_PHASE14_INVENTORY=$INVENTORY
mkdir -p "$work/lib/Roms/Ports (PORTS)"
# Eligible + blocked rows
printf '%s\n' '#!/bin/sh' 'exit 0' > "$work/lib/Roms/Ports (PORTS)/Good Port.sh"
chmod 0755 "$work/lib/Roms/Ports (PORTS)/Good Port.sh"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$work/lib/Roms/Ports (PORTS)/Skautfold - Shrouded in Sanity.sh"
chmod 0755 "$work/lib/Roms/Ports (PORTS)/Skautfold - Shrouded in Sanity.sh"

# Fake identity helpers via env overrides inside a wrapper inventory call
# Inventory reads /run/zlyme/libraries; provide a fake tree via bind? Instead
# call inventory with out_dir and plant libraries by editing PATH-less hooks.
# The inventory falls back to /mnt/sd2 then /storage. Plant under work via
# a small stub inventory for campaign start tests.

stub_inv=$work/stub-inventory
cat > "$stub_inv" << STUB
#!/bin/sh
set -eu
out=\${1:-}
mkdir -p "\$out"
printf 'ELIGIBLE\tgood\t$work/lib/Roms/Ports (PORTS)/Good Port.sh\n' > "\$out/queue.txt"
printf 'EXTERNAL_DATA_REQUIRED\tskaut\t$work/lib/Roms/Ports (PORTS)/Skautfold - Shrouded in Sanity.sh\n' >> "\$out/queue.txt"
printf 'PHASE14_INVENTORY stub\n' > "\$out/inventory-stub.txt"
STUB
chmod 0755 "$stub_inv"
export ZLYME_PHASE14_INVENTORY=$stub_inv

mkdir -p "$work/state/campaigns/testcamp/runs"
printf 'gpu=libmali\nboot_id=bootA\nsquashfs_sha256=sqA\n' > "$work/state/campaigns/testcamp/meta.txt"
printf '0\n' > "$work/state/campaigns/testcamp/cursor"
date +%s > "$work/state/campaigns/testcamp/suite-started"
printf 'ELIGIBLE\tgood\t%s\n' "$work/lib/Roms/Ports (PORTS)/Good Port.sh" > "$work/state/campaigns/testcamp/queue.txt"
printf 'EXTERNAL_DATA_REQUIRED\tskaut\t%s\n' "$work/lib/Roms/Ports (PORTS)/Skautfold - Shrouded in Sanity.sh" >> "$work/state/campaigns/testcamp/queue.txt"
printf 'testcamp\n' > "$work/state/active-campaign"
export ZLYME_PHASE14_TEST_GPU=libmali
export ZLYME_PHASE14_TEST_BOOT_ID=bootA
export ZLYME_PHASE14_TEST_SQUASHFS=sqA

# reset clears active campaign but keeps reports
ZLYME_PHASE14_VALIDATE_DIR=$work/state sh "$VALIDATE" reset
[ ! -e "$work/state/active-campaign" ] || fail "reset left active-campaign"
[ -d "$work/state/campaigns/testcamp" ] || fail "reset deleted campaign reports"

# restore active for lock test
printf 'testcamp\n' > "$work/state/active-campaign"
mkdir "$work/state/campaigns/testcamp/lock"
printf '1\n' > "$work/state/campaigns/testcamp/lock/pid"
if ZLYME_PHASE14_VALIDATE_DIR=$work/state sh "$VALIDATE" run >/dev/null 2>&1; then
	fail "run did not refuse a held lock"
fi

# GPU mismatch blocks after lock released
rm -rf "$work/state/campaigns/testcamp/lock"
export ZLYME_PHASE14_TEST_GPU=panfrost
if ZLYME_PHASE14_VALIDATE_DIR=$work/state sh "$VALIDATE" run >/dev/null 2>&1; then
	fail "run did not refuse a GPU mismatch"
fi
export ZLYME_PHASE14_TEST_GPU=libmali

# Cursor rewind for retry
printf '2\n' > "$work/state/campaigns/testcamp/cursor"
printf 'stuck\n' > "$work/state/campaigns/testcamp/blocked"
ZLYME_PHASE14_VALIDATE_DIR=$work/state sh "$VALIDATE" retry
[ "$(cat "$work/state/campaigns/testcamp/cursor")" = 1 ] || fail "retry did not rewind cursor"
[ ! -e "$work/state/campaigns/testcamp/blocked" ] || fail "retry left blocked"

# systemctl arity is covered in test_portmaster_mounts.sh
# Shell syntax
sh -n "$VALIDATE" || fail "validate syntax"
sh -n "$INVENTORY" || fail "inventory syntax"
sh -n "$PROBE" || fail "probe-paks syntax"

echo "phase14 validate ok"
