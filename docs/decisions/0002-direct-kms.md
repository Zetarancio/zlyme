# ADR 0002 — Direct DRM/KMS is the normal graphics path

Status: Accepted

## Context

Zlyme is a fixed-purpose handheld gaming OS, not a desktop distribution.

Most frontend/emulator software can use SDL KMSDRM or EGL/GBM directly.

## Decision

Normal Zlyme operation does not run a persistent X11 server or Wayland compositor.

Applications that require a window system may launch a temporary compatibility stack for their own lifetime.

## Consequences

The normal path remains small and low-overhead.

Software without direct-KMS support needs an explicit compatibility runtime.

Application exit must correctly release display/seat resources so NextUI can recover.
