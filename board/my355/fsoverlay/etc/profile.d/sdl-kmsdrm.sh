# SDL2 apps (RetroArch, MinUI, later ports) go straight to KMS. Without this
# SDL2 may try a dummy video device and appear to start while drawing nowhere.
export SDL_VIDEODRIVER=kmsdrm

# Root's home on the read-only squashfs cannot hold RetroArch's writeable
# config. /storage is the exFAT partition S15bootpart mounts.
if [ -d /storage/.config ]; then
	export HOME=/storage
	export XDG_CONFIG_HOME=/storage/.config
fi
