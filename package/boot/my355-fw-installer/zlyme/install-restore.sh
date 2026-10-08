#!/bin/sh
# Stock-side undo of the normal multiboot repair.
# Stock has to already be running. The only eligible file is one
# mtd5-original-<sha256>.img on the card FAT. No image argument. No force
# switch. The bundled stock blob is not consulted.
#
# This is not the way out of an armed recovery preloader: that preloader
# does not boot internal stock. The recovery-derivative check below stays
# for a unit where stock is already running by some other arrangement.
set -e

HERE=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$HERE/common.sh"

[ "$#" -eq 0 ] || {
    echo "refused: this helper does not take an image path" >&2
    exit 1
}

setup_card
log "--- Zlyme restore-original helper ---"
progress 5
check_ground
progress 10
read_live
sh "$HERE/check-image.sh" /tmp/zlyme-live.img >> "$LOG" 2>&1 || {
    log "installed preloader failed the structure check; nothing was written"
    finish 1
}

progress 20
collect_originals /tmp/zlyme-originals.txt
count=$(grep -c . /tmp/zlyme-originals.txt || true)
[ "$count" -ge 1 ] || {
    log "no mtd5-original backup on the card; nothing was written"
    finish 1
}
[ "$count" -eq 1 ] || {
    log "more than one original backup; nothing was written"
    finish 1
}
orig=$(cat /tmp/zlyme-originals.txt)
sh "$HERE/check-image.sh" "$orig" >> "$LOG" 2>&1 || {
    log "saved original failed the structure check; nothing was written"
    finish 1
}
sh "$HERE/check-image.sh" --ddr-cmp "$orig" /tmp/zlyme-live.img >> "$LOG" 2>&1 || {
    log "saved original DDR does not match the installed preloader; nothing was written"
    finish 1
}
if cmp -s "$orig" /tmp/zlyme-live.img; then
    log "installed preloader is already the saved original; nothing was written"
    finish 0
fi
rm -f /tmp/zlyme-from-orig.img /tmp/zlyme-from-rec.img
if sh "$HERE/patch-preloader.sh" "$orig" /tmp/zlyme-from-orig.img > /tmp/zlyme-patch.log 2>&1 \
    && cmp -s /tmp/zlyme-from-orig.img /tmp/zlyme-live.img; then
    cat /tmp/zlyme-patch.log >> "$LOG"
    log "installed preloader is the repaired form of the saved original"
elif [ -f /tmp/zlyme-from-orig.img ] \
    && sh "$HERE/apply-boot-order.sh" /tmp/zlyme-from-orig.img /tmp/zlyme-from-rec.img >> "$LOG" 2>&1 \
    && cmp -s /tmp/zlyme-from-rec.img /tmp/zlyme-live.img; then
    # Defensive only. The ordinary user path cannot reach stock in this state.
    log "installed preloader is the recovery form of the saved original"
else
    cat /tmp/zlyme-patch.log >> "$LOG" 2>/dev/null || true
    log "saved original does not produce the installed preloader; nothing was written"
    finish 1
fi

AFTER=$(sha_file "$orig")
log "restore target is $AFTER"
progress 30
save_verified_copy /tmp/zlyme-live.img "$OUTDIR/preloader-current-$BEFORE.img" "$BEFORE"

if [ "${BASEOS_DRY:-0}" = "1" ]; then
    log "dry run - would erase $MTD and write the saved original"
    finish 0
fi

progress 40
if write_and_rollback "$orig" "$AFTER" /tmp/zlyme-live.img "$BEFORE"; then
    log "readback verified; this unit's saved original preloader is installed"
    if [ -f "$OUTDIR/miyoo355_fw.img" ]; then
        rm -f "$OUTDIR/miyoo355_fw.img"
        sync
        log "removed miyoo355_fw.img from the card"
    fi
    log "original preloader restored; power the device off before changing cards"
    progress 95
    finish 0
fi
finish 1
