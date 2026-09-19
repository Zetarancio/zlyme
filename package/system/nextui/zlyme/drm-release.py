#!/usr/bin/python3
# NextUI can leave DRM master in a state where RetroArch/SDL then fail
# with "Error when switching mode". Become master and drop it so the
# pak can set the CRTC.
import fcntl
import os
import sys

DRM_IOCTL_SET_MASTER = 0x641E
DRM_IOCTL_DROP_MASTER = 0x641F

try:
	fd = os.open("/dev/dri/card0", os.O_RDWR)
except OSError:
	sys.exit(0)
try:
	try:
		fcntl.ioctl(fd, DRM_IOCTL_SET_MASTER)
	except OSError:
		pass
	try:
		fcntl.ioctl(fd, DRM_IOCTL_DROP_MASTER)
	except OSError:
		pass
finally:
	os.close(fd)
