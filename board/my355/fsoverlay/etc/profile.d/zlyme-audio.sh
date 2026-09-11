# Restore the saved audio sink for interactive shells.
#
# /etc/asound.conf reads ZLYME_SINK when a client opens the default PCM, and an
# environment variable cannot be set by the process that recorded it, so the choice
# has to be re-exported per session. zlyme-audio writes the file; this reads it.
#
# Unset is fine: asound.conf defaults to the codec, so a missing file or an
# unmounted card costs nothing.
#
# This covers logins. Anything started outside a login shell -- the frontend, and
# whatever it launches -- has to export it itself, which is why zlyme-audio has an
# `export` subcommand.

if [ -r /etc/zlyme.conf ]; then
	. /etc/zlyme.conf
	[ -r "${ZLYME_CFG}/audio.conf" ] && . "${ZLYME_CFG}/audio.conf"
	[ -n "${ZLYME_SINK}" ] && export ZLYME_SINK
fi
