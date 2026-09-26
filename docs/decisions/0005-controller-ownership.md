# ADR 0005 — One virtual controller per player, with a narrow ownership command

Status: Accepted

## Context

Phase 4B proved InputPlumber can grab the Miyoo Flip pad and expose one `xb360` target. It left management off, so NextUI still used the physical pad.

The application path needs a different owner than the hardware-maintenance path. Settings → System → Joysticks must read the physical pad. Turning management off globally would also drop external controllers. Suspending a composite does not release its evdev grab. The v0.81.0 `CreateCompositeDevice` method does not create a device.

Player order is not event-node order. With no external controller the built-in pad is P1. When any external controller is connected, externals come first and the built-in pad is last.

## Decision

Keep three boundaries:

1. `miyoo-flip-gamepad` reports the physical controls. Digital L2/R2 stay `BTN_TL2` / `BTN_TR2`.
2. InputPlumber owns grabs, composites, and the virtual `xb360` targets. One physical player controller is one composite. A small upstream patch adds `RescanDevices`, which reruns discovery without changing `ManageAllDevices`.
3. `zlyme-input` is the only Zlyme command that knows the InputPlumber bus. It enables management after the first frame, moves the built-in composite to the end of `GamepadOrder`, and can release or reclaim that composite alone.

NextUI's normal path uses SDL GameController on the virtual target and drops its physical handle once that target is open. Settings → Joysticks calls `zlyme-input release` before using the physical pad and `zlyme-input reclaim` after it has closed that handle. `nextui-session` reclaims before each frontend start so a crash in that screen does not leave the pad unmanaged.

HDMI, `/dev/input/eventN`, and `/dev/input/jsN` are not priority inputs.

## Consequences

Ordinary applications do not name `org.shadowblip.InputPlumber` or the Flip evdev device.

The first frame still happens before management starts. If InputPlumber is absent, `zlyme-input reclaim` returns without blocking boot.

External controllers are independent composites from a generic joystick rule. They are not physically validated on this unit.

Phase 4D still retargets emulators and other applications.
