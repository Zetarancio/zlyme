#!/bin/sh
# Slot 1 stays at high-speed signaling. Slot 0 keeps its UHS properties.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
dts=$ROOT/board/my355/linux/dts/rockchip/rk3566-miyoo-flip.dts

awk '
	/^&sdmmc0 \{/ { slot = 0 }
	/^&sdmmc1 \{/ { slot = 1 }
	/^};/ && slot != "" { slot = "" }
	slot == 0 && /sd-uhs-sdr104/ { s0 = 1 }
	slot == 1 && /cap-sd-highspeed/ { hs = 1 }
	slot == 1 && /sd-uhs-/ { uhs = 1 }
	slot == 1 && /vqmmc-supply = <&vccio_sd>/ { vq = 1 }
	slot == 1 && /keep-power-in-suspend/ { kp = 1 }
	slot == 1 && /bus-width = <4>/ { bw = 1 }
	END {
		if (!s0 || !hs || uhs || !vq || !kp || !bw) exit 1
	}
' "$dts"

echo "sdmmc1 high-speed ok"
