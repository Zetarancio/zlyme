#!/bin/sh
# Apply the gated HDMI policy to this process. A normal boot leaves
# ZLYME_HDMI_720P unset, and zlyme-hdmi then clears the SDL variables.
zlyme_hdmi_apply() {
	_bin=${ZLYME_HDMI_BIN:-/usr/bin/zlyme-hdmi}
	_out=
	[ -x "$_bin" ] || return 0
	_out=$("$_bin" export) || return 0
	[ -n "$_out" ] || return 0
	eval "$_out"
}
