#!/usr/bin/env bats
#
# Integration tests for the theming refactor (issue 67).
#
# minui-presenter renders to an SDL window, so these tests cannot assert rendered
# pixels or theme colors (the NextUI theme only applies in the -nextui builds, which
# are compiled by the CI matrix). Instead they run the macOS binary headless
# (SDL_VIDEODRIVER=dummy) with a short timeout and assert that the refactored
# background-resolution and default-font paths still accept their input and exit
# cleanly on timeout (exit code 124) rather than crashing.

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

@test "renders with no background color (theme/default fallback)" {
    run "$BIN" --message 'no background color set' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders with an explicit --background-color" {
    run "$BIN" --message 'explicit background color' --background-color '#123456' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders per-item background_color from a JSON file" {
    run "$BIN" --file "${FIXTURES}/background-color.json" --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders with the default font (no --font-default)" {
    run "$BIN" --message 'default font' --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders with an explicit --font-default override" {
    run "$BIN" --message 'custom font' \
        --font-default /tmp/FAKESD/.system/res/BPreplayBold-unhinted.otf \
        --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}

@test "renders a message over a background image with legibility text" {
    run "$BIN" --message 'text over an image' \
        --background-image /tmp/FAKESD/.system/res/assets@2x.png \
        --timeout 1
    [ "$status" -eq "$TIMEOUT_EXIT" ]
}
