#include <stdio.h>

/* Pointer width and a hard-float add. The dynamic section is the check. */
int main(void)
{
	volatile double left = 0.1;
	volatile double right = 0.2;

	printf("armhf %u %.1f\n", (unsigned)sizeof(void *) * 8, left + right);
	return 0;
}
