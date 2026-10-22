# PulseAudio on Phase 14

Status, 2026-10-20: both images use PipeWire. The paragraphs below that describe one PulseAudio 17 server are the earlier candidate, not the current graph.

2026-10-23, installed `74597688`, automatic output, saved volume 85: Bluetooth disconnect returned the speaker and Bluetooth reconnect returned A2DP. HDMI unplug left the speaker silent and left the external-audio mark visible. NextUI logged a restart after the HDMI change. The kernel logged ELD version 0. There is no `wpctl` or `pw-metadata` snapshot of that unplug, and no evidence that PipeWire exited. Linux 7.2 `drivers/gpu/drm/drm_sysfs.c` emits `HOTPLUG=1` on the primary card from both `drm_sysfs_hotplug_event` and `drm_sysfs_connector_hotplug_event`. DesignWare HDMI calls `drm_helper_hpd_irq_event`, which uses the single-connector variant. The image's udev rule matched `card*-HDMI-A-*`, so `zlyme-audio hdmi-event` did not run and the earlier connector-status check never saw the unplug. The rule now matches a `change` with `HOTPLUG=1` on a `drm_minor` named `card0` or `card1`. eudev 3.2.14 waits for that program and kills that pid on timeout. The ELD recheck is started with `start-stop-daemon -b`, which `setsid`s and double-forks before the handler returns. Uninstalled `zlyme-my355-20261022-0b35a90e9388.tar` (source `0b35a90e9388bb2aea04a4744118323a48b68f6a`) contains that rule. It has not been installed and has not been heard. Stream migration after an HDMI unplug has not been verified on a Flip.

Phase 13 (`8b4218aa`, published as `zlyme44.3`) played through ALSA. `asound.conf` made `default` a `dmix` plus one `FlipVolume` softvol. BlueALSA was the Bluetooth playback device. Programs that opened `default` shared the RK817 PCM.

Phase 14's earlier candidate played through one PulseAudio 17 server. The current graph does not. The server opens `hw:rk817ext,0`. `default` is the Pulse ALSA plugin, so an ordinary ALSA client, including SDL with `SDL_AUDIODRIVER=alsa` and PICO-8, reaches that server. Native `libpulse` clients use the same socket. `flipsink_*` remains for a program that opens that name. Nothing in the shipped launchers does. The Music Player sets `SDL_AUDIODRIVER=alsa`, which follows `default`.

`/proc/asound/card1/id` is `rk817ext`. The kernel short name `rk817_ext` is the headphone input name (`rk817_ext Headphones`) and is not an ALSA card id.

`enable-remixing` defaults to yes. PulseAudio 17 `daemon.conf` says setting it to no has no known valid use case and is deprecated. `enable-remixing=no` sets `disable_remixing`, and `resampler.c` then copies a channel only when the position names match. A mono stream is `mono`. A stereo sink is `front-left` and `front-right`. Nothing matches, so both speakers stay at zero. PICO-8 Splore opens that mono stream through the ALSA plugin. The override is not set.

BlueALSA remains the A2DP owner. Its own integration note says the Pulse `module-alsa-sink` bridge is experimental and that a Pulse server should use `module-bluez5-discover` instead: [PulseAudio integration](https://github.com/Arkq/bluez-alsa/wiki/PulseAudio-integration). Pulse's Bluetooth page is [Software/PulseAudio/Documentation/User/Bluetooth](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Bluetooth/). The image contains `module-bluez5-discover.so`. It is not loaded. Loading it while BlueALSA owns the A2DP profile would register two owners. That switch needs a hardware session that can stop one owner, try the other, and put BlueALSA back. It has not been run. BlueALSA stays.

`zlyme-btsink` creates the next sink and moves the default before it unloads the previous optional sink. A failed headset load leaves HDMI in place.

The codec retry stays in the background for thirty seconds. `udev` on `f48b5bf` started about a second before Pulse, and the five-second window expired while `hw:rk817ext,0` still could not be opened. The retry was not removed. Routine Pulse logs are notice. `ZLYME_PULSE_LOG=info` is the one-boot diagnostic.

PPSSPP underruns were reported with sound still audible. The codec fragment size was not changed. There is no new measurement of those underruns on this pass.
