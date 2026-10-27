# Phase 16A logging inventory

Date: 2026-10-27. Read at `92d85f9b818dbb11d1a94941a2e5757fc680ad28` on `zlyme44.4-phase-16`. This is a source reading. It is not a Miyoo Flip result.

16B3, later on this date, changed the runtime. The section at the end is that implementation. Where this 16A reading and that section disagree, the 16B3 section is the source.

Scope: the product image's NextUI launchers, `zlyme-logs`, `zlyme-ctl`, `nextui-session`, `pak-launch.sh`, `zlyme-pak-spawn`, `S28minui`, `rc.late`, the initramfs log flag, and the service scripts that write diagnostic text. The minimal defconfig does not select NextUI, so it has none of these PAKs.

`package/system/nextui/nextui.mk` copies `paks/Emus` and `paks/Tools` onto the product image and then deletes Update, Autocal, Joystick Calibration, and `RUFFLE.pak`. Those four names are not in this tree. The shipped set is the 63 `launch.sh` files that are.

## Launch contract

`S28minui` starts `nextui-session` in the background with stdout and stderr on `/tmp/nextui-session.log`. That descriptor stays there. `nextui-session` writes its own lines to `/tmp/nextui-session.txt`. While System logs are on, `zlyme-logs start` copies those files to `system-0/session.txt` and `system-0/next.txt`. It does not copy them while the switch is off.

A game or tool is `launch.sh`, started by `zlyme-pak-spawn` through `pak-launch.sh`. The spawn helper returns the leader's exit status. A leader exit of 125 is reported as 126 so it is not mistaken for the helper's own cleanup failure. The helper returns 125 when it cannot prove the session is gone. `nextui-session` treats 0, 2, 3, 137, and 143 as success and stops the frontend on 125. That path is source. It was not replayed on a Flip for this note.

`pak-log.sh` runs only when the launcher sources it. Logs on: it rotates three files, writes a header, and redirects that shell's stdout and stderr onto the PAK file whether or not `EMU_EXE` is set. `ra-run.sh` then execs `retroarch -v` and does not pass `--log-file`. Logs off: the helper creates nothing. The section below records why `--log-file` was dropped. Sourcing the helper is still not, by itself, a capture of a program that leaves the session.

With logs on, the spawn is not redirected, so a launcher that does not redirect inherits `nextui-session`'s stdout. With logs off, the spawn is appended to `SESSION_LOG`, which is the tmpfs file.

## Shipped launchers

| Class | Count | Members |
| --- | --- | --- |
| Libretro, `EMU_EXE` set before `pak-log.sh` | 39 | 32X, 3DO, A26, A5200, A78, A800, COLECO, DOS, EASYRPG, FBNEO, FC, GB, GBA, GBC, GG, INTV, LYNX, MAME, MD, MKXPZ, MS, MSX, N64, NEOCD, NGP, O2, P8, PCE, PKM, PS, SATURN, SFC, SG1000, SGX, ST, TIC, VB, VEC, WS |
| Standalone, no `EMU_EXE` | 15 | AMIGA, DAPHNE, DC, DOOM, FLASH, GC, NDS, OPENBOR, PICO, PORTS, PS2, PSP, SCUMMVM, WII, WINE |
| Tool, no `EMU_EXE` | 9 | Files, Moonlight, Music Player, Overlays, PortMaster, RetroArch, Settings, USB Transfer, ZcrapeGoat |

Paths are `package/system/nextui/paks/Emus/<name>.pak/launch.sh` and `paks/Tools/<name>.pak/launch.sh`. Every one of the 63 sources `pak-log.sh`. `scripts/tests/test_pak_logging.sh` checks that, and it also checks that a core launch does not swallow stdout. That test records the current gap. It does not prove RetroArch output arrived in the PAK file.

### Libretro, including Tools → RetroArch with no ROM

Shared path: `ra-run.sh`, then `retroarch`. Logs on: the header and the process stdout and stderr, including RetroArch's verbose lines, are the PAK file. `ra-run.sh` passes `-v` and does not pass `--log-file`. Logs off: no PAK file. `ZLYME_RA_DEBUG` still passes `--log-file /tmp/ra-debug.log` and is not the System logs switch. While that capture is on, the session append sets `log_to_file = "false"` so a saved true does not move `RARCH_LOG` to RetroArch's own file. The user file is not rewritten. `ZLYME_RA_DEBUG` does not add that line.

Tools → RetroArch (`RetroArch.pak`) execs `ra-run` with no ROM. Logs on, that is the same redirect and `-v`, with no `--log-file`. Logs off: no PAK file.

P8 sets `EMU_EXE=fake08` before `pak-log.sh`. Logs on, both the fake08 `ra-run` path and `ZLYME_EMU_CORE=native` (`pico8`) inherit the redirect. The core choice is unchanged.

### Standalones

No `EMU_EXE`. Logs on: stdout and stderr of the launcher shell, and of the program it execs, go to `paks/<tag>.log`. Logs off: no PAK file; the spawn appends to the tmpfs session log. The exit status is the exec'd program's status, subject to the spawn rules above.

| PAK | Program | Native log |
| --- | --- | --- |
| PSP | `PPSSPPSDL` | No log path in the launcher or the shipped ini. stderr follows the shell. |
| DC | `flycast` | No log path in the launcher. stderr follows the shell. |
| GC, WII | `start_dolphin` → `dolphin-emu-nogui` | No log path in `start_dolphin.sh`. stderr follows the shell. |
| NDS | `start_drastic` | Not opened by the launcher. stderr follows the shell. |
| PS2 | `aethersx2` | Not opened by the launcher. stderr follows the shell. |
| AMIGA | `amiberry` | stderr follows the shell. |
| SCUMMVM | `scummvm` | stderr follows the shell. |
| DOOM | `gzdoom` | stderr follows the shell. |
| DAPHNE | `hypseus` | stderr follows the shell. |
| WINE | `zlyme-weston-run wine` | Weston writes `$XDG_RUNTIME_DIR/weston.log`, not the PAK log. |
| FLASH | Ruffle `entrypoint.sh` | 16A found `RUFFLE_AUX_LOG_DIR` under `/storage/.config/ruffle/logs` with logs off. 16B3 keeps saves there and puts the auxiliary log on `/tmp/zlyme-ruffle/logs` unless `ZLYME_PAK_LOG` is set. stderr follows the shell. |
| OPENBOR | `OpenBOR` | `OPENBOR_LOGS_DIR` is `paks/OPENBOR` when logs are on and `/tmp/zlyme-openbor/Logs` when off. That directory is not the three-file rotation. |
| PICO | `pico8` (`start_pico8.sh`) | The wrapper execs `pico8_64`. A cart whose name matches `Splore.p8` uses `-splore`. stdout follows the shell because this launcher does not set `EMU_EXE`. The wrapper does not detach. |
| PORTS | the selected port script or binary | stdout follows the shell only while the port stays in that process. `exec` replaces the shell, so the launcher's EXIT trap does not unmount. A port that leaves the session escapes both the log fd and the waiter. That is outside the guarantee. |

### Tools

Same redirect rule as standalones, except where a tool opens another file.

| Tool | Program | Notes |
| --- | --- | --- |
| PortMaster | `/usr/bin/portmaster` → `portmaster-launch` | GUI stdout and stderr go to `LOGS_PATH/portmaster.txt` when `ZLYME_PAK_LOG` is set, else `/tmp/portmaster.log`. The file is truncated each GUI start. A port installed from the GUI is not this process. Playing it later is `PORTS.pak`. |
| Settings | `settings.elf` | stderr follows the shell. |
| Files | `vtree` | stderr follows the shell. |
| Moonlight | `./moonlight-pak` | stderr follows the shell. `/tmp/stay_awake` is a flag, not a log. |
| Music Player | `musicplayer.elf` | stderr follows the shell. |
| Overlays | the pak's own shell, no `exec` | stdout follows the shell. The script echoes a launch line. |
| USB Transfer | `zlyme-usb-transfer` and `minui-presenter` in a loop | No `exec` of the transfer daemon as the leader. Presenter and helper stdout follow the shell. The waiter sees this shell's exit. |
| ZcrapeGoat | `zcrapegoat` | stderr follows the shell. The ScreenScraper URL is built with the developer password and the user password. This reading did not find a `printf` of that URL. A library that prints the request would land in the PAK log. `cheats.c` does print git arguments to stderr. |

### Custom PAKs

A PAK that sources `pak-log.sh` and stays in the spawned session gets the same rule as its `EMU_EXE` choice. A PAK that does not source it, or that detaches from the session, is not covered. This phase does not promise those processes.

## System producers

| Producer | Path when logs are off | Enters `.logs` today |
| --- | --- | --- |
| `zlyme-logs` snapshots | none until logs are on | `system-0/dmesg.txt`, `dmesg-boot.txt`, `boot-timing.txt`, `nextui.txt` |
| `S28minui` session process | `/tmp/nextui-session.log` always | copied to `system-0/session.txt` only while logs are on |
| `nextui-session` `SESSION_LOG` | `/tmp/nextui-session.txt` always | copied to `system-0/next.txt` only while logs are on |
| `nextui.elf` | `/tmp/nextui.txt` always | copied to `system-0/nextui.txt` when logs are on, and also to `/storage/.config/nextui/my355/logs/nextui.txt` by `rc.late` regardless |
| Boot timing | `/tmp/boot-timing` | copied to `system-0/boot-timing.txt` when logs are on, and to `/storage/.config/zlyme/boot-timing` by `rc.late` regardless |
| Initramfs | no dmesg file unless `/boot/zlyme-logs` exists | `/boot/zlyme-dmesg.txt` and `/storage/.logs/dmesg-init.txt` |
| InputPlumber and `zlyme-input` late start | `/tmp/zlyme-input-late.log` | no |
| PipeWire late start | `/tmp/zlyme-pipewire-late.log` | no |
| Bluetooth late start | `/tmp/zlyme-bt-late.log` | no |
| `zlyme-storage` | `/tmp/zlyme-storage.log` | no |
| `zlyme-led` | `/tmp/zlyme-led.log` | no |
| `zlyme-wifi` async worker | `/tmp/zlyme-net-async.log` | no |
| `rc.late` syslogd and klogd | no Zlyme config found that copies them | no |
| HDMI audio trace | not created unless `/storage/.config/zlyme/hdmi-audio-trace` exists | `/storage/.logs/hdmi-audio-trace.log`, independent of System logs |
| PAK trace | `/tmp/zlyme-pak-trace.txt` when the trace flag is set | no |
| RetroArch manual debug | `/tmp/ra-debug.log` when `ZLYME_RA_DEBUG` is set | no |

Not logs, and not migration candidates: `/tmp/zlyme-minui-ra.cfg` and the other RetroArch append files, PPSSPP and Flycast bind markers, Bluetooth info files, leader files, locks, `/tmp/stay_awake`, splash flags, and `/tmp/samba-lib`.

`zlyme-ctl apply-logs` calls `zlyme-logs apply`. On creates a generation only when `/run/zlyme-logs-generation` is absent, then copies the snapshots. Off removes `/boot/zlyme-logs` and keeps the marker, so on again in the same boot does not rotate. Reboot clears `/run`, so the next boot with logs on rotates. Reboot with logs off does not call `start`, so it does not rotate. The initramfs writes dmesg only when the boot flag is still present, which is the previous boot's logs-on state, not a logs-off boot.

`zlyme-logs` copies once per `start`. It does not follow a service that keeps writing after that copy. A PAK file is the live file for that launch, so a long RetroArch `-v` session grows without a byte cap. OpenBOR's directory is outside the three-file rotation. Nothing in `zlyme-logs` or `pak-log.sh` limits bytes. The kernel ring is `CONFIG_LOG_BUF_SHIFT=18`, 256 KiB, so one `dmesg` snapshot is on that order. The PAK and service files have no measured ceiling.

`zlyme-halt` is exec'd from `nextui-session` on poweroff or reboot. It moves stdout to the console and closes inherited descriptors that point at `/storage`, because the session fd is the log file when logs were on at start. A PAK that has already exited has closed its log fd. A service that had been given a direct `.logs` fd for the whole boot would still be outside that one process. That is why long-lived services stay on tmpfs until a copy.

## Toggle, from the source

Off to on while NextUI is running: the next launcher re-reads `zlyme-ctl want logs` and can open a PAK file. `zlyme-logs apply` takes one generation if this boot has not had one, and copies the tmpfs session files. The session descriptor stays on `/tmp`.

On to off while NextUI is running: new PAK files stop, and `zlyme-logs` does not copy the session files. A launch that already opened its PAK log keeps that descriptor until the process exits. The session descriptor was never on the card.

On, off, on in one boot: one generation, because the `/run` marker survives `stop`.

These transitions were not toggled on a Flip.

## Privacy

Do not copy a file into `.logs` until its contents are known.

- `zlyme-wifi` takes a PSK and sends it to `wpa_cli`. The async log line read here is the word `reconcile`, not the PSK. The log is still not a candidate until the whole writer is checked.
- ZcrapeGoat builds a ScreenScraper URL that includes passwords. stderr is the PAK log when System logs are on. The URL itself was not found in a log statement. Git arguments are printed.
- HDMI trace lines are ELD and sink choice, behind their own flag.
- PAK trace is process identity, behind its own flag.
- PortMaster's GUI log can contain a Python traceback from pugwash. It was not shown to contain a token.

## Logs-off card writes

`rc.late` copies boot timing and `nextui.txt` onto `/storage/.config` six times, 5 s apart, with logs off. Both destinations are one file, replaced, not a growing set. `docs/ARCHITECTURE.md` records them so a hung panel still leaves evidence after the card is pulled. This pass keeps them. Removing them is not safer on the evidence in tree: the replacement would be the same two files, or nothing. They stay a named exception. They are not System logs.

The HDMI trace flag stays separate from the System logs switch. 16B3 folded Ruffle's auxiliary log into that switch. The 16A sentence that left `/storage/.config/ruffle/logs` in place is the reading, not the implementation.

## Two designs

A. Leave runtime text in tmpfs and copy bounded snapshots into `.logs`. This is what `zlyme-logs` already does for dmesg, boot timing, and `nextui.txt`. A copy does not hold an exFAT descriptor for the whole boot, which matches `zlyme-halt`. A copy also misses whatever is written after the snapshot, and it writes the card again for text that already exists in RAM. The six `rc.late` copies are that cost on a small file.

B. Append the stream straight to a bounded file under `.logs` while logs are on. 16B1 does that with the shell redirect, not with RetroArch `--log-file`. The failure at the end of the run is in the file. The descriptor stays on the card until the process exits. That is acceptable for a launch `zlyme-pak-spawn` waits for, and it is the problem `zlyme-halt` already handles for the session. It is a poor fit for InputPlumber, PipeWire, Bluetooth, storage, LED, and Wi-Fi, which outlive one launch and must not pin `/storage` for the whole boot.

Selected design: B for waited launches, A for long-lived services. No new daemon and no systemd. `pak-log.sh` remains the launch switch. `zlyme-logs` remains the boot generation and the service copy. 16B makes the launch capture include the streams that currently miss the PAK file, caps each file, and copies a bounded tail of the service tmpfs logs into the current generation at the existing snapshot points and once more before halt. It does not open those service logs directly on exFAT.

Rejected as the only method: snapshot-only for PAKs, because the interesting failure is the end of the run and the snapshot has already happened. Rejected as the only method: direct files for the late services, because those descriptors would outlive the halt fix that closes only the session's own fds.

## Retention proposal

The kernel ring is 256 KiB. Five generations and three PAK files are the existing counts and they stay.

- One system-generation directory: 2 MiB. That holds a 256 KiB dmesg, the boot and frontend text, `session.txt`, `next.txt`, and a bounded tail of each service log.
- One PAK generation file: 1 MiB, including OpenBOR's directory counted against the OPENBOR tag. 1 MiB is four kernel rings. It is a cap for an uncapped `-v` session, not a Flip measurement.
- `/storage/.logs` total: 32 MiB. Five directories at 2 MiB are 10 MiB. The rest is PAK history.

Past the cap, the oldest bytes of that file go. A generation rotate still drops the oldest boot. These numbers are the proposal. They are not implemented.

## Tests that exist

`scripts/tests/test_log_history.sh` checks five generations, one rotate per boot, and three PAK files. `scripts/tests/test_pak_logging.sh` checks that all 63 launchers source the helper, that logs off creates nothing, and that a core's stdout and stderr stay in the PAK file with the header. The RetroArch check uses a stub. `scripts/tests/test_portmaster_log.sh` checks `portmaster.txt` versus `/tmp/portmaster.log`. None of them toggle the setting under a live session, and none of them are a Flip run.

## 16B1 file-log semantics

Read from the build tree `output/build/retroarch-v1.22.2`, which is the pin `RETROARCH_VERSION = v1.22.2`. `retro_main_log_file_init` opens the path with `fopen_utf8(path, append ? "ab" : "wb")`. `rarch_log_file_init` passes append false on the first open of a session. The comment in that function says the log file is overwritten when RetroArch is launched. `retroarch_main_init` first calls `retro_main_log_file_init(NULL, false)`, which sets the log stream to stderr. `--log-file` together with `-v` then replaces that stream with the file. `DEFAULT_LOG_TO_FILE` is false. `libretro_log_cb` calls `RARCH_LOG_V` and the other `RARCH_*` writers, and those write the verbosity stream.

A host check opens a file with Python `"wb"` after a header is written. The header is gone and the new bytes remain. That is the open mode, not a run of the RetroArch binary. The same test then launches `ra-run` through `pak-log.sh` with a stub `retroarch` that truncates if it is given `--log-file`, writes stdout and stderr, and exits 7. The PAK file keeps the header, the ROM text, and both streams, the arguments contain `-v` and not `--log-file`, and the status is 7. The stub line is not a RetroArch diagnostic. The binary was not executed. What the pinned source shows is that `-v` without `--log-file` leaves `RARCH_LOG` on stderr, which the redirect already owns, and that `--log-file` on the PAK path would truncate it.

Chosen capture: redirect the waited shell, and pass `-v` without `--log-file`. A separate RetroArch log file was the other option. It would keep the header only by writing somewhere else, and it would still miss stdout unless the redirect existed too. The redirect plus `-v` is the smaller path and does not add a process or a pipe. `exec retroarch` is unchanged, so the spawn leader and MENU+START ownership stay the waited RetroArch process. If the PAK file cannot be opened, an ordinary probe fails and the redirect is skipped, so the launch still starts. A failed `exec` redirection is fatal in a POSIX shell, and that case was not run under BusyBox. Input and the other `--appendconfig` entries are unchanged. One session line, `log_to_file = "false"`, is appended only for this capture so a saved true cannot move `RARCH_LOG` off stderr. It is not written back. `ZLYME_RA_DEBUG` is unchanged.

## 16B proposal, before 16B3

The list below is the proposal this reading made. The 16B3 section records what was implemented and which bound is still not a hard cap.

- Service-log tails, the live logging toggle, byte caps, and the total budget. The 2 MiB, 1 MiB, and 32 MiB figures were a proposal at this point in the file.
- Cap PAK files, the OpenBOR directory, and each system generation only after that approval, and not by truncating a file another process still has open.
- Copy bounded tails of the late service logs into `system-0` from `zlyme-logs`, including a copy on the halt path, without a new daemon.
- Verbose modes other than RetroArch `-v` are not enabled. The launch scripts and `start_*.sh` files do not show a safe, source-grounded debug switch for the other shipped standalones or tools. Dolphin's `-v` is the video backend, not a log level. Port scripts are not given a flag. Anything that would be unbounded waits for the retention slice.
- Keep the two `rc.late` copies.
- Leave HDMI trace and `ZLYME_RA_DEBUG` on their own flags.
- Do not log ScreenScraper URLs, Wi-Fi PSKs, or git commands that carry credentials.

A Flip check still has to show that a real RetroArch 1.22.2 `-v` line, and a core log callback, land in the PAK file without losing the header. The host stub does not do that. The same later pass covers one standalone, RetroArch with no game, PortMaster, and one shutdown with logs on.

## 16B3 implementation

Date: 2026-10-27. Host tests only. No Flip run. No OTA was built.

### Rotation

`S15bootpart` backgrounds `seed`, and `seed` calls `zlyme-logs start boot` before its other work. `S28minui` does not call `zlyme-logs`. The first frame does not wait on a snapshot. Later copies are the ones `nextui-session` already took after the frontend, after a PAK, before halt, and on the pak-copy failure reboot.

The marker `/run/zlyme-logs-generation` is still one generation per logged boot. It is now taken under `flock`. A host model without the lock records two passes of a missing marker. The same overlap through `zlyme-logs` records one pass and creates `system-0` only. That is the reproduction and the correction. It was not timed on a Flip, so the device window is the source order, not a measured race.

`start boot` copies session bytes that already exist, because the switch was on at boot. Any other first `start` in that boot records the current sizes and copies nothing that is already there. `stop` appends the bytes written while the switch was still on, then clears the capture flag and keeps the rotation marker. Text appended after `stop` is absent from the next copy. A second `start` in the same boot does not create `system-1`.

### Retention

Completed PAK files are trimmed to the last 1 MiB before rotation, which is before the new launch opens the file. OpenBOR trims regular files in its log directory the same way, and the test leaves a save and a screenshot in place. PortMaster trims `portmaster.txt` after pugwash has returned, including when prepare, the root export, or the directory change fails inside the restart loop. The on-screen error is read from the full transcript before that trim. `zlyme-logs stop` copies the Weston bytes written up to the switch and remembers that offset. A later `start` does not replace that copy with bytes written afterward. If `zlyme-boot-write` cannot remove `/boot/zlyme-logs`, the next `start boot` tries once while logs are still off. A PortMaster transcript that cannot be opened does not skip pugwash. Ruffle's logs-on auxiliary directory is trimmed to the last 1 MiB of each regular file before the runtime starts. The v4.2 entrypoint still `mkdir`s the appliance `logs` path and exits 3 if that fails. The image symlinks that path to `/storage/.config/ruffle/logs`, so the launcher creates the directory even when the auxiliary files are on tmpfs. Exit 3 would otherwise look like a normal menu return. A replacement of a path does not redirect a descriptor that was already open, which is why none of these trims run against the live file.

`system-0` session copies are shortened so the known files in that generation move toward 2 MiB, and a session copy is also capped at 1 MiB. Service tails are 64 KiB. Past 32 MiB of files `zlyme-logs` itself accounts, it deletes its own files in `system-4`, then `system-3`, then `paks/*.log.2` and `paks/*.log.1`. A user file in `system-4`, a user directory, the current `paks/*.log`, and an unrecognized file under `paks/OPENBOR/` stayed in the host test.

The 32 MiB figure is not a hard ceiling. The current `paks/*.log` is left alone because a launch may hold it, and 63 such files at 1 MiB are already past 32 MiB. An open writer can grow past 1 MiB until the next completed-file trim. There is no `ulimit` and no supervisor. A full card was not simulated. An unwritable directory makes `start` return success and create no generation.

The fifth-generation rotate still removes the `system-4` directory. That is the existing generation slot, separate from the budget deletion, which only removes names `zlyme-logs` writes.

### Service tails

Copied, as tails, only while logs are on:

| Source | Copy | Why it is included |
| --- | --- | --- |
| `/tmp/zlyme-input-late.log` | `services/input-late.log` | startup transcript for InputPlumber, `zlyme-input`, and the Bluetooth start wrapper |
| `/tmp/inputplumber.log` | `services/inputplumber.log` | the daemon's own append, including lines after startup |
| `/tmp/zlyme-input.log` | `services/zlyme-input.log` | the policy daemon's own append |
| `/tmp/zlyme-pipewire-late.log` | `services/pipewire-late.log` | PipeWire startup transcript |
| `/tmp/zlyme-bt-late.log` | `services/bluetooth-late.log` | Bluetooth startup transcript |
| `/tmp/zlyme-storage.log` | `services/storage.log` | later mount failures, not only boot |
| `/tmp/zlyme-led.log` | `services/led.log` | missing sysfs and failed writes |
| `/tmp/zlyme-net-async.log` | `services/wifi-async.log` | the word `reconcile` |
| `/run/zlyme-weston/weston.log` | `services/weston.log` | copied from `zlyme-weston-run` cleanup, before the directory is removed |

PipeWire and `bluetoothd` are not given a new log file. Their later daemon output is not in a Zlyme-owned path after the startup transcript. syslogd and klogd are excluded: there is no Zlyme file, and the stream is not known to be free of unrelated messages. HDMI trace and `ZLYME_RA_DEBUG` stay on their own flags.

### Applications

Ruffle's `RUFFLE_DATA_DIR` is unchanged. `RUFFLE_AUX_LOG_DIR` is `$cfg/logs` only when `ZLYME_PAK_LOG` is set. Otherwise it is `/tmp/zlyme-ruffle/logs`, and the launcher does not create the config log directory on the dry path. That was the logs-off write the 16A table recorded.

RetroArch `-v` is unchanged from 16B1. No other launcher gained a verbose flag. Dolphin's `-v` remains the video backend.

### Privacy

`zlyme-wifi` appends `reconcile` to the async log. The PSK is not in that line. ZcrapeGoat builds a ScreenScraper URL that contains the developer password and the user password. This reading still found no `printf` of that URL. `cheats.c` does print the git argv. The clone URL in that argv is `https://github.com/libretro/libretro-database.git`. Git stderr lines containing `Authorization:` are dropped before they are printed again. PortMaster's transcript is whatever pugwash writes. None of this is a claim that third-party output is clean. No ZcrapeGoat source was changed.

### What the host tests do not prove

They do not run RetroArch, OpenBOR, Ruffle, or PortMaster's real GUI. They do not fill an exFAT volume. They do not show that the seed's `start boot` finishes before `S28` on a Flip. They do not show a long PAK fd staying open across the trim, because the trim is ordered before the new open and the live-descriptor check is a separate replacement of a path.
