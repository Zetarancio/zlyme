# InputPlumber — study only (do not package)

Date: 2026-09-14 / 2026-09-15. Zlyme my355 (Miyoo Flip).

## Live Switch Pro (2026-09-15)

Paired `98:B6:D4:58:CD:79`, `js1` / `event5`, `DRIVER=hid-generic`
(`HID_ID=0005:057E:2009`). `ID_INPUT_JOYSTICK=1` but **zero evdev
bytes in 2s**. KEY bitmap is keyboard-ish (`ffff000000000000`), not
`BTN_SOUTH`. `CONFIG_HID_NINTENDO` was off; DualShock already has
`HID_PLAYSTATION`. Nintendo pads stay in vendor report mode until
hid-nintendo sends 0x30. RetroArch udev therefore has nothing to map.
That is why RA “does not work” after a successful BlueZ pair.

**Next rebuild:** `CONFIG_HID_NINTENDO=m` + `NINTENDO_FF` in
`my355.fragment`, plus libretro `Nintendo Switch Pro Controller.cfg`.
Pro will still enumerate as **player 2** (`js0` is Flip). MENU+Start
exit stays `zlyme-pak-hotkey` on js0.

## Recommendation

Do **not** package InputPlumber for this pad. hid-nintendo is the
driver. IP is the later *composite* (one Xbox-like P1 from Flip+BT,
exclusive grab). Stay SDL + eudev until we want that grab. No Rust
daemon in front of NextUI.

## What ROCKNIX #2685 actually is

sydarn [ROCKNIX/distribution#2685](https://github.com/ROCKNIX/distribution/pull/2685)
is Anbernic gpio-keys / ADC plus YAML keyed on the DT **model**. That is
not the Flip. The Flip pad is UART `retrogame_joypad` (ROCKNIX serial
`.ko`, Zlyme patch 0002). Sticks are userspace `miyoo_inputd` on ttyS1
in stock; we use the kernel driver instead. See
`RESEARCH-JOYPAD-DRIVER.md`.

## What an obscure USB/BT pad does on Zlyme today

- eudev creates `/dev/input/event*` / `jsN`.
- NextUI opens every `SDL_JOYDEVICEADDED` (buttons mix, no grab).
- RetroArch is udev + gamecontrollerdb; unknown pads stay unmapped.
- `zlyme-pak-hotkey` is **js0** (built-in). A second pad must not steal that.
- A BT headset is A2DP, not a pad. HID UUID `00001124` is hidp, not A2DP.

## When IP would pay

One composite device, grab, known maps, cleaner BT vs built-in. Cost:
Rust daemon before NextUI first frame, a Flip YAML, RA/hotkey retarget
off `js0`. That is the opposite of Class A boot.

Stay SDL/udev. Revisit if we need exclusive grab or a pile of obscure
pads that gamecontrollerdb will not cover.
