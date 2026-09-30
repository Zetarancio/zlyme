#ifndef PRESENTER_THEME_H
#define PRESENTER_THEME_H

// presenter_theme provides the SDL-free decisions behind minui-presenter's NextUI
// theming. Keeping it display-free means it can be unit tested with the host
// compiler (see test/presenter_theme_test.c); the caller (minui-presenter.c) maps
// the results to actual SDL colors and fonts, choosing the NextUI theme values
// under -DPLATFORM_NEXTUI or the greyscale palette otherwise.

// ListTextRole-style enum for the presenter's foreground text. The color values
// live in the caller; this only captures which treatment applies.
typedef enum
{
    // normal foreground: the themed list text on NextUI, white on MinUI
    PRESENTER_TEXT_THEMED = 0,
    // forced white for legibility when drawn over a background image (both builds)
    PRESENTER_TEXT_LEGIBILITY,
} PresenterTextRole;

// PresenterTheme_TextRole decides how a foreground string (the message and the
// time-left readout) should be colored.
//
// has_background_image: whether a background image is currently being displayed.
//
// Over a background image the text stays white for legibility over arbitrary art;
// otherwise it follows the theme.
PresenterTextRole PresenterTheme_TextRole(int has_background_image);

// PresenterTheme_UseExplicitBackground reports whether an explicit background color
// (from --background-color or a per-item JSON background_color) is set. When it is
// not, the caller falls back to the theme background (COLOR_BACKGROUND on NextUI,
// black on MinUI).
//
// background_color: the item's background color string (may be NULL).
//
// Returns non-zero when background_color is a non-empty string.
int PresenterTheme_UseExplicitBackground(const char *background_color);

#endif // PRESENTER_THEME_H
