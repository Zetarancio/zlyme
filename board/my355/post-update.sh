#!/bin/sh
# OTA hook. Runs from initramfs after the new squashfs is copied onto
# ZLYMEBOOT and before pending is deleted. Intentionally empty so a
# later image can replace this file without changing the updater.
exit 0
