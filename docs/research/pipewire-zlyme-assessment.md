# PipeWire on Zlyme

Decision: deferred. Do not replace the PulseAudio server in the Phase 14 stability recovery.

The comparison is ROCKNIX `distribution` branch `next`, read on 2026-10-19. `projects/ROCKNIX/devices/RK3566/options` sets `PIPEWIRE_SUPPORT="yes"`. The audio packages in that tree are PipeWire 1.6.8 and WirePlumber 0.5.15. RK3566 is not in the quantum override. SM6115 and the other listed Qualcomm boards set a 960-frame quantum. SM8250 sets a 1024-frame Pulse minimum. RK3566 keeps PipeWire's own default quantum.

ROCKNIX builds PipeWire with `libpulse` enabled, BlueZ 5 A2DP codecs enabled, and ALSA config symlinks `50-pipewire.conf` and `99-pipewire-default.conf`. It installs systemd units `pipewire.service`, `pipewire.socket`, `pipewire-pulse.service`, and `pipewire-pulse.socket`, plus a system WirePlumber unit. The package depends on systemd. WirePlumber disables BlueZ seat monitoring and the HFP/HSP backend, and it has an auto-connect rule for headset profiles. Those units are not a BusyBox init script.

Zlyme is Buildroot 2026.08 and BusyBox init. One PulseAudio 17 process is the mixer. ALSA's default PCM is the Pulse plugin. BlueALSA owns A2DP, and a Pulse sink attaches to that PCM. Bluetooth headphone audio on that path was accepted. PipeWire's BlueZ monitor would be a second A2DP owner unless BlueALSA is removed. Running PulseAudio and a `pipewire-pulse` socket together would be two servers on the same protocol. Zlyme would have to write its own init, socket directory, and sink policy. It would not copy the systemd units.

What that would not explain. RetroArch's speaker audio improved when the Pulse interrupt buffer went from 4 fragments to 12. PPSSPP 1.19.3 still opens SDL at 44100 Hz with `AudioBufferSize` defaulting to 256 samples, about 5.8 ms, and its resampler target is 1680 samples unless the reported device period is larger. `ExtraAudioBuffering` exists and is false in the stock seed. `FillAudioGaps` and `AudioSyncMode` are not settings in this pin. A different server does not change that client buffer, and it does not change the seeded frameskip. Image size for a PipeWire plus WirePlumber plus codec build was not measured here.

The current defect to chase is the PPSSPP client and the unexplained resets, not a second audio graph.
