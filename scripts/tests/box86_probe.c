/*
 * SPDX-License-Identifier: MIT
 *
 * Minimal dynamically linked i386 execution probe for Box86. It uses
 * libc deliberately: a static ELF would not prove Box86's wrapped
 * ARMHF runtime path.
 */
#include <stdint.h>
#include <stdio.h>

int main(void)
{
	volatile uint32_t a = 0x13579bdfU;
	volatile uint32_t b = 0x2468ace0U;
	uint32_t value = (a ^ b) + 0x10203040U;

	printf("box86-x86 %zu %08x\n", sizeof(void *), value);
	return value == 0x475f677fU ? 0 : 1;
}
