# Weston runtime choice

Phase 1 needs a temporary Wayland compositor for clients that cannot use KMSDRM. It is not a boot service and it is not the normal NextUI or RetroArch path.

## What PortMaster uses

Current PortMaster ports that need a window system mount **Westonpack** and call its wrapper. The published contract (binarycounter/Westonpack wiki, still the examples ports copy) is:

- runtime file `weston_pkg_0.2.squashfs` (wiki text asks for Westonpack 0.2.x inside that name);
- downloaded by `harbourmaster runtime_check` into `PortMaster/libs/` when missing;
- mounted at `/tmp/weston`;
- launched as `$weston_dir/westonwrap.sh <gl> ... <client>`;
- cleaned with `westonwrap.sh cleanup`, then unmounted.

Modes described there include `headless noop kiosk crusty_x11egl` (X11/EGL via the crusty wrapper) and `drm gl kiosk system` (Xlib). The squashfs is expected to contain Weston, Xwayland, and GL compatibility wrappers. Input helpers such as gptokeyb are separate PortMaster pieces, not part of this choice. Audio in the Godot example is ALSA.

That squashfs is a packed third-party runtime. Zlyme does not bake it into the image: the license mix inside the blob was not verified for redistribution, and PortMaster already downloads a versioned copy when a port asks for it. Ports keep calling `westonwrap.sh` themselves. Zlyme does not force every PortMaster launch through Weston.

## What the OS ships for the tracer

Buildroot **Weston 14.0.2** (MIT, `COPYING`), DRM backend, kiosk shell, simple clients (`weston-simple-egl` / `weston-simple-shm`). No Xwayland, no Xorg, no desktop shell, no PipeWire, no boot unit.

`zlyme-weston-run` owns one temporary compositor: drop DRM master with the existing `zlyme-drm-release`, start Weston with libseat's builtin backend (`LIBSEAT_BACKEND=builtin`), run the client, then stop Weston on any exit. There is no `seatd` daemon and no `S70seatd` service. NextUI's session already calls `zlyme-drm-release` before a pak and starts `nextui.elf` again after it.

Rejected for the tracer:

- shipping `weston_pkg_0.2.squashfs` in the image (redistribution and a moving packed blob);
- a permanent Weston service;
- wrapping RetroArch or other KMSDRM apps.

Xwayland and a Westonpack-backed port stay later in this phase, after the native client cycle is proven. Wine's existing prefix/`kernel32.dll` failure is a PE/runtime problem and is not treated as a display bug.
