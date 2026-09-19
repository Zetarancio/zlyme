# Joypad driver — stock vs ROCKNIX serial `.ko`

Date: 2026-09-14 / 2026-09-15. Hardware that still runs **stock** after a
stick swap is not a power/UART short. Stock and ROCKNIX disagree, so it
is software. Treat “ROCKNIX boots / stock doesn’t” as a slip: the
reported unit is **stock works, ROCKNIX fork does not**.

Do **not** port unpublished BSP `miyooio.c` this pass. Mainline already
has gpio-keys + UART joypad. No `HID_NINTENDO`.

## Searched (2026-09-14)

Paths under `/run/media/ale/SPCC/Cursor/MIYOO-FLIP/Steward-fu-FLIP/`.

- Steward wiki (`docs`, `README.md`): **no `miyooio` page**.
- Online: Steward UART log only prints `[Miyoo]miyooio init`.
- Extra published `linux-5.10.y-…`: **no `miyooio.c`**.
- `Extra/System.map-5.10`: built-in `miyooio_open/read/write/release`
  (char device, not a `.ko` in the rootfs). Extra is gitignored in that
  wiki repo.
- SPI `spi_20241119160817` and `miyoo355_fw_20250527` ship
  **`usr/miyoo/bin/miyoo_inputd`** only.

## What `miyooio` does (from Extra `miyoo_inputd.c`, which we have)

`/dev/miyooio` is **buttons** (and HAT/L2/R2). `miyoo_inputd` `read()`s
**32 ints**, treats each as a RetroPad index, emits uinput keys.

Analog sticks are a **second thread** on `/dev/ttyS1` 9600, frames
`FF YL XL YR XR FE`. The poll thread even calls `uart_set(9600)` on
`miyooio` — leftover from a UART copy; the ABI is still `read()` of
that int array.

## Disassembly

Possible, not needed to *use* it. Uncompress stock `zImage` +
`System.map` → `objdump` of `miyooio_read` would show which GPIOs it
samples. Extra 5.10 tree will not match those symbols (driver was never
published).

## What Zlyme ships

Keep the ROCKNIX serial `.ko` (patch 0002). Later maybe serdev.
Optional A/B: run stock `miyoo_inputd` on mainline against `/dev/miyooio`
if we ever add that char device. Not this pass.

Rumble on this board is **ff-memless** on `retrogame_joypad` (PWM5 in
the DTS), not stock gpio20. `PLAT_setRumble` must talk FF, not a GPIO
stub.
