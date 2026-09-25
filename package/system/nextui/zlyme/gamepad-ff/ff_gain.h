#ifndef ZLYME_FF_GAIN_H
#define ZLYME_FF_GAIN_H

/* 0 and fills *pct. Nonzero: text is not a single gain=0..100. */
int ff_parse_gain(const char *text, int *pct);
/* 0..100 -> 0x0000..0xffff. Out of range returns -1. */
int ff_gain_value(int pct);
/* One motor: strong if nonzero, else weak. */
unsigned ff_motor_level(unsigned strong, unsigned weak);

#endif
