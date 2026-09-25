#ifndef ZLYME_FF_GAIN_H
#define ZLYME_FF_GAIN_H

/* Displayed product default. Missing and invalid files use this at runtime. */
#define FF_DEFAULT_GAIN_PERCENT 30

/* 0 and fills *pct with the parsed value, or FF_DEFAULT_GAIN_PERCENT when
 * text is missing or not a single gain=0..100. Nonzero means invalid text.
 */
int ff_parse_gain(const char *text, int *pct);
/* One decimal token, 0..100, with nothing after it. */
int ff_parse_percent_token(const char *text, int *pct);
/* Displayed 0..100 -> effective percent. 0 stays 0; 10 maps to 15; 100 stays 100. */
int ff_effective_gain_percent(int user);
/* Displayed 0..100 -> FF_GAIN. Out of range returns -1. */
int ff_gain_value(int pct);
/* One motor: strong if nonzero, else weak. */
unsigned ff_motor_level(unsigned strong, unsigned weak);

#endif
