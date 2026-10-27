# ADR 0012 — Diagnostic logging ownership and lifecycle

Status: Accepted

Date: 2026-10-27

## Context

System logs are one Settings switch, off by default. The current implementation is BusyBox init, `zlyme-logs`, and `pak-log.sh`. Phase 16 is still adding retention, service tails, and privacy limits. Those missing pieces do not change who owns a log.

The same rules have to hold if a later init system replaces BusyBox. This decision does not make that replacement.

## Decision

One user-visible switch controls new persistent diagnostics. It is Settings → System → Advanced → System logs. Off is the default.

A production service has one owner and one declared diagnostic destination. The owner is the init script or the `zlyme-*` command that starts it. A long-lived service does not hold an exFAT log descriptor for its whole life. Its live text stays on tmpfs. `zlyme-logs` copies a snapshot into `/storage/.logs` only while the switch is on.

A PAK, a libretro launch, a standalone, and a first-party tool use the shared launcher. `pak-log.sh` owns rotation and the on/off decision for that launch. The PAK does not rotate for itself. A custom PAK is covered only when it uses that interface and stays in the spawned session.

An application turns on a verbose or debug mode only when the switch is on, the mode is actually supported, and it does not change how the program plays or what it saves. There is no universal verbose flag. RetroArch's `-v` is that program's own switch. Another program is left at its default until its own option is known to be safe.

Logging must not decide whether a launch succeeds. A log that cannot be opened does not replace the program's exit status, its process id, or the process group MENU+START cleans up. An in-flight launch that already opened a PAK log keeps that descriptor until the process exits. A launch that starts after the switch is off does not open one.

Persistent diagnostics do not grow without a bound. The bound is part of `zlyme-logs` and `pak-log.sh`, not a second logger. The numeric caps are not in force yet.

Logs do not deliberately record a password, a token, or a full URL that carries either. Output from a program we do not control is not claimed to be clean.

Logs off does not start a new persistent diagnostic, except the two `rc.late` copies of boot timing and `nextui.txt`. Those stay so a hung panel can still leave evidence.

A new service or launcher brings a host test for logs on and logs off. A host test, a reading of source, and a Flip run are different evidence.

## Consequences

`docs/ARCHITECTURE.md` keeps the current paths. This file is the rule for a new init script, service, or launcher.

BusyBox init stays. ADR 0003 is unchanged.

Byte caps, service-log tails, and filtering of third-party output are still open Phase 16 work. This decision does not mark them done.

## Alternatives

A logging daemon, or journald, was not adopted. The switch, the owner, and the destination do not require one.
