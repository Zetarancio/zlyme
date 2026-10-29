# ADR 0012 — Diagnostic logging ownership and lifecycle

Status: Accepted

Date: 2026-10-27

## Context

System logs are one Settings switch, off by default. The current implementation is BusyBox init, `zlyme-logs`, and `pak-log.sh`. Phase 16 is still adding retention, service tails, and privacy limits. Those missing pieces do not change who owns a log.

The same rules have to hold if a later init system replaces BusyBox. This decision does not make that replacement.

## Decision

One user-visible switch is the request for the next boot. It is Settings → System → Advanced → System logs. Off is the default. S15 writes `/run/zlyme/logs-effective` once after storage is mounted. That file is the effective state for the boot. A Settings change does not start or stop capture, and there is no supported live toggle. The description in Settings says a restart is required. Enabling the switch creates `/boot/zlyme-logs` through `zlyme-boot-write` so the next boot's initramfs can keep the early kernel log. Disabling it removes that file the same way. The initramfs writes that log only when the marker exists and the saved System logs value on the verified primary storage volume is on (`on`, `1`, or `yes`). A missing, empty, invalid, or unreadable value is off. A marker by itself does not authorize the copy and does not remount the boot volume for diagnostics. An update still remounts that volume on its own. If the boot write fails, the saved request stays, the command returns an error, and Settings says the early boot log was not updated. The next userspace latch still follows the saved request. A failed create can omit the early copy. A failed remove can leave the marker, and the next background seed tries once, re-reading the saved value inside the boot-write lock. Enabling logs takes that same lock and reads the saved value again before it creates the marker. A marker that already matches that value is not rewritten. A saved value of on is not removed. Userspace logging still follows the latch. Ordinary boot continues.

A production service has one owner and one declared diagnostic destination. The owner is the init script or the `zlyme-*` command that starts it. A long-lived service does not hold an exFAT log descriptor for its whole life. Its live text stays on tmpfs. `zlyme-logs` copies a snapshot into `/storage/.logs` only while the effective state is on. Producers read the effective state, not the Settings file.

A PAK, a libretro launch, a standalone, and a first-party tool use the shared launcher. `pak-log.sh` owns rotation and the on/off decision for that launch. The PAK does not rotate for itself. A custom PAK is covered only when it uses that interface and stays in the spawned session.

An application turns on a verbose or debug mode only when the effective state is on, the mode is actually supported, and it does not change how the program plays or what it saves. There is no universal verbose flag. RetroArch's `-v` is that program's own switch. Another program is left at its default until its own option is known to be safe.

Logging must not decide whether a launch succeeds. A log that cannot be opened does not replace the program's exit status, its process id, or the process group MENU+START cleans up. An in-flight launch that already opened a PAK log keeps that descriptor until the process exits. A launch that starts while the effective state is off does not open one.

Persistent diagnostics do not grow without a bound. The bound is part of `zlyme-logs` and `pak-log.sh`, not a second logger. Completed files and snapshot copies are trimmed. An open writer can still grow past the number.

Logs do not deliberately record a password, a token, or a full URL that carries either. Output from a program we do not control is not claimed to be clean.

Effective logs off does not start a new persistent diagnostic, except the two `rc.late` copies of boot timing and `nextui.txt`. Those stay so a hung panel can still leave evidence. First-party event lines carry the UTC wall clock and the monotonic seconds since boot. The wall clock can be wrong until NTP. The monotonic value does not jump when the clock is corrected. A program's own message format is left as it is. Snapshot time is not labeled as the time of each line inside the snapshot.

A new service or launcher brings a host test for logs on and logs off. A host test, a reading of source, and a Flip run are different evidence.

## Consequences

`docs/ARCHITECTURE.md` keeps the current paths. This file is the rule for a new init script, service, or launcher.

BusyBox init stays. ADR 0003 is unchanged.

Service tails are copied from the tmpfs files named in `docs/ARCHITECTURE.md`. A hard total ceiling is not in force: current PAK logs stay while a launch may hold them, and one file per shipped PAK at the trim size is already over 32 MiB. Third-party output is still not filtered. This decision does not mark Phase 16 done.

## Alternatives

A logging daemon, or journald, was not adopted. The switch, the owner, and the destination do not require one.
