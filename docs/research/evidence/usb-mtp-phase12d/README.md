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

The fourth table is 12D-E20, on `zlyme-my355-20261013-dd0d717f331f.tar`, kernel `7.2.10 #1` built Tue Oct 13 18:02:11 UTC 2026. Working copies were taken from `/tmp/zlyme-usb-12d-e20`. The Flip clock is UTC. Demetria is UTC+2.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T182135Z-e20-dyndbg-before.txt` | The ten PHY `dev_dbg` sites, all `=_`, before the test. | `be43ebd0ed878c5b68536e60e55c66db97a52722deb2d8641467cfaa38dad5ad` |
| `20261013T182135Z-e20-dyndbg-enabled.txt` | Those same ten sites set to `=p`. | `a27ad27bcce4599a961e76f6583fb3a85feb71959a4bdccef1032c3c4073957f` |
| `20261013T182135Z-e20-idle-regdump.txt` | Stopped `fcc00000.usb` regdump and lower GRF. `GUSB2PHYCFG(0)` is `0x40101408`. `DCTL` is `0x00f00000`. | `98ce882f34b673ab780ff750af8dbdb9a12599fc706f84f5588aa5d3f7e3d518` |
| `20261013T182135Z-e20-flip-kmsg.txt` | Filtered `/dev/kmsg` from the DCP idle, the one replug, the SDP detection, and the later `b_peripheral` loop. No restore line. | `f31883b6fc86e1190977c8b904d2873738d66f46d3b4b69d8594c0c883858da1` |
| `20261013T182135Z-e20-flip-poll.txt` | Extcon, IRQ 20, RK817, UDC, and helper poll from 18:28:01Z through the replug and the PAK. | `b1a364655458b8445eac667300e692c72ce8c5e4628285f9d4738e3c9621cdba` |
| `20261013T182135Z-e20-host-journal.txt` | Demetria kernel follow. No USB line. The only line is an amdgpu message at 20:50:21+02, after the gadget was gone. | `ff36e0434a30aab127fe9fe6ffd7882bd25ea4033985c0ce4eaef7a709e249ef` |
| `20261013T182135Z-e20-host-udev.txt` | `udevadm monitor` banner and no USB event. | `a75697edb29c2c13f19e67b1fcaa15b36e16e39fd08f9ed40f33e7f029ae5b5a` |
| `20261013T182135Z-e20-host-lsusb-before.txt` | `lsusb` and `lsusb -t` at 18:27:51Z, before the cable moved. No `1d6b:0100`. | `befd828b1637ad4cca727669ab0652253b0e0ee9a4d8451bb60b2e3190b1000c` |
| `20261013T182135Z-e20-host-lsusb-poll.txt` | Host gadget poll, 18:27:53Z–18:43:07Z, every line `no-gadget-id`. | `3e0adb57a18e9c6b856bff51c8ad6e2973fa37897ce7e4a339ff8989b7d7c195` |
| `20261013T183200Z-e20-host-lsusb-poll.txt` | Continuation poll, 18:33Z–18:52:00Z, every line `no-gadget-id`. Covers both active snapshots. | `caa19c101649e7799ab83f2687088f1ea0f94bf9d8ba6e9dd71464b4a76d0ef4` |
| `20261013T183300Z-e20-sdp-grf.txt` | Written record of the post-replug GRF words, gadget still stopped. Not a raw debugfs dump. | `d4a65eba77cedca4f93a15f30505b27c69e3d3ef05864d69f4ddb48b5f63f5dd` |
| `20261013T183600Z-e20-active1-userspace.txt` | First active snapshot at 18:36:23Z. Helper bound, UDC not attached, watcher latch `connect`. | `5be9fd106b3af5442f6a1c04ab485d0a32eac7d7cbb9fe7fe889177473a1c89d` |
| `20261013T183600Z-e20-active1-regdump.txt` | Full active regdump. `DCTL` is `0x80f00000`. `DSTS` is `0x008e0001`. `DALEPENA` is `0x3`. | `f67bf8db18287302e2d61f3c6aaa87974d4535b791f1e6da6c460f6ef1f2f954` |
| `20261013T183600Z-e20-active1-host.txt` | Host `lsusb`, `lsusb -t`, and empty gadget query at 18:36:29Z. | `c13e9457b0713a7c15e360bc2014c281d818d0436f1859c1857974e0661cbcaf` |
| `20261013T183800Z-e20-active2-userspace.txt` | Second userspace snapshot at 18:41:49Z. Still bound, still not attached. The `dmesg` tail is the PHY worker. | `fbb30296423bfda872a7d09f7de1c83e126b886c320e68d2ad307b35117b8a49` |
| `20261013T183800Z-e20-active2-regs.txt` | Second register read at 18:41:48Z. Same key registers. EP0 `control`. GRF `0x00c0` is `0x00384e51`. | `8c9a88bb3ea82a6278f7662ce5a0ed4414a80db9acac4f21ad9dda8833d11845` |
| `20261013T183800Z-e20-active2-host.txt` | Host poll around both snapshots and a kernel journal query with no entries. | `eb8d3812fe75420743b814f74d49cd807183bb1ea0f4cd758c99498f2e1d833e` |
| `20261013T184200Z-e20-dmesg-scan.txt` | Whole-boot scan: no gadget or EP0-enable lines. `soft_connect` is write-only. Log still starts at boot. | `4d741136de01ce1ff4f27b5d505f7890ef01489068341d36959190428e2d1eeb` |
| `20261013T184500Z-e20-cleanup.txt` | After B: helper off, gadget gone, FunctionFS unmounted, NextUI back, dynamic debug restored. | `d6e5f561d6539c857e8c1d569640ce03795927d152999427f3f16077bf3718a2` |

The fifth table is 12D-E21, on the same image and the same boot as 12D-E20. Working copies were taken from `/tmp/zlyme-usb-12d-e21`. The repeated `lsusb` poll is reduced to the blocks where the device list changed. `usbmon` was not loaded: `modprobe` returned `Operation not permitted`, and no package was installed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T191708Z-e21-host-lsusb-before.txt` | Demetria `lsusb` and `lsusb -t` at 19:17:08Z. Bus 7 has only its root hub. | `ee2dba3f25dc6bbe5f6108ad57a8e8ac05fcf4cc229a8e4d827f89b6260ca9d7` |
| `20261013T191740Z-e21-baseline-debugfs.txt` | Stopped DWC3 mode, link, key registers, and lower GRF at 19:17:40Z. `mode` is `device`. | `f429609824ab553f6d9e8564f5b4bba5c55d441b9978ff60983710dc1832bf1d` |
| `20261013T191740Z-e21-clocks.txt` | Lower USB clock enable counts and rates from the following read-only debugfs mount. | `f2b1168c4668e3034a935a05a77b1beec44cd0d7a49e8145de3ba40b51b17cc8` |
| `20261013T191849Z-e21-baseline-userspace.txt` | Extcon SDP, UDC not attached, helper off, NextUI pid 14589, at 19:18:49Z. | `7a07b4ffd11af8fb88b463e15b9ff5a92d8aefcbc7b8cfce8e1433862eda0185` |
| `20261013T191859Z-e21-host-journal.txt` | Demetria kernel follow: hub connect, hub disconnect, MTP connect, MTP disconnect, mass-storage connect, and mass-storage disconnect. | `8c258f6a0e95650d7275d509ac1d475de2edbf3e6718beaa234357755d717db3` |
| `20261013T191859Z-e21-host-udev.txt` | USB uevents for those same three connections and three removals. | `9dd8e2876c9c23a551470ee3654a4496e1170453ddba325e96838cecd6a4046f` |
| `20261013T191859Z-e21-host-lsusb-changes.txt` | `lsusb` blocks that differ from the previous sample, 19:18:59Z through the mass-storage removal. | `d089e07c7148164130564e60a8809bf8226343825968eca5dddf9b5b9be00396` |
| `20261013T193257Z-e21-host-mtp-lsusb-v.txt` | `lsusb -v -d 1d6b:0100` at 19:32:57Z. High speed, one MTP interface, three endpoints. | `95114c718e7e21811175a0de11b116b108eede3dbebb3da894b9a2769e1de15a` |
| `20261013T193524Z-e21-mtp-flip.txt` | Transcribed Flip readings while MTP was configured. `link.writes` was absent. | `45802eee0a56ffbf46542ceea82deeb9bc8f85a686b693c09f2212db37be39a7` |
| `20261013T194426Z-e21-ms-remote.txt` | Stage log of the temporary mass-storage session, including cleanup at 19:45:21Z. | `d8859219188852dc65cb6c0a6709ee4adf5087661956422484b57a233f092512` |
| `20261013T194430Z-e21-ms-flip.txt` | Bound snapshot, cleanup record, the two new `dmesg` lines, and the stage log. | `dcb47db8a381edf768af7538e305fb99785619a5bc213edbcb492dad95d526e5` |
| `20261013T194459Z-e21-host-ms-lsusb-v.txt` | `lsusb -v -d 1d6b:0104` at 19:44:59Z. High speed, one mass-storage interface. The descriptor read says the device was busy. | `227d96bde1817938ec580667296c8ea3ba1c1f015c39c12dae6d6967bed9e5d6` |

The sixth table is 12D-E22, after `zlyme-my355-20261013-4a2b752bafbe.tar` was installed. The USB File Transfer page was already closed. The helper was not started from SSH. `/boot` was not written.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T212222Z-e22-stopped.txt` | Installed hashes, update paths, mounts, this boot's EP0 lines, UDC `not attached`, extcon0 DCP, and Demetria bus 7 with no gadget. | `1b044de27964ae6c0fdcb0ee115dd196bbce6ea390c687ae8c5b9496c73cace0` |

12D-E23 is a source correction. The candidate OTA is `zlyme-my355-20261013-13071973a350.tar`, SHA-256 `2f41f13de96f231bd8cf8f95cb01b7b2029c6cb17a0010779afb2692a2a89945`. A later reading found that archive installed. The seventh table is that reading. The PAK was not launched.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261013T222106Z-e24-prestart.txt` | Installed hashes, `state=off`, UDC `not attached`, extcon0 DCP, and Demetria with no Flip gadget. | `9bdbe4998cc03029709db9d180405a56c965a08168fdf6a8f2211644b693e323` |

The eighth table is 12D-E25. The E24 archive was installed. A file copy was not verified. The Flip restarted during the pass.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T004529Z-e25-acceptance.txt` | Installed E24 hashes, the high-speed enumeration on Demetria bus 1 port 2, the PTP I/O errors, the disconnect, and the post-reboot inspection. | `fc26a4629fc8f502f2b8d2a31e5de02f30e43e06f86436e62d3f7e454aae2538` |

The ninth table is 12D-E26, on that same installed image and the following boot. The PAK session was already up. Disposable SHA-256 values matched in both directions. B was not pressed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T020236Z-e26-file-match.txt` | Live session on Demetria bus 1 port 2, the matching SHA-256 pairs, the second-card copy, rename and delete, and the still-bound gadget. | `4f738302c1b2631e2b1b597a3d0505e5dfe893f829e7e2c0acee10cfe101c711` |

The tenth table is 12D-E27. The E26 gadget was gone. A second host enumeration was not logged.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T022643Z-e27-cleanup.txt` | Device 48 disconnect, empty gadget check, mounted data partitions, and the maintainer's second-Start report kept separate from the log. | `a959b0537be38af28df794b4eb01f1b06fa19f09f481171e2258c9982a3940a3` |

The eleventh table is 12D-E28. The EP0-recovery removal archive is installed. The maintainer reports that USB File Transfer works. No new file checksum was taken.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T085310Z-e28-installed.txt` | Installed archive and squashfs hashes, the live helper and kernel identity, helper off, and the maintainer's report kept separate from a file copy. | `eff4f0c6191b9216bea88e0f00365e24e7f8b62a764d9d06830b46f82ad0b46d` |

The twelfth table is 12D-E29. The USB2 PHY extcon resync patch is absent from this candidate. The candidate is not installed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T091045Z-e29-candidate.txt` | Clean Linux extract, the unpatched PHY object, and the candidate archive hashes. | `cb13d2a7d7cac03b1319a6e59f6f74a73861386365ca8629bc5e88967d9d5caf` |

The thirteenth table is 12D-E29 installed. The maintainer reports that MTP works. Demetria logged five high-speed enumerations. No new file checksum was taken.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T095100Z-e29-installed.txt` | Installed squashfs, kernel, and DTB hashes, the missing restore string, cleanup, and the host enumeration log kept separate from a file copy. | `49767a9a29f778ebe08fdd4e33b92a60b3417c5b52d436eff32b57456d2b27ff` |

The fourteenth table is 12D-E30. The lower-controller ENBLSLPM property is absent from this candidate. The candidate is not installed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T100426Z-e30-candidate.txt` | One-line DTB difference, the 66-byte kernel relink, and the candidate archive hashes. | `e50664bee64df152c49c5dedbb1fe8fa127004e6b041453b717547be3b854ed5` |

The fifteenth table is the 12D-E31 stopped inspection, before the PAK was opened.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T103652Z-e31-installed.txt` | Installed squashfs, kernel, and DTB hashes, the live tree without the ENBLSLPM property, idle `GUSB2PHYCFG(0) = 0x40101508`, and the empty MTP window at that reading. | `ec0ae711d702068a56b9ffbbdcf277641839b2b97418729ac7770e6be951d02d` |

The sixteenth table is the later 12D-E31 session on that same boot. The PAK was already open. Disposable SHA-256 values matched. The cable was not moved.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T105637Z-e31-live.txt` | Device 15 on Demetria bus 1 port 2, the matching SHA-256 pairs, the second-card copy, rename and delete, and the still-configured gadget. | `e9fa78a1a2d76498c3d838686d3ce3319539d737b6c69e35d4e6072673f4293e` |

The seventeenth table is 12D-E32. The cable-loss soft_connect pair is absent from this candidate. The candidate is not installed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T111800Z-e32-candidate.txt` | The reconnect source reading, unchanged kernel and bootloader hashes, and the candidate archive. | `4cfc5e0f7091315491614a7a9e74aab98eb64cc10c14594bfc627592592c83df` |

The eighteenth table is 12D-E33. The Flip was still the E30 image. The E32 candidate was not installed.

| File | What it is | SHA-256 |
| --- | --- | --- |
| `20261014T113707Z-e33-not-installed.txt` | E30 hashes on a new boot, the device 16 disconnect, and the unidentified reboot before any E32 test. | `585064242e2ed2929a7fd56d9bc81228b79c65fff47c7d2a44cdaceef120af36` |
