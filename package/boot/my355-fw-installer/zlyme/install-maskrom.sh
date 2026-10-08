#!/bin/sh
# Stock-side recovery-preloader helper.
# Reads this unit's preloader, keeps its DDR and SPL executable, applies
# apommel's /pinctrl repair when the tree is still empty, then sets the SPL
# boot order to /dwmmc@fe2b0000 only. No image argument. No force switch.
# Does not contain a preloader binary.
set -e

HERE=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$HERE/common.sh"

[ "$#" -eq 0 ] || {
    echo "refused: this helper does not take an image path" >&2
    exit 1
}

setup_card
log "--- Zlyme recovery-preloader helper ---"
progress 5
check_ground
progress 10
read_live
sh "$HERE/check-image.sh" /tmp/zlyme-live.img >> "$LOG" 2>&1 || {
    log "installed preloader failed the structure check; nothing was written"
    finish 1
}

progress 20
if sh "$HERE/patch-preloader.sh" /tmp/zlyme-live.img /tmp/zlyme-patched.img > /tmp/zlyme-patch.log 2>&1; then
    from_stock=1
    cat /tmp/zlyme-patch.log >> "$LOG"
else
    cat /tmp/zlyme-patch.log >> "$LOG"
    if grep -q "already has properties" /tmp/zlyme-patch.log; then
        from_stock=0
    else
        log "preloader repair refused; nothing was written"
        finish 1
    fi
fi

if [ "$from_stock" -eq 1 ]; then
    if sh "$HERE/apply-boot-order.sh" /tmp/zlyme-patched.img /tmp/zlyme-new.img >> "$LOG" 2>&1; then
        :
    else
        log "recovery boot order refused; nothing was written"
        finish 1
    fi
else
    set +e
    sh "$HERE/apply-boot-order.sh" /tmp/zlyme-live.img /tmp/zlyme-new.img >> "$LOG" 2>&1
    boot_rc=$?
    set -e
    if [ "$boot_rc" -eq 2 ]; then
        log "already a right-slot recovery preloader; nothing was written"
        finish 0
    fi
    if [ "$boot_rc" -ne 0 ]; then
        log "recovery boot order refused; nothing was written"
        finish 1
    fi
    collect_originals /tmp/zlyme-originals.txt
    count=$(grep -c . /tmp/zlyme-originals.txt || true)
    [ "$count" -eq 1 ] || {
        log "need exactly one mtd5-original backup before changing an already repaired preloader; nothing was written"
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
    sh "$HERE/patch-preloader.sh" "$orig" /tmp/zlyme-from-orig.img >> "$LOG" 2>&1 || {
        log "saved original is not a supported stock preloader; nothing was written"
        finish 1
    }
    cmp -s /tmp/zlyme-from-orig.img /tmp/zlyme-live.img || {
        log "saved original does not produce the installed preloader; nothing was written"
        finish 1
    }
fi

sh "$HERE/check-image.sh" /tmp/zlyme-new.img >> "$LOG" 2>&1 || {
    log "recovery image failed the structure check; nothing was written"
    finish 1
}
sh "$HERE/check-image.sh" --ddr-cmp /tmp/zlyme-live.img /tmp/zlyme-new.img >> "$LOG" 2>&1 || {
    log "recovery image changed the DDR payload; nothing was written"
    finish 1
}
AFTER=$(sha_file /tmp/zlyme-new.img)
log "recovery image is $AFTER"

progress 30
if [ "$from_stock" -eq 1 ]; then
    collect_originals /tmp/zlyme-originals.txt
    count=$(grep -c . /tmp/zlyme-originals.txt || true)
    if [ "$count" -gt 1 ]; then
        log "more than one original backup; nothing was written"
        finish 1
    fi
    if [ "$count" -eq 1 ]; then
        only=$(cat /tmp/zlyme-originals.txt)
        case "$only" in
            "$OUTDIR/mtd5-original-$BEFORE.img") ;;
            *)
                log "an original backup for a different preloader is already on the card; nothing was written"
                finish 1
                ;;
        esac
    fi
    save_verified_copy /tmp/zlyme-live.img "$OUTDIR/mtd5-original-$BEFORE.img" "$BEFORE"
fi
save_verified_copy /tmp/zlyme-live.img "$OUTDIR/preloader-current-$BEFORE.img" "$BEFORE"

if [ "${BASEOS_DRY:-0}" = "1" ]; then
    log "dry run - would erase $MTD and write the recovery preloader"
    finish 0
fi

progress 40
if write_and_rollback /tmp/zlyme-new.img "$AFTER" /tmp/zlyme-live.img "$BEFORE"; then
    log "readback verified"
    if [ -f "$OUTDIR/miyoo355_fw.img" ]; then
        rm -f "$OUTDIR/miyoo355_fw.img"
        sync
        log "removed miyoo355_fw.img from the card"
    fi
    log "recovery preloader installed; power the device off before changing cards"
    log "use a bootable card in the right-hand slot for normal boot"
    progress 95
    finish 0
fi
finish 1
