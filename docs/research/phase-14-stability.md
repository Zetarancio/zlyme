# Phase 14 stability

The archive `PHase14 freeze during test.zip` was read locally on 2026-10-20. It is not in git. The installed image is still the unaccepted `e2ecc05` candidate. None of these notes is a captured kernel panic.

## What the archive shows

PPSSPP 1.19.3, Z.H.P., log opened `2026-10-19T20:20:47Z`. `PSP.log` has 4177 `snd_pcm_recover` underrun lines. `PSP.log.2` has 4093. That is the ALSA client recovering inside the emulator, not a board reset by itself.

Mina the Hollower, `PORTS.log.2.part`, 14441 OpenAL Soft lines: `available update failed: Broken pipe`. The file is truncated at 737280 bytes and ends mid-line. The broken pipe is a client write to a stream that went away. The log does not say which of a dead server, a bad socket, or a retry loop it was.

`PORTS.log.1` is the 10:16Z Abombniball transcript from an out-of-session launch. It writes `/root/device_info_Zlyme_Flip.txt` and `/root/pm_dialog.txt` because that shell's HOME was `/root`, then `kmsdrm not available`, then `systemctl: not found`. It is not a menu launch. A menu launch inherits `HOME` from `nextui-session`. There is still no fake `systemctl`.

`system-0` through `system-4` dmesg snapshots stop about 5–6 seconds after boot. Mali prints `__alloc_workqueue` / name-length warnings while the driver probes. exFAT is unclean in some boots. One session cannot open the system D-Bus socket before InputPlumber. No snapshot contains a later panic, OOM, or watchdog line.

## What is proven

- The kernel config enables `CONFIG_PSTORE` and does not enable `CONFIG_PSTORE_RAM` or `CONFIG_PSTORE_BLK`. A panic is not expected to remain on disk.
- A frozen userspace can still answer ICMP and complete a TCP handshake on port 22 without sending an SSH banner. That is not, by itself, a reboot.
- PPSSPP's SDL path asks for 256 samples at 44100 Hz unless `AudioBufferSize` is set. The resampler target is 1680 samples. The underrun text is SDL/ALSA recover. Raising the old Pulse fragment count did not stop it. No PPSSPP default was changed in the PipeWire commit, and the saved ini is still not rewritten.
- OpenAL Soft's broken pipe is not fixed by hiding the line. PipeWire is the intended server. Which backend Mina opened is not proven from the truncated log.

## What is not proven

- That any freeze was a full board reset, a panic, a thermal reset, or a watchdog.
- That the 12-fragment buffer or the one-shot pak trace caused a reset. The trace does not run unless `/storage/.config/zlyme/pak-trace` or `ZLYME_PAK_TRACE=1` is set.
- That Abombniball fails the same way from the menu as the 10:16Z probe.

## Safe next diagnostic

When SSH answers, copy `/storage/.logs` and `dmesg` into `/storage/.config/zlyme/diagnostics/phase14/<boot-id>/`. Do not stress the device to force another freeze. Do not add a kernel patch for pstore until a boot record shows the current backend cannot be read.
