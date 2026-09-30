#!/usr/bin/env bats
#
# Integration tests for manual newline (\n) support in messages.
#
# minui-presenter renders to an SDL window, so these tests cannot assert
# rendered pixels. Instead they run the binary headless (SDL_VIDEODRIVER=dummy)
# with a short timeout and assert that newline input - from both the CLI and a
# JSON file - is accepted and the program exits cleanly on timeout (exit code
# 124, per the documented exit codes) rather than crashing.

setup() {
    BIN="${MINUI_PRESENTER_BIN:-./minui-presenter-macos}"
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"

    # exit code returned when --timeout is reached
    TIMEOUT_EXIT=124

    if [ ! -x "$BIN" ]; then
        skip "binary not found at $BIN (run: PLATFORM=macos make)"
    fi
    if [ ! -f /tmp/FAKESD/.system/res/BPreplayBold-unhinted.otf ]; then
        skip "resources missing (run: PLATFORM=macos make setup-resources)"
    fi

    export SDL_VIDEODRIVER=dummy
    export SDL_AUDIODRIVER=dummy
}

@test "renders a message containing a real newline" {
    run "$BIN" --message $'first line\nsecond line' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "interprets a literal backslash-n as a newline" {
    run "$BIN" --message 'first line\nsecond line' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "interprets literal backslash-t and escaped backslash" {
    run "$BIN" --message 'a\tb\\nc' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders consecutive newlines as a blank line" {
    run "$BIN" --message $'first\n\nthird' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders newlines with automatic wrapping disabled" {
    run "$BIN" --disable-auto-wrap \
        --message $'a very long line that would normally wrap across the screen\nsecond' \
        --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders a newline supplied via a JSON file" {
    run "$BIN" --file "${FIXTURES}/newline.json" --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "still renders a plain message without newlines" {
    run "$BIN" --message 'a plain message without any newlines' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}
