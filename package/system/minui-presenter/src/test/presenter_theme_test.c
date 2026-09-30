// Unit tests for the SDL-free presenter theme decisions. These have no SDL/display
// dependencies, so they run headless with the host compiler via `make test`. The
// caller (minui-presenter.c) maps the results to an actual SDL_Color / font (NextUI
// theme values or the greyscale palette and bundled font).

#include "presenter_theme.h"

#include <stdio.h>

static int checks = 0;
static int failures = 0;

#define CHECK_EQ(actual, expected, msg)                                         \
    do                                                                          \
    {                                                                           \
        checks++;                                                               \
        int _a = (actual);                                                      \
        int _e = (expected);                                                    \
        if (_a != _e)                                                           \
        {                                                                       \
            failures++;                                                         \
            fprintf(stderr, "FAIL: %s (expected %d, got %d)\n", (msg), _e, _a); \
        }                                                                       \
    } while (0)

// with no background image, foreground text follows the theme
static void test_text_role_themed(void)
{
    CHECK_EQ(PresenterTheme_TextRole(0), PRESENTER_TEXT_THEMED, "no bg image -> themed");
}

// over a background image, foreground text stays white for legibility
static void test_text_role_legibility(void)
{
    CHECK_EQ(PresenterTheme_TextRole(1), PRESENTER_TEXT_LEGIBILITY, "bg image -> legibility");
}

// a NULL or empty background color is "unset": fall back to the theme background
static void test_background_unset(void)
{
    CHECK_EQ(PresenterTheme_UseExplicitBackground(NULL), 0, "NULL -> not explicit");
    CHECK_EQ(PresenterTheme_UseExplicitBackground(""), 0, "empty -> not explicit");
}

// a non-empty background color is an explicit choice
static void test_background_explicit(void)
{
    CHECK_EQ(PresenterTheme_UseExplicitBackground("#ff0000"), 1, "#ff0000 -> explicit");
    CHECK_EQ(PresenterTheme_UseExplicitBackground("#000000"), 1, "#000000 -> explicit");
}

int main(void)
{
    test_text_role_themed();
    test_text_role_legibility();
    test_background_unset();
    test_background_explicit();

    if (failures == 0)
    {
        printf("ok - all %d checks passed\n", checks);
        return 0;
    }

    fprintf(stderr, "not ok - %d/%d checks failed\n", failures, checks);
    return 1;
}
