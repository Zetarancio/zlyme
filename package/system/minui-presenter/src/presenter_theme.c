#include "presenter_theme.h"

#include <stddef.h>

PresenterTextRole PresenterTheme_TextRole(int has_background_image)
{
    // over a background image, keep text white so it stays readable over
    // arbitrary art; otherwise let the caller apply the theme color
    if (has_background_image)
        return PRESENTER_TEXT_LEGIBILITY;

    return PRESENTER_TEXT_THEMED;
}

int PresenterTheme_UseExplicitBackground(const char *background_color)
{
    // a non-empty background color is an explicit choice; an empty/NULL value
    // means "unset", so the caller uses the theme background instead
    return background_color != NULL && background_color[0] != '\0';
}
