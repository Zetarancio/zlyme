CFLAGS ?= -O2 -Wall -Wextra
LDLIBS = -lasound

zlyme-jackd: zlyme-jackd.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f zlyme-jackd

.PHONY: clean
