# NextUI builds

Some devices run NextUI, a fork of MinUI, instead of (or in addition to) MinUI. NextUI ships a different SDK, so those devices need a binary built against a NextUI toolchain. These NextUI-specific binaries carry a `-nextui` suffix in their platform id and artifact name.

## Platform matrix

| Platform id     | Firmware | Upstream repo      | Version / ref (Makefile var)            | Workspace dir | Toolchain image                        |
|-----------------|----------|--------------------|-----------------------------------------|---------------|----------------------------------------|
| `tg5040-nextui` | NextUI   | `loveRetro/NextUI` | `v6.14.0` (`NEXTUI_VERSION`)            | `tg5040`      | `savant/minui-toolchain:tg5040-nextui` |
| `my355-nextui`  | NextUI   | `loveRetro/NextUI` | `my355-latest` (`MY355_NEXTUI_VERSION`) | `my355`       | `savant/minui-toolchain:my355-nextui`  |
| `tg5050-nextui` | NextUI   | `loveRetro/NextUI` | `v6.14.0` (`NEXTUI_VERSION`)            | `tg5050`      | `savant/minui-toolchain:tg5050-nextui` |
| `h700-nextui`   | NextUI   | `pvaibhav/NextUI`  | `h700-rc9` (`H700_VERSION`)             | `h700`        | `savant/minui-toolchain:h700-nextui`   |

`tg5040` and `my355` also have MinUI builds (`minui-presenter-tg5040`, `minui-presenter-my355`) since those devices run both firmwares. `tg5050` and `h700` are NextUI-only.

The `my355` workspace only exists on the `my355-latest` branch of `loveRetro/NextUI` (no tagged release contains it), so it uses its own version variable.

## How the build is wired

The Makefile keeps the build platform id (`PLATFORM`) separate from the upstream workspace directory and the on-device id:

- `WORKSPACE` is the upstream workspace directory name and the runtime device id. It equals `PLATFORM` for every platform except the `-nextui` variants, where it is the bare device (for example `PLATFORM=tg5040-nextui` builds `WORKSPACE=tg5040`).
- `IS_NEXTUI` is set for NextUI platforms. It gates the `/opt/nextui` include and lib paths, the `-DPLATFORM_NEXTUI` define, the extra `config.c` source, and the GLES link flags.

`-DPLATFORM` is compiled into the on-device `SYSTEM_PATH` and `USERDATA_PATH` (`.system/<PLATFORM>` and `.userdata/<PLATFORM>`), so it is driven by `WORKSPACE`. A `tg5040-nextui` binary therefore reports `tg5040` at runtime and resolves the same on-card paths as the device firmware.

The source-level NextUI differences live in `minui-presenter.c`, gated by `-DPLATFORM_NEXTUI`:

- `PLAT_isOnline` is mapped to `PWR_isOnline`, which NextUI's SDK uses for online detection.
- `FONT_PATH` points at the bundled `BPreplayBold-unhinted.otf` (the fallback when the theme font is unavailable).
- the UI is re-colored and re-fonted from the user's NextUI theme (see [Theming](#theming) below).

### GLES and audio libraries

NextUI toolchains install `libmsettings` and the GLES stack under `/opt/nextui`. Every NextUI target links `libsamplerate`, which `api.c` uses to resample audio. The linked libraries differ per device (`NEXTUI_GL_LIBS`):

- `tg5040-nextui` and `h700-nextui`: `-lGLESv2 -lsamplerate`
- `tg5050-nextui` and `my355-nextui`: `-lGLESv2 -lmali -lsamplerate` (their `libGLESv2` is a stub backed by a standalone mali blob that must be linked explicitly)

## Theming

NextUI lets the user pick theme colors and a font (stored in `minuisettings.txt`). The `-nextui` binaries honor that theme, so a `minui-presenter` screen matches the rest of the NextUI menu instead of the fixed greyscale MinUI palette. MinUI and macOS builds are unaffected: every theme reference is confined to `#ifdef PLATFORM_NEXTUI` helpers in `minui-presenter.c`, so those builds still use the greyscale palette and the bundled font and compile unchanged.

Nothing new has to be initialized. The existing `GFX_init(MODE_MAIN)` call already runs the NextUI SDK's `CFG_init`, which reads the theme and populates the `THEME_COLOR*` globals and the themed font. The app just references those when drawing. The presenter's small UI maps to NextUI's color slots (`config.h`) as follows:

| Theme slot (default)              | Where it is used                                                          |
|-----------------------------------|---------------------------------------------------------------------------|
| `COLOR_LIST_TEXT` (white)         | the message text and the `--show-time-left` readout                       |
| `COLOR_BACKGROUND` (black)        | the default background fill, when no per-item background color is set      |
| `COLOR_HINT` (white)              | hardware/button hints (already themed by the SDK's `GFX_blitButton*`)     |

Over a background image the text stays white for legibility over arbitrary art (both builds), and the optional message pill keeps its black backdrop; the theme only applies to text drawn without a background image. The background falls back to `COLOR_BACKGROUND` only when no `background_color`/`background_image` is set; an explicit `--background-color`, a JSON `background_color`, or a `background_image` still overrides it. Fonts follow the theme when no `--font-default` override is given: `open_fonts` reuses the SDK's `font.large`/`font.small` globals, which `GFX_init` loaded from the themed font (this uses the SDK font accessors that exist on every NextUI toolchain, rather than a newer helper some branches lack). A `--font-default` path still opens a custom font at the configured size on both builds, so `--font-size-default` applies on NextUI only alongside `--font-default`. Under the default theme the result looks the same as the MinUI greyscale; the theme only diverges once the user customizes it.

The SDL-free theming decisions (explicit-vs-theme background, legibility-vs-themed text) are factored into `presenter_theme.c` and unit tested by `test/presenter_theme_test.c` (run via `make test`). `test/makefile.bats` asserts `presenter_theme.c` is compiled into every platform.

## Building

Build a NextUI variant with its platform id inside the matching toolchain:

```bash
PLATFORM=tg5040-nextui make setup
PLATFORM=tg5040-nextui make
```

This produces `minui-presenter-tg5040-nextui`.

## Testing the wiring

`test/makefile.bats` asserts the per-platform Makefile wiring (upstream repo, version, workspace, `-DPLATFORM_NEXTUI`, device id, sources, GLES libs, and that `presenter_theme.c` is compiled everywhere) by introspecting the Makefile with `make print-<VAR> PLATFORM=<p>`. It needs neither a toolchain nor a cloned upstream tree:

```bash
bats test/makefile.bats
```

`make test` runs the SDL-free unit tests (`test/presenter_theme_test.c`, host-compiled, no toolchain or resources needed) and then the bats suites (`makefile.bats`, `newline.bats`, `theming.bats`). The binary-backed bats tests exercise the macOS build, so they need a prior `PLATFORM=macos make` and `PLATFORM=macos make setup-resources`; they cannot assert NextUI theme colors, which only apply in the `-nextui` builds.

The CI matrix builds every NextUI binary in its `savant/minui-toolchain:<device>-nextui` container, which is the integration test for the full compile and link (including the theming code paths).

## Keeping the pins current

The NextUI pins (`NEXTUI_VERSION`, `MY355_NEXTUI_VERSION`, `H700_VERSION`) are documented alongside the MinUI pin in [upstream-pins.md](upstream-pins.md), which covers why a stale pin still builds but fails on device, how `scripts/check-upstream-pins.sh` reports drift, and how to bump one.
