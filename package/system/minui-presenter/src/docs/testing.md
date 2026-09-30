# Testing

Integration tests are written with [bats](https://github.com/bats-core/bats-core) and live in
the `test/` directory. There are two kinds:

- `test/newline.bats` builds on the native macOS build and exercises the binary headlessly.
- `test/makefile.bats` asserts the per-platform Makefile build wiring (upstream repo, version,
  workspace, `-DPLATFORM_NEXTUI`, device id, sources, and GLES libs) for the NextUI variants.
  It introspects the Makefile with `make print-<VAR> PLATFORM=<p>`, so it needs neither a
  toolchain nor the macOS binary and runs on any host with `make`. See [nextui.md](nextui.md).

## Prerequisites

```bash
brew install bats-core
```

You also need the macOS build prerequisites described in [macos.md](macos.md).

## Running

```bash
# Build the binary and stage the MinUI resources
PLATFORM=macos make
PLATFORM=macos make setup-resources

# Run the test suite
PLATFORM=macos make test
```

`make test` runs `bats test/`.

## How the tests work

`minui-presenter` renders to an SDL window, so the tests cannot assert rendered pixels. Instead
they run the binary with `SDL_VIDEODRIVER=dummy` (no window is opened) and a short `--timeout`,
then assert that the process exits cleanly on timeout (exit code `124`) rather than crashing.
This provides a regression guard that message input - including manual newlines from the command
line and from JSON files - is parsed and rendered without error.

The tests skip automatically if the binary or the MinUI resources are missing.
