# Phase 12D USB evidence

Small text copies of readings that would otherwise live only under `/tmp`. Passwords and unrelated runtime dumps are not here. A path under `/tmp` is not the durable copy.

The running image for every 2026-10-13 Flip reading below was Linux 7.2.10, built Tue Oct 13 08:43:04 UTC 2026, from the dirty OTA `zlyme-my355-20261013-0a96c787607b-dirty.tar`. The source tree at the later notes was `f6d57cbfc2c0573e9300929ed50c2741f77264c6`. The Flip clock is UTC. The development host clock is UTC+2.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T131719Z-idle-baseline.txt` | Flip snapshot at 13:17:19Z. Gadget stopped, extcon zero, RK817 charging. Copied from `/tmp/zlyme-usb-12d-20261013/regs/idle-baseline.txt`. | `709fe47c4283de381616eaf3b484d6bb63772bf8bbe5a9e71c20761b4b163060` |
| `20261013T132237Z-idle-debugfs.txt` | Device-tree phandles and IRQ 20 ownership at 13:22:37Z. Copied from `/tmp/zlyme-usb-12d-20261013/regs/debugfs-idle.txt`. | `929e7b034076e6179d0b917c8e2c7b8aecd8476a1fc5e1dc8f9808ae391aa8de` |
| `20261013T132318Z-idle-regs.txt` | Selected DWC3 lines and USB2PHY GRF at 13:23:18Z. Copied from `/tmp/zlyme-usb-12d-20261013/regs/idle-regs.txt`. | `af87862ea1637b4983c260698bae2edd7220f70455c32bbb9d6f5601b81db65d` |
| `20261013-fcc00000-regdump.txt` | Full `fcc00000.usb` regdump, 8201 bytes, gadget stopped (`DCTL = 0x00f00000`). The 13:23Z session recorded a dump of that size with the same key registers. The host file later saved at `/tmp/zlyme-usb-12d-speedcap/regdump.txt` has mtime 16:32 +0200 and no date line of its own. | `0ba93680d2576cd3c1355ed5f581477fa5cf9e825352705847ce6218bf165c2e` |
| `20261013T150134Z-host-lsusb-poll.txt` | Demetria `lsusb` poll, 15:01:34Z through 15:01:44Z, every line `no-gadget-id`. This poll ended before the 15:01:56Z active sample. Copied from `/tmp/zlyme-usb-12d-active/host-lsusb.txt`. | `d4076b48a08106ff3adcd3bafeccf949455d7a8322cae5bef703b59958560e8f` |
| `20261013T150156Z-active-session.txt` | Transcribed values from the held-open SSH session. The raw command transcript was not saved as a file. | none; this file is a transcription |

The 7.0.2 session directories named in section 10 of `usb-mtp-phase12d.md` were already absent when that section was written. They are still absent.
