# ADR 0008 — libmali by default, Panfrost GLES separate from PanVK

Status: Accepted

Date: 2026-10-26

## Context

The Miyoo Flip GPU can be driven by the vendor Mali stack or by Mesa Panfrost. The two kernel drivers cannot own the GPU at the same time. The product image also builds Mesa's PanVK driver. On Mali-G52, current Mesa treats that Vulkan driver as incompatible unless the process asks for it explicitly.

Direct DRM/KMS remains the normal graphics path (`docs/decisions/0002-direct-kms.md`). A GPU change does not add a compositor.

## Decision

Settings → System → Advanced → GPU offers `mali_kbase` and `panfrost`. The default is `mali_kbase`. The choice is `/storage/.config/zlyme/gpu`, and it takes effect on the next boot. `S15gpudriver` loads one kernel module and, for libmali, bind-mounts that stack's EGL, GLES, and GBM libraries over the shared sonames.

`panvk` is not a Settings choice. `zlyme-gpu-env.sh` exports PanVK's Vulkan ICD and `PAN_I_WANT_A_BROKEN_VULKAN_DRIVER` only when the saved value is exactly `panvk`. The `panfrost` value selects Panfrost OpenGL ES and does not export that flag. libmali exports only the Mali ICD.

The minimal image builds Panfrost GLES and does not build PanVK.

## Consequences

A Panfrost GLES result is not a Vulkan result. PanVK remains experimental. One orange frame presented with the opt-in is not hardware acceptance of Vulkan games.

Rollback is writing the previous GPU value and rebooting. Do not switch the GPU from an SSH session as part of a test.

Implemented support and hardware acceptance stay separate. `docs/ROADMAP.md` records which paths were accepted.
