# Miyoo Flip gamepad — Phase 3A

Date: 2026-09-23. Research only. No driver, DTS, or kernel patch was changed.

This document replaces the 2026-09-14 note that said to keep the ROCKNIX serial module. That recommendation is obsolete. The target is a Zlyme driver for the Flip's actual hardware.

Evidence labels:

```text
PROVEN
STRONGLY SUPPORTED
DESIGN DECISION
REQUIRES TRACER VALIDATION
UNKNOWN
```

## Decision

```text
physical input device:  Miyoo Flip Gamepad
analog transport:       UART1 / serdev
analog protocol:        9600 8N1, frame FF YL XL YR XR FE
buttons:                17 GPIOs, interrupt-driven after tracer proof
rumble:                 FF_RUMBLE -> PWM5
Linux topology:         one input_dev
identity:               BUS_HOST, name "Miyoo Flip Gamepad"
                        vendor = product = version = 0
                        not Xbox, not Xbox 360, not a Nintendo Switch
```

Phase 4 may add a virtual compatibility controller. The physical driver must not.

`DESIGN DECISION` unless a line below says otherwise.

## What is proven about the hardware

### Analog path — PROVEN

Stock `miyoo_inputd.c` (`spi_20241119160817/unpack/joystick_study/miyoo_inputd.c`) opens `/dev/ttyS1` and calls `trimui_uart_set(fd, 9600, 0, 8, 1, 'N')`: 9600 baud, 8 data bits, no parity, 1 stop bit, hardware flow control off.

The frame struct is six bytes:

```text
FF  YL  XL  YR  XR  FE
```

`0xFF` starts a frame. `0xFE` ends it. Each axis is one unsigned byte. A comment in that file shows an example frame `FF 80 9A 88 93 FE`.

The current Zlyme module (ROCKNIX `rocknix-joypad` pin `3bc3ef644`, object `rocknix-singleadc-joypad.o`, plus Zlyme patches `0002` and `0003`) parses the same frame after `filp_open("/dev/ttyS1")` and an in-kernel termios edit to `B9600 | CS8 | CREAD | CLOCAL`.

A Rockchip 8250 `base_baud` of 1500000 is the UART divisor reference, not the stick line rate.

### Buttons — PROVEN

Stock firmware `miyoo355_fw_20250527` decompiled DTS (`miyoo355_20250527_0.dts`, model `MIYOO RK3566 355 V10 Board`) has one `gpio-keys-polled` node, `poll-interval` 10, `debounce-interval` 10, and `autorepeat`. Phandle `0x10b` is `gpio3@fe760000`. Phandle `0x10c` is `gpio2@fe750000`. Flag `1` is active-low. Flag `0` is active-high.

Those pins match the seventeen gamepad GPIOs in `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts`:

| Control | GPIO | Stock DTS label | Stock `linux,code` | Zlyme `linux,code` |
| --- | --- | --- | --- | --- |
| D-pad up | `gpio3` PA3, active-low | `up` | `KEY_UP` | `BTN_DPAD_UP` |
| D-pad down | `gpio3` PA4, active-low | `down` | `KEY_DOWN` | `BTN_DPAD_DOWN` |
| D-pad left | `gpio3` PA5, active-low | `left` | `KEY_LEFT` | `BTN_DPAD_LEFT` |
| D-pad right | `gpio3` PA6, active-low | `right` | `KEY_RIGHT` | `BTN_DPAD_RIGHT` |
| South (silk side of stock label `b`) | `gpio3` PC2, active-low | `b` | `KEY_LEFTCTRL` | `BTN_SOUTH` |
| East | `gpio3` PC3, active-low | `a` | `KEY_SPACE` | `BTN_EAST` |
| North | `gpio3` PC1, active-low | `x` | `KEY_LEFTSHIFT` | `BTN_NORTH` |
| West | `gpio3` PC0, active-low | `y` | `KEY_LEFTALT` | `BTN_WEST` |
| Select | `gpio3` PB6, active-low | `select` | `KEY_RIGHTCTRL` | `BTN_SELECT` |
| Start | `gpio3` PB5, active-low | `start` | `KEY_ENTER` | `BTN_START` |
| Menu | `gpio3` PA1, active-low | `menu` | `KEY_ESC` | `BTN_MODE` |
| L | `gpio3` PB1, active-low | `l1` | `KEY_TAB` | `BTN_TL` |
| R | `gpio3` PB3, active-low | `r1` | `KEY_BACKSPACE` | `BTN_TR` |
| L2 | `gpio3` PB2, active-low | `l2` | `KEY_PAGEUP` | `BTN_TL2` |
| R2 | `gpio3` PB4, active-low | `r2` | `KEY_PAGEDOWN` | `BTN_TR2` |
| L3 | `gpio2` PC1, active-high | `l3` | `KEY_RIGHTALT` | `BTN_THUMBL` |
| R3 | `gpio2` PC0, active-high | `r3` | `KEY_RIGHTSHIFT` | `BTN_THUMBR` |

Stock also puts volume up/down (`gpio3` PA7 / PA8, `KEY_VOLUMEUP` / `KEY_VOLUMEDOWN`) in that same polled node, and a separate `adc-keys` node reads volume through SARADC. Volume stays out of the new gamepad driver. The lid and the RK817/RK805 power key stay out as well.

Zlyme already reports positional `BTN_*` codes. That is the Linux gamepad ABI to keep. Stock's `KEY_*` values are a keyboard-style report used by the vendor polled node. Do not copy them. Do not copy stock `autorepeat` onto game buttons.

### UART1 pinmux and DMA — PROVEN present, not proven removable

Stock `serial@fe650000` (UART1) is `status = "okay"`, has `dmas`, and `pinctrl-0` references both `uart1m0-xfer` (`0xdb`) and `uart1m0-ctsn` (`0xdc`). The decompiled node has no `dma-names` property. Zlyme's UART1 node adds `dma-names = "tx", "rx"` and the same two pin groups.

Stock userspace disables hardware flow control. That does not prove the CTS pinmux or the DMA descriptors can be dropped. The 3B tracer keeps the current known-good UART pin and DMA setup. Removing `uart1m0_ctsn` or `dma-names` is a later, separate experiment.

### Rumble — STRONGLY SUPPORTED

The live Zlyme path is `FF_RUMBLE` on the gamepad `input_dev`, PWM5, period 10 ms, as described by the Flip DTS and used by `PLAT_setRumble()`. A stock comment in NextUI says the BSP wrote gpio20. That is historical wiring evidence, not the mainline path. Standard force feedback stays the interface.

### Electronics between the pots and UART1 — UNKNOWN

The RK3566 is the UART receiver. Stock never samples the stick pots in `miyoo_inputd`. Some other device digitizes two potentiometer axes and transmits the six-byte frame. No local DTS, `System.map`, string, or public source names that part. It is not a Joy-Con HID microcontroller: the bytes are not HID reports. Do not invent an IC name.

## Nintendo Switch 1 stick modules

`STRONGLY SUPPORTED` as a user report, not as a Zlyme hardware test: more than one person has fitted standard Switch 1 non-Hall potentiometer modules to a Flip, and stock Miyoo OS still reads them. Full travel has been reported to reach approximately the full Linux axis range after that OS's own calibration.

That is mechanical and electrical compatibility with the Flip's existing analog front-end. It is not Nintendo HID.

```text
original Miyoo-compatible potentiometer module
        \
         -> board ADC/controller -> same UART frame -> same driver
        /
Switch 1 non-Hall compatible module
```

`DESIGN DECISION`: one driver, one protocol. No `hid-nintendo`, no Nintendo VID/PID, no HID parser, and no Switch-specific transport for these modules. Differences show up only as observed minimum, center, maximum, and noise.

`DESIGNED COMPATIBILITY` is not `HARDWARE-VALIDATED COMPATIBILITY`. The project owner does not currently have those modules. Phase 3C designs for them. Phase 3B does not wait for them. Phase 3D does not call them supported until a community tester runs the protocol below on a modified unit.

`hid-nintendo` and Switchroot Joy-Con support speak the Joy-Con/Pro Controller transport. None of that parser applies to `FF YL XL YR XR FE`. Generic min/center/max mapping is useful and is already what stock does. It is not Nintendo code.

`adc-joystick` does not apply. The axes are not an IIO channel.

A historical ROCKNIX-based image was reported to show a black screen on a Flip fitted with those sticks. No failure log was captured. Stock on that unit worked. Blocking probe, a calibration wait, or a frontend that will not start without the pad are `PLAUSIBLE` and `UNSUPPORTED` as the cause. They are still hard requirements for the new driver: missing or bad UART data must not block probe, button registration, NextUI, boot, or suspend/resume.

## `miyooio` source search

No published `miyooio.c` was found.

| Location | Result |
| --- | --- |
| Steward-fu tree under `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP/` | No `.c`. The string `[Miyoo]miyooio init` appears in stock boot logs. `Extra/System.map-5.10` and the firmware `System.map` list the symbols. |
| `spi_20241119160817` `zImage` | Does not contain the init string (not the image that was disassembled). |
| `miyoo355_fw_20250527` | Raw ARM64 `Image` (file is named `zImage`). Contains the driver strings. Its `rootfs/info/System.map-5.10` matches that image. |
| Sourcegraph, `miyooio_open` and `file:miyooio.c`, including forks and archived repos | 0 matches |
| Gitee search for `miyooio.c` | No source hit |
| Steward UART page | Boot log line `[Miyoo]miyooio init` only |
| MiyooCFW kernel | Different, older Miyoo devices. Not this driver |

Do not claim the C file exists in public.

## Bounded stock-kernel inspection

Image: `miyoo355_fw_20250527/unpack/zImage`, matched to `unpack/rootfs/info/System.map-5.10`. This was not a full reverse of the stock kernel.

| Symbol | What the image shows | Label |
| --- | --- | --- |
| `miyooio` init string | Printed from inside the `gpio-keys-polled` probe, after the GPIO claim loop and before `input_register_polled_device`'s error string. The chrdev name `miyooio` and class `miyooio_class` are registered there. | PROVEN |
| `miyooio_open` | Prints `Device open!` and returns 0. | PROVEN |
| `miyooio_read` | Copies 128 bytes (32 ints) to userspace. That is what `miyoo_inputd` reads. | PROVEN |
| `miyooio_write` | Returns the caller count and does not use the buffer. | PROVEN |
| `miyooio_release` | Returns 0. | PROVEN |
| Poll vs IRQ | The DTS node is `gpio-keys-polled`. Probe and the poll function walk the child GPIOs. | PROVEN |
| Debounce | DTS `debounce-interval` is 10. The polled core uses that interval. No separate IRQ debounce was recovered. | PROVEN for the DTS value |
| `joy_type` | `joy_type_store` parses a decimal, stores `s_joy_type`, and prints `set joy type:%d [-1=none 0=miyoo 1=xbox]`. `joy_type_show` prints it back. A scan of kernel text found no other reference to `s_joy_type`. | PROVEN for this image |
| `str_to_code` | Maps labels `A/B/X/Y/L/R/L2/R2` onto the same `KEY_*` values already stored in the stock DTS. It has callers in the button-report helper. The DTS already sets `linux,code`, so this is a label fallback, not a second electrical map. | PROVEN that the function exists and is called |

`joy_type` does not change button behavior in this kernel. The face-button swap lives in `miyoo_inputd.c` under the comment `//xbox pad layout`: RetroPad A is reported as Linux `BTN_B` and B as `BTN_A`. Those are positional codes (`BTN_A` is south). The program does not set a Microsoft USB id.

Nothing recovered here changes the new driver. Stock `/dev/miyooio` is the vendor button/control mechanism. Stock `/dev/ttyS1` is the analog data. Zlyme already has the physically validated GPIO map and reports a normal `input_dev`. Do not recreate `/dev/miyooio` or `/sys/class/miyooio_chr_dev/joy_type`.

## Why the current module is not the target

Pinned source is ROCKNIX `rocknix-joypad` `3bc3ef644` (`Copyright (C) 2024 ROCKNIX`, SPDX `GPL-2.0-or-later`, `MODULE_AUTHOR("ROCKNIX")`). Current ROCKNIX tip `d02ed13aae08113f6f9e0e9d699cb29bb3450fa2` only adds `MODULE_IMPORT_NS("IIO_CONSUMER")`. Zlyme patches `0002` and `0003` are by Zetarancio. Any copied lines keep that authorship and the GPL header. The new driver, compatible string, and input name must not use ROCKNIX branding.

| Mechanism | Class |
| --- | --- |
| One `input_dev` for buttons, axes, and rumble | REUSE CONCEPT |
| These seventeen GPIOs as the Flip buttons | REIMPLEMENT |
| `input-polldev` and the 6 ms poll | DROP |
| Generic ADC mux properties | DROP for this board |
| Frame `FF … FE` at 9600 8N1 | REUSE CONCEPT, REIMPLEMENT on `serdev` |
| `filp_open("/dev/ttyS1")` and in-kernel termios edits | DROP |
| 10-second delayed work before serial start | DROP |
| Serial kthread | REIMPLEMENT as a `serdev` receive path |
| Boot auto-cal that can race userspace | REIMPLEMENT as non-blocking center only |
| Sysfs `miyoo_cal_left` / `miyoo_cal_right` | REPLACE with the minimum transform interface below |
| PWM `FF_RUMBLE` | REUSE CONCEPT |
| System-sleep callbacks | REIMPLEMENT |
| `joypad_input_g` and the `adc-keys` keycode-316 redirect | DROP after cutover. The Flip DTS has no `adc-keys` gamepad node. The symbol is only a link dependency. Menu is GPIO `BTN_MODE`. |
| Names `rocknix-singleadc-joypad` and `retrogame_joypad` | DROP |
| Vendor `0x484B`, product `0x1101`, version `0x0100` | DROP. These are DTS properties of the old driver. `0x484B` is the ASCII pair `H` `K`, not a Miyoo assignment found in OTP or USB. |

The old driver assigns `joypad_input_g` and needs the exported symbol to load. `rk_send_key_f_key_up` / `_down` run only if `adc-keys` sees keycode 316. Nothing on the Flip produces that event.

SARADC is enabled in the Flip DTS (`&saradc { status = "okay"; }`) with a comment that still says the joypad uses channel 0. The analog path is UART. Do not remove SARADC in Phase 3. The stale comment and any unused ADC resource belong to Phase 5 unless the new driver actually conflicts with the node.

## Calibration

Cheap potentiometer modules vary from unit to unit. Calibration is normal, including for original Flip sticks and for Switch 1 non-Hall replacements. Do not treat stock raw defaults such as 85/130/200 as universal. Do not assume the two sticks, or the four axes, share a range. Positive and negative travel may be asymmetric.

Split:

| Layer | Owns |
| --- | --- |
| Kernel | UART decode, runtime transform, deadzone/noise, standard `ABS_*` output |
| Userspace | Procedure, files under `/storage`, UI, when to restore or apply |

The kernel must not open persistent files.

`DESIGN DECISION`:

```text
persistent, independently per axis:  min, zero, and max
boot:                                 a fresh center when the sticks are still
```

The calibration application writes the persistent min, zero, and max. A boot measurement does not rewrite that file.

Do not assume one stored zero stays valid forever. The usual boot pose is both sticks centered and still. That is a hint to the user, not a stall.

### Boot center — 3B/3C requirement, not final constants

After the `input_dev` is registered, collect valid UART frames on the `serdev` receive path.

```text
collect N centered samples
estimate the center with a median or another outlier-resistant statistic
reject the set if the spread or sample-to-sample movement is too large
accept only a stable cluster
```

`N`, the spread limit, and the retry interval are implementation constants to pick in 3B/3C. They are not fixed here.

At boot:

```text
attempt a fresh center from stable, untouched sticks
if accepted:
    use that center for this running boot only
if rejected because the samples are moving or unstable:
    use the persisted zero
if there is no valid persisted calibration:
    use a conservative compiled default zero
```

A successful boot-center measurement must not rewrite the persistent calibration file. The calibration application remains responsible for deliberate persistent calibration. An unstable window may be retried in the background, or left for userspace. It must not install a bad center.

No infinite wait. No 10-second startup delay. No calibration loop inside `probe`. Buttons stay live if UART never yields a valid frame.

### Full-range application

Boot calibration does not learn the ends of travel. The calibration application must still capture, independently for each stick:

```text
x_min  x_zero  x_max
y_min  y_zero  y_max
```

Userspace may write a new center as well as the ends. The kernel applies whatever set is installed.

Prefer one sysfs attribute per stick, or one attribute for the whole pad, carrying those integers. Do not add a character device for calibration.

### Diagnostic

Phase 3C/3D needs a narrow way to read:

```text
raw YL XL YR XR
observed raw min/max
calculated center
active calibration
normalized ABS values
frame-valid and desync counts
```

A debug sysfs attribute or a small userspace reader of that attribute is enough. Do not add a permanent broad debug ABI. The point is to compare an original pair with a community Switch-style pair using the same report.

## Hard failure isolation

```text
no UART data
bad UART data
desynchronized UART data
unexpected raw ranges
```

must not block module probe, button registration, NextUI, boot, or suspend/resume. Axes may go quiet or stay at the last valid report. When valid frames return, parsing resumes without reloading the module.

## GPIO interrupts

Every gamepad line below is `REQUIRES TRACER VALIDATION`. Rockchip GPIO IRQ support is not a hardware pass. Phase 3B must show, on each line, that `gpiod` request, `gpiod_to_irq`, the IRQ request, the polarity, debounce, and press/release all behave.

Preferred mechanism after that proof: event-driven GPIO input inside the one gamepad driver, with software debounce. Stock's 10 ms debounce is a starting point, not a validated Zlyme constant. The current 6 ms poll is a software choice.

Volume, lid, and the PMIC power key are not in this table and not in this driver.

| Control | GPIO | Active level | Status |
| --- | --- | --- | --- |
| D-pad up/down/left/right | `gpio3` PA3 PA4 PA5 PA6 | low | REQUIRES TRACER VALIDATION |
| South / East / North / West | `gpio3` PC2 PC3 PC1 PC0 | low | REQUIRES TRACER VALIDATION |
| Select, Start | `gpio3` PB6 PB5 | low | REQUIRES TRACER VALIDATION |
| Menu | `gpio3` PA1 | low | REQUIRES TRACER VALIDATION |
| L, R, L2, R2 | `gpio3` PB1 PB3 PB2 PB4 | low | REQUIRES TRACER VALIDATION |
| L3, R3 | `gpio2` PC1 PC0 | high | REQUIRES TRACER VALIDATION |

## Device-tree contract

Not applied. Shape for the implementation, not a patch:

```text
&uart1 {
    status = "okay";
    /* keep the current xfer + ctsn pinctrl and DMA setup in 3B */

    gamepad {
        compatible = "miyoo,flip-gamepad";
        current-speed = <9600>;

        pwms = <&pwm5 0 10000000 0>;
        pwm-names = "enable";

        /* 17 gamepad GPIOs, active level, and linux,code
           as in the table above */
    };
};
```

The contract is:

```text
compatible = "miyoo,flip-gamepad"
this node owns UART1 via serdev
protocol is 9600 8N1, frame FF YL XL YR XR FE
17 gamepad GPIOs with Linux event codes and polarity
PWM5 rumble
immutable hardware parameters only
```

No calibration file, no Xbox or Nintendo identity, and no SDL/RetroArch mapping in DTS. GPIO and PWM properties on this UART child are appropriate: the Flip gamepad is one board-specific device that happens to use all three resources.

`serdev` on Linux 7.0.2 can set the baud and deliver bytes from a receive callback. Claiming the port removes `/dev/ttyS1`. Probe still returns if no frame has arrived.

Do not bind this node and `rocknix-singleadc-joypad` at the same time.

## Identity

```text
name:     Miyoo Flip Gamepad
bustype:  BUS_HOST
vendor:   0
product:  0
version:  0
```

No Miyoo Linux vendor or product assignment was found. Do not invent one. SDL mappings for Phase 3D are generated from the device that actually enumerates. Do not keep the old GUID built from `retrogame_joypad` / `0x484B` / `0x1101`.

## Community test protocol

For a later tester who has installed standard Switch 1 non-Hall stick modules. Do not collect account names, serial numbers, or unrelated logs.

Record:

```text
driver and kernel version
input device name, bustype, vendor, product, version
raw UART min, center, and max for YL XL YR XR
normalized evdev min, center, and max for ABS_Y ABS_X ABS_RY ABS_RX
center stability with sticks untouched
full circular movement of each stick
cardinal movement of each stick
L3 and R3
one suspend/resume with sticks centered
one boot with both sticks untouched and centered
one reboot, then the same center check
```

Pass means the same driver and the same frame format work, and the calibration interface can represent that unit's extrema. Failure of this protocol does not revert the original-stick result. It means replacement-stick support stays designed, not validated.

## Phase 3D cutover checklist

Do not edit these in 3A. When the new device name and sysfs exist, update the live consumers together.

Must change a hardcoded name, id, or sysfs path:

| Consumer | What it matches |
| --- | --- |
| `board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts` | node `rocknix-singleadc-joypad`, `joypad-name`, `0x484B`, `0x1101`, `0x0100` |
| `board/my355/fsoverlay/etc/modules-load.d/joypad.conf` | `rocknix-singleadc-joypad` |
| `board/my355/fsoverlay/etc/init.d/S26joypadcal` | module name, `/sys/devices/platform/rocknix-singleadc-joypad`, hotplug `.ko` path |
| `board/my355/fsoverlay/usr/sbin/zlyme-joypad-cal` | `miyoo_cal_left` / `miyoo_cal_right` and that sysfs directory |
| `package/system/nextui/paks/Tools/Autocal.pak/launch.sh` | same sysfs path; calls `zlyme-joypad-cal` |
| `package/system/zlyme-keylidmon/zlyme-keylidmon.c` | `PAD_NAME` `retrogame_joypad` |
| `package/system/nextui/zlyme/zlyme-pak-hotkey.c` | `PAD_NAME` `retrogame_joypad` |
| `package/system/nextui/src/workspace/my355/platform/platform.c` | rumble looks for `retrogame` in the evdev name |
| `package/system/nextui/nextui-session` | `grep retrogame_joypad` on the SDL db |
| `package/system/nextui/zlyme/gamecontrollerdb.txt` | both GUID lines and the name. Installed by `nextui.mk` to `/usr/lib/gamecontrollerdb.txt` and `/usr/share/zlyme/gamecontrollerdb.txt` |
| `package/system/nextui/zlyme/ra-run.sh` | copies `retrogame_joypad.cfg` if the autoconfig dir lacks it |
| `package/emulators/retroarch/zlyme/autoconfig/sdl2/retrogame_joypad.cfg` | name, vendor `18507` (`0x484B`), product `4353` (`0x1101`) |
| `package/emulators/retroarch/zlyme/autoconfig/udev/retrogame_joypad.cfg` | same ids |
| `package/emulators/retroarch/retroarch.mk` | installs those two files twice |
| `board/my355/fsoverlay/usr/share/zlyme/retroarch/autoconfig/sdl2/retrogame_joypad.cfg` | duplicate of the sdl2 file |
| `board/my355/fsoverlay/usr/share/zlyme/retroarch/autoconfig/udev/retrogame_joypad.cfg` | duplicate of the udev file |
| `package/emulators/pico8/start_pico8.sh` | `grep retrogame_joypad` in the SDL db |
| `package/emulators/pico8/pico8-splore-pad.c` | opens the evdev name |
| `package/drivers/rocknix-joypad/` | package, `Config.in`, `0002`, `0003`. Remove only after the new module is the normal build |
| `board/my355/post-build.sh` | requires `rocknix-singleadc-joypad.ko`, deletes a leftover `rocknix-joypad.ko`, chmods `zlyme-joypad-cal` and `S26joypadcal` |
| `package/drivers/Config.in` | sources the old package |

Follow the SDL database once its lines change. They do not hardcode the old name:

```text
package/system/nextui/paks/Tools/Moonlight.pak/launch.sh
package/system/nextui/paks/Tools/Artwork Scraper.pak/launch.sh
package/system/nextui/paks/Tools/ScrapeGoat.pak/launch.sh
package/system/portmaster/portmaster.mk
package/system/vtree/vtree.mk
package/emulators/moonlight/moonlight.conf   (comment only)
```

Comment-only, update with the cutover so the next reader is not sent back to the old driver:

```text
package/system/nextui/apostrophe/include/apostrophe.h
package/system/nextui/paks/Tools/Autocal.pak/LICENSE
```

Present in tree, not part of the my355 boot DTB. Do not treat them as Flip cutover work:

```text
board/my355/linux/dts-overrides/rockchip/rk3568-anbernic-rg-ds.dts
board/my355/linux/dts-overrides/rockchip/rk3566-powkiddy-rk2023.dtsi
```

Kernel patches that exist only for the old module (`input-polldev`, `adc-keys` keycode 316) come off after cutover, when nothing links them. That is not a second general patch-cleanup pass. SARADC, UART1 CTS, and UART1 DMA stay as noted above.

## Open measurements

These need a tracer or a scope. They do not need another stock boot. Stock artifacts already answer the protocol, the GPIO map, and the role of `miyooio`.

- Which IC transmits the UART frame. Needs board photos or a continuity trace from the stick connector. A logic capture will only reconfirm `FF … FE`.
- Whether `uart1m0_ctsn` is electrically tied to the sender. Remove it only on a unit where frames still arrive.
- Per-line IRQ debounce, measured on the tracer.
- Raw min, center, and max for an original pair, from the diagnostic interface, so the default range is measured on Zlyme rather than copied from stock's 85/130/200.
- The same four numbers from a community Switch-style pair, using the protocol above.
