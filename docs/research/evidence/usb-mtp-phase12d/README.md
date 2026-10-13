# Phase 12D USB evidence

Small text copies of readings that would otherwise live only under `/tmp`. Passwords and unrelated runtime dumps are not here. A path under `/tmp` is not the durable copy.

The first table is the dirty Linux 7.2.10 image, built Tue Oct 13 08:43:04 UTC 2026, from `zlyme-my355-20261013-0a96c787607b-dirty.tar`. The source tree at those notes was `f6d57cbfc2c0573e9300929ed50c2741f77264c6`. The Flip clock is UTC. The development host clock is UTC+2.

The second table is 12D-E18, on the clean OTA `zlyme-my355-20261013-4bd0b1ecec72.tar`, kernel `7.2.10 #2` built Tue Oct 13 16:08:35 UTC 2026. Working copies were taken from `/tmp/zlyme-usb-12d-e18-20261013T162544Z`. USB File Transfer stayed stopped. The host poll is every sample in that window, and every sample is `no-gadget-id`.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T131719Z-idle-baseline.txt` | Flip snapshot at 13:17:19Z. Gadget stopped, extcon zero, RK817 charging. Copied from `/tmp/zlyme-usb-12d-20261013/regs/idle-baseline.txt`. | `709fe47c4283de381616eaf3b484d6bb63772bf8bbe5a9e71c20761b4b163060` |
| `20261013T132237Z-idle-debugfs.txt` | Device-tree phandles and IRQ 20 ownership at 13:22:37Z. Copied from `/tmp/zlyme-usb-12d-20261013/regs/debugfs-idle.txt`. | `929e7b034076e6179d0b917c8e2c7b8aecd8476a1fc5e1dc8f9808ae391aa8de` |
| `20261013T132318Z-idle-regs.txt` | Selected DWC3 lines and USB2PHY GRF at 13:23:18Z. Copied from `/tmp/zlyme-usb-12d-20261013/regs/idle-regs.txt`. | `af87862ea1637b4983c260698bae2edd7220f70455c32bbb9d6f5601b81db65d` |
| `20261013-fcc00000-regdump.txt` | Full `fcc00000.usb` regdump, 8201 bytes, gadget stopped (`DCTL = 0x00f00000`). The 13:23Z session recorded a dump of that size with the same key registers. The host file later saved at `/tmp/zlyme-usb-12d-speedcap/regdump.txt` has mtime 16:32 +0200 and no date line of its own. | `0ba93680d2576cd3c1355ed5f581477fa5cf9e825352705847ce6218bf165c2e` |
| `20261013T150134Z-host-lsusb-poll.txt` | Demetria `lsusb` poll, 15:01:34Z through 15:01:44Z, every line `no-gadget-id`. This poll ended before the 15:01:56Z active sample. Copied from `/tmp/zlyme-usb-12d-active/host-lsusb.txt`. | `d4076b48a08106ff3adcd3bafeccf949455d7a8322cae5bef703b59958560e8f` |
| `20261013T150156Z-active-session.txt` | Transcribed values from the held-open SSH session. The raw command transcript was not saved as a file. | none; this file is a transcription |

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T162744Z-e18-idle-regs.txt` | Stopped DWC3 summary and lower PHY GRF at 16:27:44Z. `GUSB2PHYCFG(0)` is `0x40101408`. | `3bcfbff4191358c16f80b3c526f2a12edd70f14ee675fdd2efb8169652465a8b` |
| `20261013T162744Z-e18-fcc00000-regdump.txt` | Full stopped `fcc00000.usb` regdump, 8201 bytes. | `109b00440deda71ddc701cd51d239fa913ec4f44fe4eeca062e49d9ee260783e` |
| `20261013T162958Z-e18-dcp.txt` | Lower PHY still DCP at 16:29:58Z, uptime 399, IRQ 20 count 0. | `d7449a3847ea52fb9bfa1a98ea604fabf2e9f3f9f09288d639ede0901da1f79f` |
| `20261013T163027Z-e18-host-journal.txt` | Demetria kernel follow, 16:30:27Z–16:38:03Z, no lines, plus the 16:34:11Z one-shot with no entries. | `c4362af456ac1ae15bb15cb2f7d01ceaa6c09a57743c79a3beedc86a60c57933` |
| `20261013T163027Z-e18-host-udev.txt` | `udevadm monitor` banner and no USB event. | `a75697edb29c2c13f19e67b1fcaa15b36e16e39fd08f9ed40f33e7f029ae5b5a` |
| `20261013T163028Z-e18-host-lsusb-poll.txt` | Timestamped `lsusb` poll, 16:30:28Z–16:37:58Z, every line `no-gadget-id`. | `133dbecb3d42b382652e2deea19aa4bc7125204f316049934e0c4afc285a5d1b` |
| `20261013T163123Z-e18-host-lsusb.txt` | Full `lsusb` and `lsusb -t` at 16:31:23Z. No `1d6b:0100`. | `c2c9687b4373fae81a823690bdc2acb68a2e5ffdab789b0f2e9849da9c1f2153` |
| `20261013T163249Z-e18-after-replug.txt` | Both PHYs all zero at 16:32:49Z after two replugs. IRQ 20 count 6. RK817 still DCP. | `8dbaaadd045fc7872780025ca7f28f8fbdbbb20e9e25091980ba4e17da0e2679` |
| `20261013T163343Z-e18-grf.txt` | GRF at 16:33:43Z. Power word `0x00000c00`, `0x00c0` `0x00384e73`, extcon still zero. Debugfs unmounted. | `e2dfd6b6947b61eb7f084646d373491156fe0319e28c02899d148d1e819d89fb` |
| `20261013T163411Z-e18-dmesg.txt` | Boot phy-supply lines only. No `dwc3` line. Helper off, NextUI pid 502. | `06775bc8c152a7f422797520d32e0943b3e075f88e799171453bab909e526a15` |
| `20261013T163557Z-e18-identity.txt` | `uname`, `os-release`, and the live `usb@fcc00000` properties at 16:35:57Z. | `5945a7ffb4e7d78c0caeb71e45cd0ab903571f9647404486e57d7c433ff5a52c` |
| `20261013T163606Z-e18-settled.txt` | Extcon still zero at 16:36:06Z. IRQ 20 still 6. Battery status `Discharging`. | `ebd31c0295551fdefad5adccbf1d0dd18bbf29704cc7bc7deafa297345a0cd12` |
| `20261013T163643Z-e18-charger.txt` | Capacity 100, charger still online, `usb_type` still DCP, at 16:36:43Z. | `e3cd9612b00b1eb68730908ac36af6fd108486bcdbbea8b79969a2fb0f3b0a97` |

The third table is 12D-E19, on that same clean OTA and the same boot until the restart at about 17:00:49Z. Dynamic debug was limited to the OTG worker and the charger worker.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T165553Z-e19-dyndbg-before.txt` | The ten `dev_dbg` sites, all `=_`, before the test. No bvalid-irq site exists. | `c8aacf591cf41b3f839ea4a5af661bc7a67d4508440bed257c263b9490309c2f` |
| `20261013T165553Z-e19-dyndbg-enabled.txt` | Those same ten sites set to `=p`. | `3b10c72f71c14f2c2b9a3d76f8d8a6eaf73a28b1c08814615ceedd3d141dff29` |
| `20261013T165630Z-e19-initial.txt` | Extcon zero, GRF, RK817 DCP, IRQ 20 count 6, helper off, at 16:56:30Z. | `525924b2c60bdf96b8da4f7fa9b504bb25f317b250f28ee48db6c13635d52938` |
| `20261013T165745Z-e19-idle-dyndbg.txt` | `dmesg` excerpt of the `b_peripheral` loop before the replug. | `6ac9fbc66fb48caacf6cde7df33155863450ca12f53784763d3333efa1130f55` |
| `20261013T165809Z-e19-kmsg.txt` | Filtered `/dev/kmsg` from 16:58:09Z through the disconnect, the SDP detection, and the following `b_peripheral` loop. | `2575d68b5aa23bdf19b22563a243589bd687e72b1df2663c9331d763f8f05e00` |
| `20261013T165812Z-e19-poll.txt` | One-second extcon, IRQ, GRF, and helper poll from 16:58:13Z until the SSH drop at 17:02:45Z. SDP becomes 1 at 16:59:05Z. | `9287e49e050b1dcc8d83992d1f80748276956195aff91ecaa11f965b8018f5b7` |
| `20261013T170143Z-e19-host-journal.txt` | Demetria kernel follow from 17:01:43Z. No kernel lines. | `2ae3c68454fba9879798b4d22b0ea660237fad0c4da5048ef1a8f65ef202f682` |
| `20261013T170144Z-e19-host-lsusb-poll.txt` | Host `lsusb` poll from 17:01:44Z. Every line is `no-gadget-id`. | `cb2311651530c059aac1c1d97b4d39b03755ee2d4343ea00a7ec3308c376ef96` |
| `20261013T170502Z-e19-active-regdump.txt` | DWC3 regdump at 17:05:02Z on the new boot, gadget bound, `RUN_STOP` clear, bit 8 clear. | `b7e2a2a8e6f838bdec8d3a5d3c9472880e8a3258ae0459c1e90f95d0a8b73a7d` |
| `20261013T170502Z-e19-active-dmesg.txt` | This boot's `ep0out` failure and the dynamic-debug flags back at `=_`. | `a58b23986b9e2049cfbc09a67b245a89844ff235f9f8901b710989fcce315b22` |
| `20261013T173112Z-e19-reboot-read.txt` | Read-only check of the 17:00:49Z boot: empty pstore, `ON_SOURCE=0x02`, `OFF_SOURCE=0x08`, and the Mali workqueue warning. Nothing was deleted. | `316a5769d3b7f09052d4fcc2ec4485cdcc91b4456379625e9c9db99ff0e6a342` |

The 7.0.2 session directories named in section 10 of `usb-mtp-phase12d.md` were already absent when that section was written. They are still absent.
