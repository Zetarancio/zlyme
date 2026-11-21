#!/bin/sh
# Terminal check for the hosted product build.
# An earlier stage may exit 0 when its compile window closes with no image,
# so the next stage can run. After the last stage, one have_image output
# must be the string true. That output is set only when the OTA and
# zlyme.img are both present.
set -eu

found=0
for value in \
	"${STAGE_A_HAVE_IMAGE:-}" \
	"${STAGE_B_HAVE_IMAGE:-}" \
	"${STAGE_C_HAVE_IMAGE:-}"
do
	if [ "$value" = "true" ]; then
		found=1
	fi
done

if [ "$found" -eq 1 ]; then
	echo "product image present"
	exit 0
fi

echo "no product image: no stage reported have_image=true" >&2
exit 1
