# minui presenter

This is a minui presentation app. It allows displaying messages on the screen with background colors and images.

## Requirements

- A minui union toolchain
- Docker (this folder is assumed to be the contents of the toolchain workspace directory)
- `make`

## Building

- todo: this is built inside-out. Ideally you can clone this into the MinUI workspace directory and build from there under each toolchain, but instead it gets cloned _into_ a toolchain workspace directory and built from there.

The build platform is selected with `PLATFORM`, and the binary is named `minui-presenter-$(PLATFORM)`. For example, `PLATFORM=tg5040 make` produces `minui-presenter-tg5040`.

## Supported platforms

Binaries are built against one of two firmwares. Most devices build against MinUI (`shauninman/MinUI`). NextUI-specific binaries build against a NextUI toolchain and are suffixed with `-nextui`.

- `tg5040` and `my355` run both firmwares, so they have a MinUI build (`minui-presenter-tg5040`, `minui-presenter-my355`) and a NextUI build (`minui-presenter-tg5040-nextui`, `minui-presenter-my355-nextui`).
- `tg5050` and `h700` are NextUI-only and build as `minui-presenter-tg5050-nextui` and `minui-presenter-h700-nextui`.

The `-nextui` binaries honor the device's NextUI theme, re-coloring the background and message text and following the theme font instead of the fixed MinUI greyscale palette.

To build a NextUI variant, use its platform id inside the matching toolchain, for example `PLATFORM=tg5040-nextui make`. See [docs/nextui.md](docs/nextui.md) for the platform/toolchain matrix, the theming details, and how the NextUI builds are wired. For the native macOS build used by the test suite, see [docs/macos.md](docs/macos.md).

## Usage

```shell
minui-presenter --message "The quick brown fox jumps over the lazy dog"
```

### Options

#### Message Display

- `--background-color <hex-color>`: Default background color to use (default: `#000000`; on `-nextui` builds, the NextUI theme background when unset).
- `--background-image <path>`: Default background image to use (default: empty string).
- `--message <text>`: Display a single message (default: empty string)
  - The following backslash escapes are interpreted: `\n` (newline), `\t` (tab), and `\\` (literal backslash). Use `\n` to insert a manual line break, e.g. `--message "line1\nline2"`.
- `--message-alignment <alignment>`: Set message alignment (default: `middle`)
  - Valid values: `top`, `middle`, `bottom`
- `--file <path>`: Path to JSON file containing messages (default: empty string)
- `--item-key <key>`: Key in JSON file containing items array (default: `items`)
- `--quit-after-last-item`: Quit the program after navigating past the last element (default: `false`)
- `--show-pill`: Whether to show the pill by default or not (default: `false`)

> [!IMPORTANT]
> Either the `--message` or `--file` argument must be specified

### Font Configuration

- `--font-default <path>`: Path to custom font file (default: built-in font; on `-nextui` builds, the NextUI theme font when unset)
- `--font-size-default <size>`: Font size for messages (default: `FONT_LARGE`)

### Button Configuration

#### Action Button

- `--action-button <button>`: Assign action button (default: none)
- `--action-text <text>`: Text for action button (default: `ACTION`)
- `--action-show`: Show action button (default: `false`)

#### Confirm Button

- `--confirm-button <button>`: Assign confirm button (default: `A`)
- `--confirm-text <text>`: Text for confirm button (default: `SELECT`)
- `--confirm-show`: Show confirm button (default: `false`)

#### Cancel Button

- `--cancel-button <button>`: Assign cancel button (default: `B`)
- `--cancel-text <text>`: Text for cancel button (default: `BACK`)
- `--cancel-show`: Show cancel button (default: `false`)

#### Inaction Button

- `--inaction-button <button>`: Assign inaction button (default: none)
- `--inaction-text <text>`: Text for inaction button (default: `OTHER`)
- `--inaction-show`: Show inaction button (default: `false`)

### Display Options

- `--disable-auto-sleep`: Disables the auto-sleep functionality (default: `false`)
- `--disable-auto-wrap`: Disables automatic word wrapping so lines break only at manual newlines (default: `false`). Lines that are wider than the screen are not wrapped and may extend past the screen edge.
- `--show-hardware-group`: Show hardware information group (default: `false`)
- `--show-time-left`: Show countdown timer (default: `false`)
- `--timeout <seconds>`: Set timeout in seconds (default: `0`, no timeout)

When setting the `--timeout` flag, `minui-presenter` has the following behavior:

- `value < 0`: Will not respond to button presses. This is useful for backgrounding the process and using `killall` to terminate it once another foreground process completes. Sleep will be disabled.
- `value == 0`: Will continue to execute until any of the configured buttons are pressed. Useful for confirmation screens or image galleries. Sleep will be disabled.
- `value > 0`: Will continue to execute until any of the configured buttons are pressed _or_ the configured timeout is reached. Useful for confirmation screens that should only be shown for a maximum amount of time. Sleep is enabled.

### Button Values

> [!NOTE]
> Each hardware button can only be assigned once.

Valid button assignments are:

- `A`: A button
- `B`: B button
- `X`: X button
- `Y`: Y button

When an assigned button is pressed, minui-presenter will exit with the appropriate exit code. Minui-presenter will ignore button presses for the assigned `A`/`X`/`Y` buttons if they are not displayed via the appropriate `show` flag (though will always respect the assigned `B` button).

## Signals

This process handles the following signals:

- `SIGINT`: Exits with Keyboard interrupt (`130`)
- `SIGTERM`: Exits gracefully (`143`)
- `SIGUSR1`: Advances the item state by one or goes to first item if at end of list. Respects the `--quit-after-last-item` flag.

## Exit Codes

- `0`: Success
- `1`: Error
- `2`: Cancel button pressed
- `4`: Action button pressed
- `5`: Inaction button pressed
- `6`: Start button pressed
- `124`: Timeout reached
- `130`: Keyboard interrupt (Ctrl+C)
- `143`: Graceful exit (`SIGTERM`)

## JSON File Format

When using `--file`, the JSON should follow this format:

```json
{
  "items": [
    {
      "text": "Message text",
      "background_image": "path/to/image.png",
      "background_color": "#000000",
      "show_pill": false,
      "alignment": "middle"
    }
  ],
  "selected": 0
}
```

An initial index can be specified via the `selected` key (default: `0`).

When multiple items are displayed, the list can be scrolled using the `LEFT` AND `RIGHT` buttons.

### Item Properties

- `text`: The message to display. Text is automatically word-wrapped to fit the screen; a `\n` in the value forces a manual line break (JSON strings use standard JSON escaping). Automatic wrapping can be disabled with `--disable-auto-wrap`.
- `background_image`: (default: null) Path to background image. Will be stretched to fill screen by aspect ratio. The image will be displayed as soon as it exists.
- `background_color`: (default: `#000000`, or the NextUI theme background on `-nextui` builds) Hex color code for background
- `show_pill`: (default: `false`) Whether to show a pill around the text
- `alignment`: (default: `middle`) Message alignment ("top", "middle", "bottom")

## Screenshots

| Name                                           | Image                                                                 |
|------------------------------------------------|-----------------------------------------------------------------------|
| Fullscreen image with Actions                  | <img src="screenshots/fullscreen-image-with-actions.png" width=240 /> |
| Background color and scaled image with Actions | <img src="screenshots/background-color-and-image-with-actions-scaled.png" width=240 /> |
| Message with Timeout                           | <img src="screenshots/message-with-timeout.png" width=240 />          |
