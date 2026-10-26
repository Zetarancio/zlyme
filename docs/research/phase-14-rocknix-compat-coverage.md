# ROCKNIX compat archive coverage, 2026-10-25

Pinned `ROCKNIX/packages` `691f24bceb72228f20d41ddb4a1e76ed76a1b0b8`, `compat.tar.gz` SHA-256 `4eba88bf7fef74489fc7d113005aec5b335519a8901e776f7d6203bbcc58b791`. The archive contains one directory and 50 regular files. Those files have 49 distinct SONAMEs. `libSDL2-2.0.so.0` and `libSDL2-2.0.so.0.gles` are two files with the same SONAME. There is no other duplicate SONAME. The machine-readable inventory is `package/system/portmaster-rocknix-compat/sonames.tsv`.

Classification of those 50 files:

- A. Supplied by Zlyme with a compatible ABI. Seven files, six SONAMEs, including both SDL2 objects. Those SDL2 objects are not installed. ROCKNIX removes them because the SONAME is the system one.
- B. Supplied by an existing source-built PortMaster library. `libxml2.so.2` (2.13.9) and `libtheoradec.so.1` (1.1.1). The archive copies are not installed.
- C. Missing before this package. Forty-one files and forty-one SONAMEs. `portmaster-rocknix-compat` installs those unmodified bytes under `/usr/lib/compat`.
- D. No SONAME in the forty-nine is a source-built substitute for an archive file. Libraries those files need, and which Zlyme did not already provide, are source-built separately: `libgomp.so.1`, `libX11.so.6`, `libXext.so.6`, `libXfixes.so.3`, `libpango-1.0.so.0`, `libpangocairo-1.0.so.0`, `libpangoft2-1.0.so.0`, `libspeex.so.1`, `libgcrypt.so.20`, and `libvdpau.so.1`.
- E. Empty. The archive copies of `libtheoradec.so.1` and `libwebpmux.so.3` have different `DT_NEEDED` entries from Zlyme's libraries, so those archive files stay out. Zlyme's own SONAMEs remain the ones ports load.

`libSDL2_net-2.0.so.0` and `libmodplug.so.1` are not in this archive. They stay the Buildroot packages selected for X-Moto and JVGS.

The Candidate column is the comparison against the product target before the allowlist package. `archive` means the file is now the allowlist. The installed image during the X-Moto and JVGS inspection was source `72916de`. That image has `libxml2.so.16` and does not have `libxml2.so.2`, `libSDL2_net-2.0.so.0`, or `libmodplug.so.1`.

Walked port closures are X-Moto, JVGS, and Aerofoil. X-Moto needs `libxml2.so.2` and system `libSDL2-2.0.so.0`. It does not need the archive's SDL2 file. JVGS and Aerofoil do not need any file in this archive. LÖVE uses Zlyme's source-built `libtheoradec.so.1`, not the archive copy, which also needs `libcairo.so.2`.

| File | SONAME | Candidate | Same SONAME note | Outside-libc NEEDED | Walked ports | Source-built provider |
| --- | --- | --- | --- | --- | --- | --- |
| `libFLAC.so.8` | `libFLAC.so.8` | archive | unmodified allowlist file under `/usr/lib/compat` | libogg.so.0 | — | — |
| `libSDL2-2.0.so.0` | `libSDL2-2.0.so.0` | system | system SDL2; archive also needs libasound. Do not replace it. | libasound.so.2 | X-Moto uses system SDL2 | existing system package |
| `libSDL2-2.0.so.0.gles` | `libSDL2-2.0.so.0` | system | same SONAME as system SDL2. ROCKNIX deletes both SDL2 files on install. | libasound.so.2 | X-Moto uses system SDL2 | existing system package |
| `libaom.so.0` | `libaom.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libavcodec.so.58` | `libavcodec.so.58` | archive | unmodified allowlist file under `/usr/lib/compat` | libswresample.so.3, libavutil.so.56, libvpx.so.6, libwebpmux.so.3, libwebp.so.6, liblzma.so.5, librsvg-2.so.2, libgobject-2.0.so.0, libglib-2.0.so.0, libcairo.so.2, libzvbi.so.0, libsnappy.so.1, libaom.so.0, libcodec2.so.0.8.1, libgsm.so.1, libmp3lame.so.0, libopenjp2.so.7, libopus.so.0, libshine.so.3, libspeex.so.1, libtheoraenc.so.1, libtheoradec.so.1, libtwolame.so.0, libvorbis.so.0, libvorbisenc.so.2, libwavpack.so.1, libx264.so.155, libx265.so.176, libxvidcore.so.4, libva.so.2 | — | — |
| `libavformat.so.58` | `libavformat.so.58` | archive | unmodified allowlist file under `/usr/lib/compat` | libavcodec.so.58, libavutil.so.56, libxml2.so.2, libbz2.so.1.0, libgme.so.0, libopenmpt.so.0, libchromaprint.so.1, libbluray.so.2, libgnutls.so.30, libssh-gcrypt.so.4 | — | — |
| `libavutil.so.56` | `libavutil.so.56` | archive | unmodified allowlist file under `/usr/lib/compat` | libva-drm.so.2, libva.so.2, libva-x11.so.2, libvdpau.so.1, libX11.so.6, libdrm.so.2 | — | — |
| `libbluray.so.2` | `libbluray.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | libxml2.so.2, libfontconfig.so.1, libfreetype.so.6 | — | — |
| `libchromaprint.so.1` | `libchromaprint.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | libavcodec.so.58, libavutil.so.56 | — | — |
| `libcodec2.so.0.8.1` | `libcodec2.so.0.8.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libcom_err.so.2` | `libcom_err.so.2` | system | same SONAME | — | — | existing system package |
| `libcroco-0.6.so.3` | `libcroco-0.6.so.3` | archive | unmodified allowlist file under `/usr/lib/compat` | libglib-2.0.so.0, libxml2.so.2 | — | — |
| `libcrypto.so.1.1` | `libcrypto.so.1.1` | archive | different SONAME from system OpenSSL `libcrypto.so.3`. Unmodified allowlist file. | — | — | — |
| `libgdk_pixbuf-2.0.so.0` | `libgdk_pixbuf-2.0.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | libglib-2.0.so.0, libgobject-2.0.so.0, libgmodule-2.0.so.0, libgio-2.0.so.0 | — | — |
| `libgme.so.0` | `libgme.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libgsm.so.1` | `libgsm.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libgssapi_krb5.so.2` | `libgssapi_krb5.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | libkrb5.so.3, libk5crypto.so.3, libcom_err.so.2, libkrb5support.so.0 | — | — |
| `libk5crypto.so.3` | `libk5crypto.so.3` | archive | unmodified allowlist file under `/usr/lib/compat` | libkrb5support.so.0 | — | — |
| `libkeyutils.so.1` | `libkeyutils.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libkrb5.so.3` | `libkrb5.so.3` | archive | unmodified allowlist file under `/usr/lib/compat` | libk5crypto.so.3, libcom_err.so.2, libkrb5support.so.0, libkeyutils.so.1 | — | — |
| `libkrb5support.so.0` | `libkrb5support.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `liblzma.so.5` | `liblzma.so.5` | system | same SONAME | — | — | existing system package |
| `libmp3lame.so.0` | `libmp3lame.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libnuma.so.1` | `libnuma.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libogg.so.0` | `libogg.so.0` | system | system libogg. LÖVE also ships a private copy. | — | — | existing system package |
| `libopenjp2.so.7` | `libopenjp2.so.7` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libopenmpt.so.0` | `libopenmpt.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | libmpg123.so.0, libvorbis.so.0, libvorbisfile.so.3 | — | — |
| `libopus.so.0` | `libopus.so.0` | system | same SONAME | — | — | existing system package |
| `librsvg-2.so.2` | `librsvg-2.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | libgdk_pixbuf-2.0.so.0, libgio-2.0.so.0, libpangocairo-1.0.so.0, libcairo.so.2, libpangoft2-1.0.so.0, libpango-1.0.so.0, libgobject-2.0.so.0, libfontconfig.so.1, libcroco-0.6.so.3, libglib-2.0.so.0, libxml2.so.2 | — | — |
| `libshine.so.3` | `libshine.so.3` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libsnappy.so.1` | `libsnappy.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libsoxr.so.0` | `libsoxr.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | libgomp.so.1 | — | — |
| `libssh-gcrypt.so.4` | `libssh-gcrypt.so.4` | archive | unmodified allowlist file under `/usr/lib/compat` | libgcrypt.so.20, libgpg-error.so.0, libgssapi_krb5.so.2 | — | — |
| `libswresample.so.3` | `libswresample.so.3` | archive | unmodified allowlist file under `/usr/lib/compat` | libavutil.so.56, libsoxr.so.0 | — | — |
| `libswscale.so.5` | `libswscale.so.5` | archive | unmodified allowlist file under `/usr/lib/compat` | libavutil.so.56 | — | — |
| `libtheoradec.so.1` | `libtheoradec.so.1` | compat | Zlyme 1.1.1 decoder needs only libc. Archive copy also needs libcairo. | libcairo.so.2 | LÖVE uses Zlyme's copy | portmaster-theora-compat 1.1.1 |
| `libtheoraenc.so.1` | `libtheoraenc.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | libogg.so.0 | — | — |
| `libtwolame.so.0` | `libtwolame.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libva-drm.so.2` | `libva-drm.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | libva.so.2, libdrm.so.2 | — | — |
| `libva-x11.so.2` | `libva-x11.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | libva.so.2, libX11.so.6, libXext.so.6, libXfixes.so.3, libdrm.so.2 | — | — |
| `libva.so.2` | `libva.so.2` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libvpx.so.6` | `libvpx.so.6` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libwavpack.so.1` | `libwavpack.so.1` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libwebp.so.6` | `libwebp.so.6` | archive | different SONAME from system `libwebp.so.7`. Unmodified allowlist file. | — | — | — |
| `libwebpmux.so.3` | `libwebpmux.so.3` | system | same SONAME. Zlyme's copy needs libwebp.so.7. Archive copy needs libwebp.so.6. | libwebp.so.6 | — | existing system package |
| `libx264.so.155` | `libx264.so.155` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libx265.so.176` | `libx265.so.176` | archive | unmodified allowlist file under `/usr/lib/compat` | libnuma.so.1 | — | — |
| `libxml2.so.2` | `libxml2.so.2` | compat | source-built 2.13.9. System library remains libxml2.so.16. Absent on 72916de. | — | X-Moto | portmaster-xml2-compat 2.13.9 |
| `libxvidcore.so.4` | `libxvidcore.so.4` | archive | unmodified allowlist file under `/usr/lib/compat` | — | — | — |
| `libzvbi.so.0` | `libzvbi.so.0` | archive | unmodified allowlist file under `/usr/lib/compat` | libpng16.so.16 | — | — |

## Totals

- Regular files: 50
- Distinct SONAMEs: 49
- Duplicate SONAME inside the archive: 1 SONAME, 2 files (`libSDL2-2.0.so.0`)
- Class A, system: 7 files, 6 SONAMEs
- Class B, existing source-built compat: 2 files, 2 SONAMEs
- Class C, unmodified archive allowlist: 41 files, 41 SONAMEs
- Class D among the 49 SONAMEs: 0
- Class E: 0
- Covered SONAMEs: 49

Same SONAME is not the same build. The archive `libtheoradec.so.1` needs cairo; Zlyme's source-built decoder does not. The archive `libwebpmux.so.3` needs `libwebp.so.6`; Zlyme's copy needs `libwebp.so.7`. Those archive files are not installed. `libcrypto.so.1.1` and `libwebp.so.6` stay archive files because the system SONAMEs are `libcrypto.so.3` and `libwebp.so.7`. Installed `72916de` predates this package.
