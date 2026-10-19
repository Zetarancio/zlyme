# Clients inherit one runtime directory. audio.conf is data, not shell.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/zlyme/pipewire}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-/run/zlyme/pipewire}"
