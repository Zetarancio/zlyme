#!/usr/bin/env python3
"""Point Apostrophe my355 builds at the Flip joystick (NextUI JOY_*).

https://github.com/Helaas/Apostrophe treats Flip buttons as keyboard
scancodes. Zlyme's rocknix joypad only emits joystick events.
Handles both the compile-time MY355 exclusion (Moonlight's pin) and
the runtime skip (current ScrapeGoat pin).
"""
from __future__ import annotations

import sys
from pathlib import Path

MY355_CASES = """\
        switch (btn) {
            case 0:  return AP_BTN_B;
            case 1:  return AP_BTN_A;
            case 2:  return AP_BTN_X;
            case 3:  return AP_BTN_Y;
            case 4:  return AP_BTN_L1;
            case 5:  return AP_BTN_R1;
            case 6:  return AP_BTN_L2;
            case 7:  return AP_BTN_R2;
            case 8:  return AP_BTN_SELECT;
            case 9:  return AP_BTN_START;
            case 10: return AP_BTN_MENU;
            case 13: return AP_BTN_UP;
            case 14: return AP_BTN_DOWN;
            case 15: return AP_BTN_LEFT;
            case 16: return AP_BTN_RIGHT;
            default: return AP_BTN_NONE;
        }
"""

MY355_BLOCK = f"""\
    /* Flip (my355): NextUI platform.h JOY_* indices, not TrimUI / keyboard. */
    if (ap_get_platform() == AP_PLATFORM_MY355) {{
{MY355_CASES}    }}
"""


def patch(text: str) -> str:
    if "Flip (my355): NextUI platform.h JOY_*" in text:
        return text

    # Moonlight pin: mapper and JOYBUTTON cases are compiled out on my355.
    text = text.replace(
        "/* Map SDL joystick button to virtual button (raw joystick — used on TrimUI) */\n"
        "#if !defined(PLATFORM_MY355)\n"
        "static ap_button ap__map_joy_button(uint8_t btn) {\n",
        "/* Map SDL joystick button to virtual button (raw joystick — used on TrimUI) */\n"
        "static ap_button ap__map_joy_button(uint8_t btn) {\n",
        1,
    )
    text = text.replace(
        "        default:                 return AP_BTN_NONE;\n"
        "    }\n"
        "}\n"
        "#endif\n\n"
        "/* Map SDL GameController button",
        "        default:                 return AP_BTN_NONE;\n"
        "    }\n"
        "}\n\n"
        "/* Map SDL GameController button",
        1,
    )
    text = text.replace(
        "           Axis events (thumbstick) are allowed through on all platforms. */\n"
        "        #if !defined(PLATFORM_MY355)\n"
        "        case SDL_JOYBUTTONDOWN: {\n",
        "           Axis events (thumbstick) are allowed through on all platforms. */\n"
        "        case SDL_JOYBUTTONDOWN: {\n",
        1,
    )
    text = text.replace(
        "            ap__set_hat_state(ev->jhat.value, now);\n"
        "            break;\n"
        "        }\n"
        "        #endif /* !PLATFORM_MY355 */\n",
        "            ap__set_hat_state(ev->jhat.value, now);\n"
        "            break;\n"
        "        }\n",
        1,
    )
    # Older pin also compiled hat helper out on my355; JOYHATMOTION still calls it.
    text = text.replace(
        "#if !defined(PLATFORM_MY355)\n"
        "static void ap__set_hat_state(uint8_t hat, uint32_t now) {\n",
        "static void ap__set_hat_state(uint8_t hat, uint32_t now) {\n",
        1,
    )
    text = text.replace(
        "    ap__g.hat_held = hat;\n"
        "    ap__g.hat_repeat_time = hat ? (now + ap__g.input_repeat_delay_ms) : 0;\n"
        "}\n"
        "#endif\n\n"
        "static void ap__set_axis_direction_y",
        "    ap__g.hat_held = hat;\n"
        "    ap__g.hat_repeat_time = hat ? (now + ap__g.input_repeat_delay_ms) : 0;\n"
        "}\n\n"
        "static void ap__set_axis_direction_y",
        1,
    )

    # Current Apostrophe: runtime skip of joystick on my355.
    text = text.replace(
        "            if (ap_get_platform() == AP_PLATFORM_MY355) break;\n",
        "",
    )

    if "static ap_button ap__map_joy_button(uint8_t btn) {" not in text:
        raise SystemExit("apostrophe.h: joystick mapper not found")
    if MY355_BLOCK not in text:
        text = text.replace(
            "static ap_button ap__map_joy_button(uint8_t btn) {\n",
            "static ap_button ap__map_joy_button(uint8_t btn) {\n" + MY355_BLOCK,
            1,
        )
    return text


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "apostrophe.h")
    new = patch(path.read_text())
    path.write_text(new)
    print(f"patched {path}")


if __name__ == "__main__":
    main()
