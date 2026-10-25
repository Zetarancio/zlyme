# ROCKNIX compat archive coverage, 2026-10-25

Pinned `ROCKNIX/packages` `691f24bceb72228f20d41ddb4a1e76ed76a1b0b8`, `compat.tar.gz` SHA-256 `4eba88bf7fef74489fc7d113005aec5b335519a8901e776f7d6203bbcc58b791`. The archive was not installed. It contains one directory and 50 regular files. Those files have 49 distinct SONAMEs. `libSDL2-2.0.so.0` and `libSDL2-2.0.so.0.gles` are two files with the same SONAME. There is no other duplicate SONAME.

The local candidate is the product target built from `zlyme_my355_defconfig`. The installed image is source `72916de`. That image was inspected for the X-Moto and JVGS failures: it has `libxml2.so.16` and does not have `libxml2.so.2`, `libSDL2_net-2.0.so.0`, or `libmodplug.so.1`. Those two SDL and modplug names are not in this archive either. The other system SONAMEs below are present in the local product target. This pass did not re-list every one of them on the Flip.

Walked port closures are X-Moto, JVGS, and Aerofoil. X-Moto needs `libxml2.so.2` and system `libSDL2-2.0.so.0`. It does not need the archive's SDL2 file. JVGS and Aerofoil do not need any file in this archive. LÖVE uses Zlyme's source-built `libtheoradec.so.1`, not the archive copy, which also needs `libcairo.so.2`.

| File | SONAME | Candidate | Same SONAME note | Outside-libc NEEDED | Walked ports | Source-built provider |
| --- | --- | --- | --- | --- | --- | --- |
| `libFLAC.so.8` | `libFLAC.so.8` | missing | no selected package installs this SONAME | libogg.so.0 | — | — |
| `libSDL2-2.0.so.0` | `libSDL2-2.0.so.0` | system | system SDL2; archive also needs libasound. Do not replace it. | libasound.so.2 | X-Moto uses system SDL2 | existing system package |
| `libSDL2-2.0.so.0.gles` | `libSDL2-2.0.so.0` | system | same SONAME as system SDL2. ROCKNIX deletes both SDL2 files on install. | libasound.so.2 | X-Moto uses system SDL2 | existing system package |
| `libaom.so.0` | `libaom.so.0` | missing | no selected package installs this SONAME | — | — | — |
| `libavcodec.so.58` | `libavcodec.so.58` | missing | no selected package installs this SONAME | libswresample.so.3, libavutil.so.56, libvpx.so.6, libwebpmux.so.3, libwebp.so.6, liblzma.so.5, librsvg-2.so.2, libgobject-2.0.so.0, libglib-2.0.so.0, libcairo.so.2, libzvbi.so.0, libsnappy.so.1, libaom.so.0, libcodec2.so.0.8.1, libgsm.so.1, libmp3lame.so.0, libopenjp2.so.7, libopus.so.0, libshine.so.3, libspeex.so.1, libtheoraenc.so.1, libtheoradec.so.1, libtwolame.so.0, libvorbis.so.0, libvorbisenc.so.2, libwavpack.so.1, libx264.so.155, libx265.so.176, libxvidcore.so.4, libva.so.2 | — | — |
| `libavformat.so.58` | `libavformat.so.58` | missing | no selected package installs this SONAME | libavcodec.so.58, libavutil.so.56, libxml2.so.2, libbz2.so.1.0, libgme.so.0, libopenmpt.so.0, libchromaprint.so.1, libbluray.so.2, libgnutls.so.30, libssh-gcrypt.so.4 | — | — |
| `libavutil.so.56` | `libavutil.so.56` | missing | no selected package installs this SONAME | libva-drm.so.2, libva.so.2, libva-x11.so.2, libvdpau.so.1, libX11.so.6, libdrm.so.2 | — | — |
| `libbluray.so.2` | `libbluray.so.2` | missing | no selected package installs this SONAME | libxml2.so.2, libfontconfig.so.1, libfreetype.so.6 | — | — |
| `libchromaprint.so.1` | `libchromaprint.so.1` | missing | no selected package installs this SONAME | libavcodec.so.58, libavutil.so.56 | — | — |
| `libcodec2.so.0.8.1` | `libcodec2.so.0.8.1` | missing | no selected package installs this SONAME | — | — | — |
| `libcom_err.so.2` | `libcom_err.so.2` | system | same SONAME | — | — | existing system package |
| `libcroco-0.6.so.3` | `libcroco-0.6.so.3` | missing | no selected package installs this SONAME | libglib-2.0.so.0, libxml2.so.2 | — | — |
| `libcrypto.so.1.1` | `libcrypto.so.1.1` | missing | different ABI. System OpenSSL is libcrypto.so.3. | — | — | — |
| `libgdk_pixbuf-2.0.so.0` | `libgdk_pixbuf-2.0.so.0` | missing | no selected package installs this SONAME | libglib-2.0.so.0, libgobject-2.0.so.0, libgmodule-2.0.so.0, libgio-2.0.so.0 | — | — |
| `libgme.so.0` | `libgme.so.0` | missing | no selected package installs this SONAME | — | — | — |
| `libgsm.so.1` | `libgsm.so.1` | missing | no selected package installs this SONAME | — | — | — |
| `libgssapi_krb5.so.2` | `libgssapi_krb5.so.2` | missing | no selected package installs this SONAME | libkrb5.so.3, libk5crypto.so.3, libcom_err.so.2, libkrb5support.so.0 | — | — |
| `libk5crypto.so.3` | `libk5crypto.so.3` | missing | no selected package installs this SONAME | libkrb5support.so.0 | — | — |
| `libkeyutils.so.1` | `libkeyutils.so.1` | missing | no selected package installs this SONAME | — | — | — |
| `libkrb5.so.3` | `libkrb5.so.3` | missing | no selected package installs this SONAME | libk5crypto.so.3, libcom_err.so.2, libkrb5support.so.0, libkeyutils.so.1 | — | — |
| `libkrb5support.so.0` | `libkrb5support.so.0` | missing | no selected package installs this SONAME | — | — | — |
| `liblzma.so.5` | `liblzma.so.5` | system | same SONAME | — | — | existing system package |
| `libmp3lame.so.0` | `libmp3lame.so.0` | missing | no selected package installs this SONAME | — | — | — |
| `libnuma.so.1` | `libnuma.so.1` | missing | no selected package installs this SONAME | — | — | — |
| `libogg.so.0` | `libogg.so.0` | system | system libogg. LÖVE also ships a private copy. | — | — | existing system package |
| `libopenjp2.so.7` | `libopenjp2.so.7` | missing | no selected package installs this SONAME | — | — | — |
| `libopenmpt.so.0` | `libopenmpt.so.0` | missing | no selected package installs this SONAME | libmpg123.so.0, libvorbis.so.0, libvorbisfile.so.3 | — | — |
| `libopus.so.0` | `libopus.so.0` | system | same SONAME | — | — | existing system package |
| `librsvg-2.so.2` | `librsvg-2.so.2` | missing | no selected package installs this SONAME | libgdk_pixbuf-2.0.so.0, libgio-2.0.so.0, libpangocairo-1.0.so.0, libcairo.so.2, libpangoft2-1.0.so.0, libpango-1.0.so.0, libgobject-2.0.so.0, libfontconfig.so.1, libcroco-0.6.so.3, libglib-2.0.so.0, libxml2.so.2 | — | — |
| `libshine.so.3` | `libshine.so.3` | missing | no selected package installs this SONAME | — | — | — |
| `libsnappy.so.1` | `libsnappy.so.1` | missing | no selected package installs this SONAME | — | — | — |
| `libsoxr.so.0` | `libsoxr.so.0` | missing | no selected package installs this SONAME | libgomp.so.1 | — | — |
| `libssh-gcrypt.so.4` | `libssh-gcrypt.so.4` | missing | no selected package installs this SONAME | libgcrypt.so.20, libgpg-error.so.0, libgssapi_krb5.so.2 | — | — |
| `libswresample.so.3` | `libswresample.so.3` | missing | no selected package installs this SONAME | libavutil.so.56, libsoxr.so.0 | — | — |
| `libswscale.so.5` | `libswscale.so.5` | missing | no selected package installs this SONAME | libavutil.so.56 | — | — |
| `libtheoradec.so.1` | `libtheoradec.so.1` | compat | Zlyme 1.1.1 decoder needs only libc. Archive copy also needs libcairo. | libcairo.so.2 | LÖVE uses Zlyme's copy | portmaster-theora-compat 1.1.1 |
| `libtheoraenc.so.1` | `libtheoraenc.so.1` | missing | no selected package installs this SONAME | libogg.so.0 | — | — |
| `libtwolame.so.0` | `libtwolame.so.0` | missing | no selected package installs this SONAME | — | — | — |
| `libva-drm.so.2` | `libva-drm.so.2` | missing | no selected package installs this SONAME | libva.so.2, libdrm.so.2 | — | — |
| `libva-x11.so.2` | `libva-x11.so.2` | missing | no selected package installs this SONAME | libva.so.2, libX11.so.6, libXext.so.6, libXfixes.so.3, libdrm.so.2 | — | — |
| `libva.so.2` | `libva.so.2` | missing | no selected package installs this SONAME | — | — | — |
| `libvpx.so.6` | `libvpx.so.6` | missing | no selected package installs this SONAME | — | — | — |
| `libwavpack.so.1` | `libwavpack.so.1` | missing | no selected package installs this SONAME | — | — | — |
| `libwebp.so.6` | `libwebp.so.6` | missing | different ABI. System libwebp is libwebp.so.7. | — | — | — |
| `libwebpmux.so.3` | `libwebpmux.so.3` | system | same SONAME. Zlyme's copy needs libwebp.so.7. Archive copy needs libwebp.so.6. | libwebp.so.6 | — | existing system package |
| `libx264.so.155` | `libx264.so.155` | missing | no selected package installs this SONAME | — | — | — |
| `libx265.so.176` | `libx265.so.176` | missing | no selected package installs this SONAME | libnuma.so.1 | — | — |
| `libxml2.so.2` | `libxml2.so.2` | compat | source-built 2.13.9. System library remains libxml2.so.16. Absent on 72916de. | — | X-Moto | portmaster-xml2-compat 2.13.9 |
| `libxvidcore.so.4` | `libxvidcore.so.4` | missing | no selected package installs this SONAME | — | — | — |
| `libzvbi.so.0` | `libzvbi.so.0` | missing | no selected package installs this SONAME | libpng16.so.16 | — | — |

## Totals, local candidate

- Regular files: 50
- Distinct SONAMEs: 49
- Duplicate SONAME inside the archive: 1 SONAME, 2 files (`libSDL2-2.0.so.0`)
- Files whose SONAME is already in `/usr/lib` or `/lib`: 7
- Files whose SONAME is only under `/usr/lib/compat`: 2 (`libtheoradec.so.1`, `libxml2.so.2`)
- Files with no matching SONAME: 41
- Installed `72916de` lacks `libxml2.so.2`, so its compat coverage of this archive is the Theora decoder only.

Same SONAME is not the same build. The two differences that matter are `libtheoradec.so.1` (archive needs cairo; Zlyme's source-built decoder does not) and `libwebpmux.so.3` (archive needs `libwebp.so.6`; Zlyme's copy needs `libwebp.so.7`). Those archive files are not installed. The other missing SONAMEs are installed from this pinned archive by `portmaster-rocknix-compat`, except the two SDL2 objects. `libgomp.so.1`, X11, Pango, Speex, libgcrypt, and libvdpau are source-built so the installed ELF files have a resolvable `DT_NEEDED` closure. `libcrypto.so.1.1` and `libwebp.so.6` remain different SONAMEs from the system libraries and are supplied by the archive, not by renaming the system files.
