# Shared card, backup, and NAND helpers for the stock-side preloader images.
# Sourced by install-maskrom.sh and install-restore.sh.
#
# Card discovery, the mtd5 gate, the battery gate, and the three-try
# write/readback loop follow apommel's install.sh (MIT, apommel/baseos-my355
# e09d37bb). Rollback messages and the one-entry recovery path are Zlyme's.
# A verified write signals the stock updater and leaves that session running.
# These helpers do not reboot. apommel's own installer may; that file is not
# this one. This file does not accept an image path or a force switch.

sha_file() {
    sha256sum "$1" | cut -c1-64
}

log() {
    echo "$*"
    echo "$(date '+%H:%M:%S') $*" >> "$LOG"
}

progress() {
    echo "$1" > /tmp/fwupdate_progress
}

finish() {
    sync
    if [ -n "${FATMNT:-}" ]; then
        mountpoint -q "$FATMNT" 2>/dev/null && umount "$FATMNT"
    fi
    progress 100
    echo 1 > /tmp/fwupdate_done
    # Stock's updater is waiting on fwupdate_done. Leave that session running.
    exit "${1:-0}"
}

setup_card() {
    CARD="${CARD:-$(pwd)}"
    resolved=$(cd "$CARD" 2>/dev/null && pwd -P) && CARD="$resolved"
    FATMNT=/tmp/zlyme-fw-fat
    OUTDIR="$CARD"
    # CARDDEV finds the FAT volume. It is not a physical-slot identity.
    MOUNTS="${MOUNTS:-/proc/mounts}"
    CARDDEV=$(awk -v d="$CARD" '$2 == d { print $1; exit }' "$MOUNTS")
    case "$CARDDEV" in
        /dev/mmcblk*p*)
            for part in "${CARDDEV%p*}"p*; do
                blkid "$part" 2>/dev/null | grep -q 'TYPE="vfat"' || continue
                mkdir -p "$FATMNT"
                if mount -t vfat "$part" "$FATMNT" 2>/dev/null; then
                    OUTDIR="$FATMNT"
                fi
                break
            done
            ;;
    esac
    LOG="$OUTDIR/zlyme-fw.log"
}

# Commands the transform, the target write, and the rollback all need.
# A missing one refuses before the first erase.
require_tools() {
    for cmd in flash_erase nandwrite dd sha256sum xxd awk grep cmp \
        cp rm cat wc basename sync mktemp date tr cut sed sh; do
        command -v "$cmd" >/dev/null 2>&1 || {
            log "required command is missing: $cmd"
            finish 1
        }
    done
}

# mtd5 on the stock firmware apommel measured: name spl, 2 MiB, 128 KiB
# erase, 2048-byte pages. The SPI NAND spare area is 64 bytes. bad_blocks
# is that partition's MTD count. A missing attribute refuses; it is not skipped.
sys_is() {
    key=$1
    want=$2
    file="$MTD_SYSFS/$key"
    if [ ! -r "$file" ]; then
        log "mtd sysfs $key is missing"
        finish 1
    fi
    got=$(tr -d '[:space:]' < "$file")
    if [ "$got" != "$want" ]; then
        log "mtd5 $key is not $want"
        finish 1
    fi
}

check_ground() {
    PROC_MTD="${PROC_MTD:-/proc/mtd}"
    MTD="${MTD:-/dev/mtd5}"
    MTD_SYSFS="${MTD_SYSFS:-/sys/class/mtd/mtd5}"
    BATTERY_CAPACITY="${BATTERY_CAPACITY:-/sys/class/power_supply/battery/capacity}"
    POWER_ROOT="${POWER_ROOT:-/sys/class/power_supply}"
    require_tools
    grep -q '"spl"' "$PROC_MTD" || {
        log "no spl partition; wrong device"
        finish 1
    }
    spl_line=$(grep '"spl"' "$PROC_MTD" | cut -c1-5)
    [ "$spl_line" = "mtd5:" ] || {
        log "spl is not mtd5"
        finish 1
    }
    size_hex=$(awk '/"spl"/ { print $2; exit }' "$PROC_MTD")
    erase_hex=$(awk '/"spl"/ { print $3; exit }' "$PROC_MTD")
    [ "$size_hex" = "00200000" ] || {
        log "spl size is not 2 MiB"
        finish 1
    }
    [ "$erase_hex" = "00020000" ] || {
        log "spl erase size is not 128 KiB"
        finish 1
    }
    sys_is name spl
    sys_is size 2097152
    sys_is erasesize 131072
    sys_is writesize 2048
    sys_is oobsize 64
    bad=$(tr -d '[:space:]' < "$MTD_SYSFS/bad_blocks") || {
        log "mtd sysfs bad_blocks is missing"
        finish 1
    }
    [ "$bad" = "0" ] || {
        log "mtd5 has bad blocks"
        finish 1
    }
    CAP=$(cat "$BATTERY_CAPACITY" 2>/dev/null || echo 0)
    AC=0
    for s in "$POWER_ROOT"/*/online; do
        [ -e "$s" ] || continue
        [ "$(cat "$s" 2>/dev/null)" = "1" ] && AC=1
    done
    if [ "$CAP" -lt 25 ] && [ "$AC" != "1" ]; then
        log "battery $CAP% and no charger; refusing"
        finish 1
    fi
    log "battery $CAP%, on charger $AC"
}

read_live() {
    dd if="${MTD}ro" of=/tmp/zlyme-live.img bs=2048 2>/dev/null
    BEFORE=$(sha_file /tmp/zlyme-live.img)
    log "preloader reads as $BEFORE"
}

# Record every mtd5-original-<sha256>.img in DEST, one path per line.
# A badly named or hash-mismatched file refuses. This does not look at
# preloader-current-*.img.
collect_originals() {
    dest=$1
    : > "$dest"
    for f in "$OUTDIR"/mtd5-original-*.img; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        printf '%s\n' "$base" | grep -Eq '^mtd5-original-[0-9a-f]{64}\.img$' || {
            log "backup name is not mtd5-original-<sha256>.img: $base"
            finish 1
        }
        want=$(printf '%s\n' "$base" | sed 's/^mtd5-original-//;s/\.img$//')
        got=$(sha_file "$f")
        [ "$got" = "$want" ] || {
            log "backup hash does not match its name: $base"
            finish 1
        }
        [ "$(wc -c < "$f" | tr -d ' ')" -eq 2097152 ] || {
            log "backup is not 2 MiB: $base"
            finish 1
        }
        printf '%s\n' "$f" >> "$dest"
    done
}

save_verified_copy() {
    src=$1
    dest=$2
    expect=$3
    if [ -f "$dest" ]; then
        [ "$(sha_file "$dest")" = "$expect" ] || {
            log "existing $(basename "$dest") does not match the image"
            finish 1
        }
        log "kept existing $(basename "$dest")"
        return 0
    fi
    cp "$src" "$dest" && sync
    [ "$(sha_file "$dest")" = "$expect" ] || {
        log "copy to the card did not verify: $(basename "$dest")"
        finish 1
    }
    log "saved $(basename "$dest")"
}

# A failed or short read must not be compared with an older file. The NAND
# readback is a new 2 MiB image every time, for the target and the rollback.
readback_matches() {
    expect=$1
    tmp=$(mktemp) || return 1
    ok=0
    if dd if="${MTD}ro" of="$tmp" bs=2048 2>/dev/null; then
        size=$(wc -c < "$tmp" | tr -d ' ')
        if [ "$size" -eq 2097152 ]; then
            got=$(sha_file "$tmp")
            if [ "$got" = "$expect" ]; then
                ok=1
            fi
        fi
    fi
    rm -f "$tmp"
    [ "$ok" -eq 1 ]
}

write_and_rollback() {
    target=$1
    expect=$2
    rollback=$3
    roll_sha=$4
    n=0
    while [ "$n" -lt 3 ]; do
        n=$((n + 1))
        log "flash attempt $n"
        flash_erase "$MTD" 0 0 >> "$LOG" 2>&1 || true
        nandwrite -p "$MTD" "$target" >> "$LOG" 2>&1 || true
        progress $((40 + n * 15))
        if readback_matches "$expect"; then
            return 0
        fi
        log "readback mismatch"
    done
    log "could not write the preloader; restoring the previous image"
    n=0
    while [ "$n" -lt 3 ]; do
        n=$((n + 1))
        log "rollback attempt $n"
        flash_erase "$MTD" 0 0 >> "$LOG" 2>&1 || true
        nandwrite -p "$MTD" "$rollback" >> "$LOG" 2>&1 || true
        if readback_matches "$roll_sha"; then
            log "target write failed; the previous preloader was restored"
            return 1
        fi
    done
    log "CRITICAL: target write failed and rollback could not be verified"
    return 2
}
