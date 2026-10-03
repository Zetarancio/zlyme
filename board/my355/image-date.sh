# Canonical Zlyme image date. build.sh sets ZLYME_IMAGE_DATE once.
# Board scripts only accept that value. They do not read the clock.

zlyme_require_image_date() {
	local got round
	got="${ZLYME_IMAGE_DATE:-}"
	round=$(date -u -d "${got}" +%Y-%m-%d 2>/dev/null || true)
	if [ -z "${got}" ] || [ "${round}" != "${got}" ]; then
		echo "ZLYME_IMAGE_DATE must be YYYY-MM-DD" >&2
		return 1
	fi
	return 0
}

zlyme_image_stamp() {
	zlyme_require_image_date
	printf '%s\n' "${ZLYME_IMAGE_DATE//-/}"
}
