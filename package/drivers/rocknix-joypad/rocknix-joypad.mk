################################################################################
#
# rocknix-joypad
#
# Out-of-tree input driver. The Flip's buttons, d-pad, analog stick (Miyoo
# UART1 protocol, not ADC) and rumble PWM all bind here. Pin from NOTES.md
# section 4; move it when the kernel moves.
################################################################################

ROCKNIX_JOYPAD_VERSION = 3bc3ef644
ROCKNIX_JOYPAD_SITE = $(call github,ROCKNIX,rocknix-joypad,$(ROCKNIX_JOYPAD_VERSION))
ROCKNIX_JOYPAD_LICENSE = GPL-2.0

# Their Makefile: empty DEVICE matches the first ifeq (empty == empty) and
# builds only rocknix-joypad.o. The Flip DTS compatible is
# rocknix-singleadc-joypad. Command-line obj-m wins over the Makefile.
ROCKNIX_JOYPAD_MODULE_MAKE_OPTS = obj-m=rocknix-singleadc-joypad.o

$(eval $(kernel-module))
$(eval $(generic-package))
