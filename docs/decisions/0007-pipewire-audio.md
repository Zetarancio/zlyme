# ADR 0007 — One PipeWire graph owns playback

Status: Accepted

Date: 2026-10-26

## Context

Zlyme needs one mixer for the RK817 codec, HDMI, and Bluetooth headphones. The earlier product graph was ALSA `dmix` plus a `FlipVolume` softvol. A later candidate used one PulseAudio 17 server and BlueALSA for A2DP. That candidate had its own boot script, socket, and sink policy, and it did not survive contact with the read-only root and the BusyBox init split.

Buildroot 2026.08 supplies PipeWire 1.6.6 and WirePlumber 0.5.14. ROCKNIX uses a newer PipeWire pair, but it starts them with systemd units. Zlyme does not.

## Decision

Both the product image and the minimal image run one PipeWire daemon, one WirePlumber, and one `pipewire-pulse`.

ALSA is the hardware backend. The default PCM is the PipeWire plugin. `libpulse` clients use `pipewire-pulse`. PipeWire's BlueZ monitor owns A2DP. `zlyme-audio` selects the sink. `zlyme-jackd` still owns the RK817 playback mux.

`rcS` does not start this graph. `rc.late` starts `S33pipewire` after the first frame, beside InputPlumber, and neither waits for the other.

There is no PulseAudio daemon and no BlueALSA service.

## Consequences

A second audio server, a systemd unit, or a per-application daemon is a new design, not a bug fix.

PipeWire does not change the panel pixel clock. An audio symptom that follows the display clock still has to be measured on this graph.

The rejected PulseAudio and BlueALSA details stay in `docs/research/audio-phase14.md`. The running contract is `docs/ARCHITECTURE.md`.
