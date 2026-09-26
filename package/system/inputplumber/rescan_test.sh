#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
patch=$dir/0001-rescan-devices.patch
grep -q 'RescanDevices' "$patch"
grep -q 'discover_all_devices' "$patch"
grep -q 'fn rescan_devices' "$patch"
grep -q 'DevicesCommand::Rescan' "$patch"
echo RESCAN_OK
