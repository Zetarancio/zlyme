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

## 18D0.1. Path proof and mount identity

Date: 2026-11-08. The 18D0 launcher compared the work-directory string with mountinfo and unmounted a path when exactly one mount remained there. Two defects follow from that.

`ZLYME_DRASTIC_WORKDIR=/tmp/../storage` is not one of the literal banned strings, and it is the directory `/storage` once the kernel resolves it. The mount table names `/storage`, so the string comparison would miss that mount. The removal would then run on persistent storage. The same gap covers `.`, repeated slashes, a trailing slash, and a symlink in the middle of the path. This pass did not execute that override and did not point `rm` at it.

A count of one is not ownership. This launch can create mount id 10, lose it, and find id 99 alone at the same path. The 18D0 release would unmount 99.

The device scratch path is the literal `/tmp/drastic-run`. A test override is accepted only when it is an absolute path under `/tmp/`, it is not that device path, and none of its components is `.`, `..`, empty, or a repeated slash. Each existing component is then a real directory. A symlink component is refused before removal. A test directory that does not already exist is refused. The check that fails is finished before `rm`.

Each launch creates `/tmp/drastic-run.lock` with `mkdir`, or the matching sibling of a test directory. The second launch finds that directory and returns. It does not remove the scratch tree. There is no signal trap. MENU+START delivers SIGTERM to the shell and then SIGKILL; neither runs the release lines. The lock and any binds stay. The next launch returns at the lock. SIGKILL cannot be handled. A stale mount is still not removed and not unmounted.

After each successful bind the launcher stores the single new mountinfo id. Release unmounts only when that same id is the only id at the path. A replacement id, a stack, a missing id, or an unreadable table is left mounted. The lock stays in those cases so the next launch cannot remove the tree. A failed first bind releases the lock because no mount was added. A failed second bind unmounts the first path only when its recorded id is still the only one there.

A symlink-only layout was considered. The installed DraStic binary contains the formats `%s%cbackup%c%s.dsv` and `%s%csavestates%c%s_%d.dss`. It does not contain the strings `realpath`, `readlink`, or `O_NOFOLLOW`. That is not evidence the proprietary program follows a symlink, rejects one, or requires a bind. The binary was not executed. The bind mount stays. A correct symlink would be created only when `backup` and `savestates` do not already exist as directories. That layout is not shipped.

The host regression is `scripts/tests/test_drastic_workdir.sh`. Its `rm` refuses every path outside the disposable root, and the path-refusal cases do not execute `rm`. It does not create a bind. It does not depend on `/tmp/drastic-run` being absent. The run printed `drastic workdir ok`. Covered cases include the traversal strings, an intermediate symlink, a symlink used as the work directory, save-slot symlinks, a replacement mount id, a held lock, a concurrent holder, a failed bind, a failed release, a stale mount, a stacked mount, a malformed table, and an unreadable table. The persistent fixture files stayed. `strace` is not installed here, so the traversal case was not traced; the refusal happened before `rm`. The target BusyBox is 1.38.0 and contains `awk`, `mkdir`, `rmdir`, `rm`, `mount`, and `umount`. It was not executed. The script does not call `realpath` or `mountpoint`.

The same regression is in the lightweight source job of `.github/workflows/validation.yml`. It does not build DraStic or an image.

The check and the removal are still two steps. The lock keeps another launcher out of that window. It does not stop a different program from mounting the scratch directory in between. A killed launch leaves the lock until the tmpfs is gone. Reboot clears it. No image contains this correction, and DraStic was not launched.

## 18D0.2. Test cleanup and forced termination

Date: 2026-11-08. The 18D0.1 regression removed `/tmp/drastic-run` or `/tmp/drastic-run.lock` when either path appeared after the test started. The test does not own those paths. Cleanup now stops only that test's launcher and fake emulator, then removes only the directory from its own `mktemp` when the path is `/tmp/tmp.*` and is not a symlink. The function does not call `rmdir`, `mount`, or `umount`. A check of the function text rejects a cleanup that names the production scratch path.

`package/system/nextui/zlyme/zlyme-pak-spawn.c` sends SIGTERM to the session leader and then to the other members. The wait is 30 polls of 50 ms, and the following signal is SIGKILL. For Nintendo DS the leader is the `package/emulators/drastic/start_drastic.sh` shell, and DraStic is its child. The shell is signaled while DraStic can still be running. The shell has no trap, so SIGTERM ends it before the unmount lines. SIGKILL cannot be trapped. A trap that unmounted on SIGTERM would start too early. None was added.

`scripts/tests/test_drastic_workdir.sh` printed `drastic workdir ok`. A normal exit releases both owned mounts and the lock, and the next launch succeeds. SIGTERM and SIGKILL to the launcher leave the lock, both simulated binds, and the fake emulator. The following launch refuses and leaves the fixture saves in place. No real bind was created.

After MENU+START the lock and the binds remain until the tmpfs is gone, or until a separately authorized recovery removes them. Another NDS launch refuses until then. That is the contained limitation. This branch is not a firmware candidate: the correction is not in an image, and DraStic was not launched. Phase 18D is not closed.

## 18D1. Diagnostic image and black screen

Date: 2026-11-08. A local product image was built from `29e84c8d65278820b7763dd904f298048654734c` and the maintainer installed it. The packed root was `zlyme-my355-20261108-29e84c8d6527`. One existing Nintendo DS ROM was started from the NextUI list. DraStic stayed on a black screen. The process had the KMSDRM driver selected and `/dev/dri/card0` open. Its maps did not include EGL or GLES. The NDS log stayed at its header. MENU+START returned to NextUI. The launch lock and both save binds were still present afterward. Those binds were on the second card. This pass did not unmount them, delete the lock, or launch again.

The earlier sections of this file describe the DraStic launcher that image contained. They are the evidence. They are not the current launcher.

## 18D2. DSperate replaces DraStic

Date: 2026-11-08. After that launch, the maintainer explicitly superseded the earlier decision not to replace DraStic. DSperate is the only NDS emulator in the product source. The pin is `beebono/DSperate` tag `v3.4.0`, commit `aabc4b065afaf582cbc43c16d579de431b808d57`. The emulator is GPL-3.0-or-later. FreeBIOS keeps its BSD-2-Clause notice, the Noto glyphs keep the OFL, WenQuanYi keeps the GPL-3.0-or-later font exception, and vendored miniz keeps its MIT notice. The built-in analog cheat database is not linked: upstream says `usrcheat-analog.dat` is not GPL, and Zlyme has no exception for it. An empty built-in catalogue is not reported as a corrupt database. A file named `usrcheat-analog.dat` beside the ROM or the config is still read. Vulkan, GLES, Wayland scanout, achievements, networking, and PGO are off. The NDS pak execs `start_dsperate`, which execs `dsperate` with the ROM quoted. The launcher also passes `--no-mic`, so a game that reads the microphone does not open `plughw:0,0` beside SDL playback.

The launcher passes `--sink kms --no-gpu-present --no-gpu3d`. Those options are in the pinned parser. KMS page flips use the SDL KMSDRM window and do not link Vulkan, RGA, or Wayland. `--no-gpu-present` skips the Vulkan and RGA presenters. `--no-gpu3d` keeps the 3D layer on the CPU. A sink that does not open falls back to SDL's renderer inside the same process. That fallback has not been seen on the Flip. No DSperate binary has been compiled in this pass, and DSperate has not been launched on hardware.

Battery saves are `$SAVES_PATH/NDS/dsperate/<rom stem>.sav`. States are `$SAVES_PATH/NDS/dsperate/states/<game code>.<slot>.dss` and `<game code>.auto.dss`. The command line sets `paths.saves` and `paths.states` after the config file is read, so an older ini cannot put them back beside the ROM. Config is `$XDG_CONFIG_HOME/dsperate/dsperate.ini`. The session exports `XDG_CONFIG_HOME=/storage/.config`. `SAVES_PATH` is the selected library's `Saves` directory. A missing ini is written once. A non-empty ini is kept. Optional BIOS files are `Bios/NDS/bios9.bin`, `bios7.bin`, and `firmware.bin`. A missing BIOS is allowed. `.nds` and `.zip` are the extensions DSperate opens itself. `.7z` is not extracted before launch, so it is not listed.

`Saves/NDS/backup`, `Saves/NDS/savestates`, and `.config/drastic` are not mounted, renamed, converted, or deleted by installation. Reset standalone settings removes `.config/dsperate` and does not remove `.config/drastic`. Deleting one ROM removes a stem-matched `Saves/NDS/dsperate/<name>.sav`. It does not remove DraStic `.dsv` files or a game-code `.dss` state. There is no DraStic package, `start_drastic`, or `libdrastouch` in the active tree.

Host checks cover the pin, the launcher, quoting, the config seed, and those legacy files. They do not show a picture, sound, or a frame time. Phase 18D stays open. The next step is a local package build and, only after that is reviewed, a diagnostic image. The Flip still has the DraStic lock and binds from the launch above. This source change does not clear them.
