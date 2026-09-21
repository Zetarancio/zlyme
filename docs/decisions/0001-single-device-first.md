# ADR 0001 — Support one device now, preserve a device boundary

Status: Accepted

## Context

Zlyme currently runs on the Miyoo Flip (`my355`).

Future handheld support is desirable, but no second target is currently implemented or tested.

Premature generic frameworks would add complexity and untested code. At the same time, scattering Miyoo Flip assumptions through generic packages would make a later port unnecessarily expensive.

## Decision

Miyoo Flip remains the only supported device.

We isolate its hardware implementation under explicit board/runtime boundaries and use device-qualified defconfigs and metadata.

We do not add unused second-device code.

## Consequences

A future port gets a clear place to integrate.

Some current `my355` assumptions must be moved out of global files.

The first future port may still reveal abstractions that cannot be designed correctly today; those should be extracted then.
