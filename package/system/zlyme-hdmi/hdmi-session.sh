#!/bin/sh
# Apply the gated HDMI policy to this process and to its children.
# eval alone leaves the assignments in this shell. nextui.elf and
# RetroArch are children, so the values have to be exported.
# A failed query clears a previous success. It does not keep it.
zlyme_hdmi_clear() {
	unset ZLYME_HDMI_SDL_MODE ZLYME_HDMI_SDL_INDEX ZLYME_HDMI_SDL_CONNECTOR \
		ZLYME_HDMI_WIDTH ZLYME_HDMI_HEIGHT ZLYME_HDMI_CONNECTOR \
		ZLYME_HDMI_CARD ZLYME_HDMI_VREFRESH ZLYME_HDMI_REFRESH_HZ \
		ZLYME_HDMI_MONITOR ZLYME_HDMI_MODE_INDEX ZLYME_HDMI_CONNECTOR_ID
	ZLYME_HDMI_ACTIVE=0
	export ZLYME_HDMI_ACTIVE
}

zlyme_hdmi_apply() {
	_bin=${ZLYME_HDMI_BIN:-/usr/bin/zlyme-hdmi}
	_out=
	if [ ! -x "$_bin" ]; then
		zlyme_hdmi_clear
		return 0
	fi
	_out=$("$_bin" export) || {
		zlyme_hdmi_clear
		return 0
	}
	if [ -z "$_out" ]; then
		zlyme_hdmi_clear
		return 0
	fi
	eval "$_out" || {
		zlyme_hdmi_clear
		return 0
	}
	if [ "${ZLYME_HDMI_ACTIVE:-0}" = 1 ]; then
		export ZLYME_HDMI_ACTIVE ZLYME_HDMI_CARD ZLYME_HDMI_CONNECTOR \
			ZLYME_HDMI_CONNECTOR_ID ZLYME_HDMI_WIDTH ZLYME_HDMI_HEIGHT \
			ZLYME_HDMI_VREFRESH ZLYME_HDMI_REFRESH_HZ ZLYME_HDMI_MONITOR \
			ZLYME_HDMI_MODE_INDEX ZLYME_HDMI_SDL_CONNECTOR \
			ZLYME_HDMI_SDL_INDEX ZLYME_HDMI_SDL_MODE
	else
		zlyme_hdmi_clear
	fi
}
