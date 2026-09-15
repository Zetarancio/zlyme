.PHONY: all clean

all: keymon.elf

keymon.elf: keymon.c
	$(CC) -o $@ $< -I../libmsettings -L../libmsettings -lmsettings -lrt

clean:
	rm -f keymon.elf
