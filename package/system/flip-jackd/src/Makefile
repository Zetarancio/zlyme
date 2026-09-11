CFLAGS ?= -O2 -Wall -Wextra
LDLIBS = -lasound

flip-jackd: flip-jackd.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f flip-jackd

.PHONY: clean
