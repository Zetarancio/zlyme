#!/usr/bin/env python3
"""Pack a stock-side Zlyme preloader helper as a miyoo355_fw image.

The container is apommel's: a model/version sector, bootstrap.sh in the next
4 KiB, and a ustar payload at sector 16. Stock's miyoo_fw_update runs that
bootstrap only when the file is named miyoo355_fw.img.

bootstrap.sh, patch-preloader.sh, and fdtpatch.awk are copied from the pinned
apommel tree. The install script and the boot-order tools are Zlyme's.
"""

from __future__ import annotations

import argparse
import io
import pathlib
import tarfile

SECTOR = 512
SCRIPT_SECTORS = 8
PAYLOAD_SECTOR = 16
TAR_LIMIT = 256 * SECTOR

HERE = pathlib.Path(__file__).resolve().parent
MODES = {
    "maskrom": "install-maskrom.sh",
    "restore": "install-restore.sh",
}


def add_bytes(tar: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mtime = 0
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mode = 0o755 if name.endswith(".sh") else 0o644
    tar.addfile(info, io.BytesIO(data))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apommel", type=pathlib.Path, required=True)
    ap.add_argument("--mode", choices=sorted(MODES), required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("out", type=pathlib.Path)
    args = ap.parse_args()
    src = args.apommel
    for name in ("bootstrap.sh", "patch-preloader.sh", "fdtpatch.awk"):
        if not (src / name).is_file():
            raise SystemExit(f"missing {src / name}")

    header = f"model:miyoo355\nversion:{args.version}\n".encode()
    if len(header) > SECTOR:
        raise SystemExit("header does not fit in one sector")
    script = (src / "bootstrap.sh").read_bytes()
    if len(script) > SCRIPT_SECTORS * SECTOR:
        raise SystemExit("bootstrap.sh is over the 4 KiB stock reads")

    notice = """\
Container, bootstrap.sh, patch-preloader.sh, and fdtpatch.awk:
  apommel/baseos-my355 e09d37bb0f03c34e564d61bd02164f332d8515a8
  MIT. See APOMMEL-LICENSE.
common.sh, check-image.sh, apply-boot-order.sh, bootorder.awk,
and install.sh:
  Zlyme. MIT. See ZLYME-LICENSE.
Stock runs this image only when the card file is named miyoo355_fw.img.
This archive contains no preloader binary.
"""
    files = [
        ("install.sh", (HERE / MODES[args.mode]).read_bytes()),
        ("common.sh", (HERE / "common.sh").read_bytes()),
        ("check-image.sh", (HERE / "check-image.sh").read_bytes()),
        ("apply-boot-order.sh", (HERE / "apply-boot-order.sh").read_bytes()),
        ("bootorder.awk", (HERE / "bootorder.awk").read_bytes()),
        ("patch-preloader.sh", (src / "patch-preloader.sh").read_bytes()),
        ("fdtpatch.awk", (src / "fdtpatch.awk").read_bytes()),
        ("NOTICE", notice.encode()),
        ("APOMMEL-LICENSE", (src.parent.parent / "LICENSE").read_bytes()),
        ("ZLYME-LICENSE", (HERE / "LICENSE").read_bytes()),
    ]

    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.USTAR_FORMAT) as tar:
        for name, data in files:
            add_bytes(tar, name, data)
    payload = buf.getvalue()
    if len(payload) > TAR_LIMIT:
        raise SystemExit(f"payload is {len(payload)} bytes, over the 128 KiB bootstrap reads")

    img = bytearray(header.ljust(SECTOR, b"\0"))
    img += script.ljust(SCRIPT_SECTORS * SECTOR, b"\0")
    img = img.ljust(PAYLOAD_SECTOR * SECTOR, b"\0")
    img += payload
    args.out.write_bytes(bytes(img))
    print(f"wrote {args.out} ({len(img)} bytes, version {args.version})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
