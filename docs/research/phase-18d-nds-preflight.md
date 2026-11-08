# Phase 18D0 — Nintendo DS preflight

Date: 2026-11-08. Source and host only. Branch `zlyme45-phase-18d` starts at main `d4159da87570d8ddb60e31e7fe8968a2d078a472`. Phase 18C stays open on `zlyme45-phase-18c` at `2525168d0a81de4f85a864f1a4559e694edb0616` and is not in this branch. `docs/ROADMAP.md` and `docs/research/phase-18-plan.md` already differ on that branch, so this pass does not edit them.

DraStic was not launched. No image was built. The installed Phase 16 image does not contain the correction below.

## Save directories

`package/emulators/drastic/start_drastic.sh` clears `/tmp/drastic-run`, bind-mounts `Saves/NDS/backup` and `Saves/NDS/savestates` there, runs DraStic in the foreground, and unmounts those two paths. `package/system/nextui/paks/Emus/NDS.pak/launch.sh` replaces itself with that shell. The shell is the pak session leader. It does not replace itself with DraStic.

`package/system/nextui/zlyme/zlyme-pak-spawn.c` handles MENU+START by signaling that session. The leader and the other members receive SIGTERM. The wait is 30 polls of 50 ms, then SIGKILL. The old shell had no trap, so those signals skip the unmount lines. The binds stay in the mount table. The same skip happens when the shell is killed outright.

The next launch used to run `rm -rf` on `/tmp/drastic-run` before reading the mount table. A bind is a directory. Recursive removal enters it and deletes the files in the persistent save directory. A normal exit that reaches the unmount lines does not make the killed-session case safe.

The old fallback created a symlink when `mount --bind` failed. The destination directory already existed, and GNU `ln -sfn` then created the link inside that directory. GNU `rm -rf` of the parent directory leaves a symlink's target in place. GNU `rm -rf` of the symlink path with a trailing slash removes the target. The fallback is gone.

The rootfs BusyBox is 1.38.0. Its binary contains the `mountpoint` diagnostic text and an `awk` applet. It does not contain `one-file-system`. `mountpoint` identifies a mount by device number. A bind can share a device with its source, so that test is not the guard. The initramfs BusyBox is a different build and does not provide `mountpoint`. This launcher runs from the rootfs. The aarch64 binary was not executed.

The correction reads `/proc/self/mountinfo` field 5, the mountpoint. Optional fields before the hyphen do not move that field. The launch refuses, and does not remove or unmount anything, when the table cannot be read, a line cannot be parsed, or any mountpoint is the work directory or a path under it. The read and the later removal are two steps. A mount that appears in that gap is still removed. This launcher does not add a mount lock. A leftover symlink at the work directory or at either save slot is removed with `rm` and without `-r` before any recursive delete. The recursive delete has no trailing slash. A failed bind stays a failed bind. At exit, a path is unmounted only when the table shows exactly one mount there. Any other count is left mounted and reported. When DraStic itself returned 0 and a release failed, the launcher returns 1. The following launch hits the same refusal.

`scripts/tests/test_drastic_workdir.sh` drives the real launcher with a fake `mount`, a fake `umount`, and a fake DraStic binary. It does not create a bind and it does not touch `/tmp/drastic-run`. A clean table is accepted and the persistent files stay. A stale mount, a mount of the work directory itself, an escaped space in the mountpoint, two mounts at one slot, a malformed table, and an unreadable table all refuse before deletion. A failed unmount and a partial bind leave the simulated table in place, and the next launch does not delete the work directory or the save files. A symlink used as the work directory or as a save slot does not delete the save files. An unrelated mount, including a path that only shares the work directory's prefix, is not unmounted. A second mount that appears before release is left mounted. The host run printed `drastic workdir ok`. That is not gameplay and not a Flip result.

## Graphics

`package/system/nextui/nextui-session` exports `SDL_VIDEODRIVER=kmsdrm`. Before it runs the pak it calls `/usr/bin/zlyme-drm-release` and waits 0.4 seconds. The NDS launcher and `start_drastic.sh` do not call that helper again. `package/emulators/dolphin-emu/start_dolphin.sh` does.

The product SDL 2.32.10 configuration enables KMSDRM and the OpenGL ES and ES2 renderers. `SDL_VIDEO_RENDER_OGL` and `SDL_VIDEO_OPENGL` are undefined in that build. `package/emulators/drastic/sources/libdrastouch.c` logs `[drastouch] SDL renderer: %s (flags=0x%x)` when `SDL_GetRendererInfo` succeeds. Its black-menu comment applies when that name is `opengl`. This SDL build has no desktop OpenGL renderer, so that name is not one it can report. Absence of the line means `SDL_CreateRenderer` returned null or renderer info was not available. Shader setup logs `[drastouch] init_shader: mode=%d glCreateShader=%s` and `[drastouch] shader_program=%u`. A texture bind failure logs `[drastouch] SDL_GL_BindTexture failed:`. No tracing was added.

## Audio and input

The same SDL build sets `SDL_AUDIO_DRIVER_ALSA`. Its PulseAudio and PipeWire audio drivers are off. `board/my355/fsoverlay/etc/asound.conf` sends `pcm.!default` through the PipeWire ALSA plugin. `package/emulators/drastic/config/drastic.cfg` sets `enable_sound = 1`. `libdrastouch` opens a capture device only when `DSHOOK_MIC_THRESH` is set. Playback stays DraStic's own SDL audio.

`start_drastic.sh` sources `/usr/share/zlyme/pak-input.sh` when that file is readable. The helper limits SDL joysticks to `045e:028e`, the InputPlumber virtual pad. The stock config says `zlyme_pad_abi = xb360`. Its `controls_b` face values are 1024 through 1027. The Phase 15D button audit already recorded that map. This pass does not change it, PipeWire, ALSA, or InputPlumber.

## Later hardware launch

The Flip was not contacted. A launch waits until a candidate image contains this correction. The installed `4d1f74e` image still has the old removal.

Before that launch, `/proc/self/mountinfo` must show no mount at or under `/tmp/drastic-run`. A mount there ends the attempt. The directory is not removed and the mount is not detached by an unrelated command.

With system logs on, stderr goes to the NDS pak log. The log header contains the ROM path and is not published. The useful lines are the renderer line, the shader lines, a bind or unmount refusal, and the exit status. Also record the image identity, which process holds the DRM device after the session releases it and after MENU+START, whether the default PCM opened, and whether the virtual pad was the joystick SDL saw. After return, no `drastic` or `start_drastic` process remains. If the save binds are still mounted, the next launch has to refuse. Saves and `drastic.cfg` stay except for writes DraStic itself makes. No ROM is copied. DraStic stays the proprietary binary already recorded for this package. No second Nintendo DS emulator is added.

Phase 18D is not closed. Phase 18E is not started.
