#!/usr/bin/env python3
"""Structural checks for a 2 MiB my355 preloader image.

The layout matches apommel's patch-preloader.sh: two RKNS IDB copies,
each with two entries whose stored SHA-256 matches the payload.
Entry 0 is the DDR blob. Entry 1 is the SPL. The /pinctrl repair
changes the SPL and must leave the DDR payload byte-identical.

The recovery transform is offline. It shortens the SPL boot-order
property to the right-hand SD controller and reseals the SPL hashes.
It does not erase or program NAND. A local manifest is not a signature:
disarm trusts the transform only after it recomputes that image from
the saved source and compares the bytes.
"""

import hashlib
import json
import struct
import sys

SIZE = 2097152
COPIES = (131072, 524288)
ENTRY = 0x58
ENTRIES = 2
DDR_INDEX = 0
SPL_INDEX = 1
DTB_OFF = 0x3A5C0
BOOT_CALL = 0x27D4
BOOT_CALL_INSN = bytes.fromhex("50f8ff97")
SPL_BANNER = "U-Boot SPL 2017.09 (Nov 02 2024 - 15:59:04)"
RIGHT_SLOT = "/dwmmc@fe2b0000"
SOURCE_ORDER = (
    "/dwmmc@fe2b0000",
    "/sdhci@fe310000",
    "/nandc@fe330000",
    "/sfc@fe300000/flash@0",
    "/sfc@fe300000/flash@1",
)
DESIGN = "right-sd-v1"
SCHEMA = 1
MANIFEST_KEYS = (
    "schema",
    "design",
    "device",
    "source_sha256",
    "recovery_sha256",
    "source_backup",
    "source_ddr_sha256",
    "spl_banner",
    "executable_sha256",
)


def _u16le(blob, off):
    return int.from_bytes(blob[off:off + 2], "little")


def _parse(data):
    if len(data) != SIZE:
        raise SystemExit(f"size {len(data)} is not {SIZE}")
    found = []
    for base in COPIES:
        if data[base:base + 4] != b"RKNS":
            raise SystemExit(f"no RKNS magic at {base}")
        for i in range(ENTRIES):
            entry = base + 0x78 + i * ENTRY
            off = _u16le(data, entry)
            count = _u16le(data, entry + 2)
            if count <= 0:
                raise SystemExit(f"empty IDB entry {i} at {base}")
            start = base + off * 512
            length = count * 512
            if start < 0 or start + length > len(data):
                raise SystemExit(f"IDB entry {i} at {base} is out of range")
            blob = data[start:start + length]
            want = data[entry + 0x18:entry + 0x18 + 32]
            if hashlib.sha256(blob).digest() != want:
                raise SystemExit(f"IDB entry {i} at {base} fails its SHA-256")
            found.append({
                "copy": base,
                "index": i,
                "entry": entry,
                "start": start,
                "payload": blob,
            })
    return found


def _entries(data):
    return [(item["index"], item["payload"]) for item in _parse(data)]


def _paired(data):
    found = _parse(data)
    ddr = [item["payload"] for item in found if item["index"] == DDR_INDEX]
    spl = [item for item in found if item["index"] == SPL_INDEX]
    if len(ddr) != len(COPIES) or ddr[0] != ddr[1]:
        raise SystemExit(f"DDR copies disagree")
    if len(spl) != len(COPIES) or spl[0]["payload"] != spl[1]["payload"]:
        raise SystemExit("SPL copies disagree")
    return ddr[0], spl


def validate(path):
    _entries(open(path, "rb").read())
    return 0


def _ddr(path):
    blobs = [blob for index, blob in _entries(open(path, "rb").read()) if index == DDR_INDEX]
    if len(blobs) != len(COPIES) or blobs[0] != blobs[1]:
        raise SystemExit(f"DDR copies disagree in {path}")
    return blobs[0]


def ddr_same(left, right):
    if _ddr(left) != _ddr(right):
        raise SystemExit("DDR payload differs")
    return 0


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _fdt(payload):
    if len(payload) < DTB_OFF + 40:
        raise SystemExit("SPL payload is too small for a device tree")
    off = int.from_bytes(payload[0x10:0x14], "little")
    if off != DTB_OFF:
        raise SystemExit(f"SPL device tree offset is {off:#x}")
    if payload[BOOT_CALL:BOOT_CALL + 4] != BOOT_CALL_INSN:
        raise SystemExit("SPL boot-order call is not the Nov 02 instruction")
    if SPL_BANNER.encode() not in payload[:DTB_OFF]:
        raise SystemExit("SPL banner is not the Nov 02 2024 Miyoo build")
    if payload[DTB_OFF:DTB_OFF + 4] != b"\xd0\x0d\xfe\xed":
        raise SystemExit("SPL device tree magic is missing")
    total = int.from_bytes(payload[DTB_OFF + 4:DTB_OFF + 8], "big")
    if DTB_OFF + total > len(payload):
        raise SystemExit("SPL device tree overruns the payload")
    if payload[DTB_OFF + total:] != bytes(len(payload) - DTB_OFF - total):
        raise SystemExit("bytes after the SPL device tree are not zero")
    return payload[DTB_OFF:DTB_OFF + total]


def _walk(blob):
    if len(blob) < 40 or blob[:4] != b"\xd0\x0d\xfe\xed":
        raise SystemExit("FDT magic is missing")
    vals = struct.unpack(">IIIIIIIIII", blob[:40])
    total, off_struct, off_str, _rsv, _ver, _last, _cpu, size_str, size_struct = vals[1:]
    if total != len(blob) or off_struct + size_struct > len(blob) or off_str + size_str > len(blob):
        raise SystemExit("FDT header is out of range")
    strings = blob[off_str:off_str + size_str]
    p = off_struct
    end = off_struct + size_struct
    stack = []
    props = []
    while p < end:
        token = struct.unpack_from(">I", blob, p)[0]
        if token == 1:
            z = blob.index(b"\0", p + 4)
            stack.append(blob[p + 4:z].decode())
            p = (z + 4) & ~3
        elif token == 2:
            if not stack:
                raise SystemExit("FDT node nesting is invalid")
            stack.pop()
            p += 4
        elif token == 3:
            length, nameoff = struct.unpack_from(">II", blob, p + 4)
            if nameoff < 0 or nameoff >= len(strings):
                raise SystemExit("FDT property name is out of range")
            name = strings[nameoff:strings.index(b"\0", nameoff)].decode()
            data = blob[p + 12:p + 12 + length]
            path = "/" + "/".join(part for part in stack if part)
            props.append((path, name, data, p))
            p = (p + 12 + length + 3) & ~3
        elif token == 4:
            p += 4
        elif token == 9:
            return vals, strings, props
        else:
            raise SystemExit(f"bad FDT token {token:#x}")
    raise SystemExit("FDT structure has no end token")


def _stringlist(data):
    if not data or data[-1] != 0:
        raise SystemExit("boot-order property is not a terminated string list")
    return [part.decode() for part in data.split(b"\0")[:-1]]


def _boot_order(blob):
    _vals, _strings, props = _walk(blob)
    found = [item for item in props if item[0] == "/chosen" and item[1] == "u-boot,spl-boot-order"]
    if len(found) != 1:
        raise SystemExit("SPL boot-order property is missing")
    return found[0], _stringlist(found[0][2])


def _require_right_slot(blob):
    _vals, _strings, props = _walk(blob)
    alias = [item[2] for item in props if item[0] == "/aliases" and item[1] == "mmc1"]
    if alias != [RIGHT_SLOT.encode() + b"\0"]:
        raise SystemExit("mmc1 alias is not the right-hand slot")
    flags = {item[1]: item[2] for item in props if item[0] == "/dwmmc@fe2b0000"}
    if b"\0" not in flags.get("status", b"") or flags.get("status", b"").split(b"\0", 1)[0] != b"okay":
        raise SystemExit("right-hand slot is not okay")
    if "u-boot,dm-spl" not in flags:
        raise SystemExit("right-hand slot is not an SPL device")


def _replace_boot_order(blob):
    vals, strings, _props = _walk(blob)
    prop, order = _boot_order(blob)
    if tuple(order) == (RIGHT_SLOT,):
        raise SystemExit("image is already a right-slot recovery preloader")
    if tuple(order) != SOURCE_ORDER:
        raise SystemExit("SPL boot order is not the Nov 02 list")
    _require_right_slot(blob)
    at = prop[3]
    old = prop[2]
    new = RIGHT_SLOT.encode() + b"\0"
    old_end = (at + 12 + len(old) + 3) & ~3
    new_end = (at + 12 + len(new) + 3) & ~3
    delta = new_end - old_end
    off_struct = vals[2]
    size_struct = vals[9]
    struct_end = off_struct + size_struct
    head = bytearray(blob[at:at + 12])
    struct.pack_into(">I", head, 4, len(new))
    pad = bytes((4 - (len(new) & 3)) & 3)
    body = blob[:at] + bytes(head) + new + pad + blob[old_end:struct_end] + strings
    out = bytearray(body)
    struct.pack_into(">I", out, 4, vals[1] + delta)
    struct.pack_into(">I", out, 12, vals[3] + delta)
    struct.pack_into(">I", out, 36, size_struct + delta)
    if len(out) != vals[1] + delta:
        raise SystemExit("rebuilt device tree size is inconsistent")
    _prop, rebuilt = _boot_order(bytes(out))
    if rebuilt != [RIGHT_SLOT]:
        raise SystemExit("rebuilt boot order is not the right-hand slot")
    return bytes(out)


def _fingerprint(payload, blob):
    return {
        "banner": SPL_BANNER,
        "executable_sha256": _sha(payload[:DTB_OFF]),
        "dtb_sha256": _sha(blob),
    }


def derive_bytes(data):
    raw = bytes(data)
    ddr, spl = _paired(raw)
    payload = spl[0]["payload"]
    blob = _fdt(payload)
    edited = _replace_boot_order(blob)
    if len(edited) >= len(blob):
        raise SystemExit("recovery device tree did not shrink")
    rebuilt = payload[:DTB_OFF] + edited + bytes(len(payload) - DTB_OFF - len(edited))
    if rebuilt[:DTB_OFF] != payload[:DTB_OFF]:
        raise SystemExit("recovery transform changed SPL executable bytes")
    if rebuilt[BOOT_CALL:BOOT_CALL + 4] != BOOT_CALL_INSN:
        raise SystemExit("recovery transform changed the boot-order call")
    out = bytearray(raw)
    digest = hashlib.sha256(rebuilt).digest()
    for item in spl:
        out[item["start"]:item["start"] + len(rebuilt)] = rebuilt
        out[item["entry"] + 0x18:item["entry"] + 0x38] = digest
    produced = bytes(out)
    new_ddr, _new_spl = _paired(produced)
    if new_ddr != ddr:
        raise SystemExit("recovery transform changed the DDR payload")
    if produced[spl[0]["start"]:spl[0]["start"] + DTB_OFF] != payload[:DTB_OFF]:
        raise SystemExit("resealed SPL executable bytes changed")
    return produced


def _load(path):
    return open(path, "rb").read()


def _hex64(value, label):
    if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
        raise SystemExit(f"recovery manifest {label} is not a sha256")
    return value


def manifest_for(source, recovery):
    ddr, spl = _paired(source)
    payload = spl[0]["payload"]
    blob = _fdt(payload)
    _prop, order = _boot_order(blob)
    if tuple(order) != SOURCE_ORDER:
        raise SystemExit("source boot order is not the Nov 02 list")
    if hashlib.sha256(recovery).digest() != hashlib.sha256(derive_bytes(source)).digest():
        raise SystemExit("recovery image is not the derivative of the source")
    if recovery != derive_bytes(source):
        raise SystemExit("recovery image is not the derivative of the source")
    finger = _fingerprint(payload, blob)
    source_sha = _sha(source)
    return {
        "schema": SCHEMA,
        "design": DESIGN,
        "device": "my355",
        "source_sha256": source_sha,
        "recovery_sha256": _sha(recovery),
        "source_backup": f"preloader-current-{source_sha}.img",
        "source_ddr_sha256": _sha(ddr),
        "spl_banner": finger["banner"],
        "executable_sha256": finger["executable_sha256"],
    }


def _manifest(path):
    try:
        obj = json.loads(open(path, "r", encoding="utf-8").read())
    except (OSError, UnicodeError, json.JSONDecodeError):
        raise SystemExit("recovery manifest is malformed")
    if not isinstance(obj, dict) or tuple(sorted(obj)) != tuple(sorted(MANIFEST_KEYS)):
        raise SystemExit("recovery manifest is malformed")
    if obj["schema"] != SCHEMA or type(obj["schema"]) is not int:
        raise SystemExit("recovery manifest schema is not supported")
    if obj["design"] != DESIGN:
        raise SystemExit("recovery manifest design is not supported")
    if obj["device"] != "my355":
        raise SystemExit("recovery manifest device is not my355")
    for key in ("source_sha256", "recovery_sha256", "source_ddr_sha256", "executable_sha256"):
        _hex64(obj[key], key)
    name = obj["source_backup"]
    if name != f"preloader-current-{obj['source_sha256']}.img":
        raise SystemExit("recovery manifest source backup name is not the source sha")
    if obj["spl_banner"] != SPL_BANNER:
        raise SystemExit("recovery manifest SPL banner is not the Nov 02 build")
    return obj


def bound_source(manifest_path, live_path, directory):
    """Print the source backup path, or refuse.

    The manifest hashes are checked, then discarded as authority.
    The source file has to regenerate the live bytes.
    """
    doc = _manifest(manifest_path)
    live = _load(live_path)
    _paired(live)
    if _sha(live) != doc["recovery_sha256"]:
        raise SystemExit("live preloader is not the recovery image in the manifest")
    directory = directory.rstrip("/")
    name = doc["source_backup"]
    source_path = directory + "/" + name
    try:
        source = _load(source_path)
    except OSError:
        raise SystemExit("source backup is missing")
    if _sha(source) != doc["source_sha256"]:
        raise SystemExit("source backup sha does not match the manifest")
    source_ddr, source_spl = _paired(source)
    live_ddr, live_spl = _paired(live)
    if source_ddr != live_ddr or _sha(source_ddr) != doc["source_ddr_sha256"]:
        raise SystemExit("DDR payload does not match the source backup")
    source_payload = source_spl[0]["payload"]
    live_payload = live_spl[0]["payload"]
    if SPL_BANNER.encode() not in source_payload[:DTB_OFF]:
        raise SystemExit("source backup is a different SPL build")
    if source_payload[:DTB_OFF] != live_payload[:DTB_OFF]:
        raise SystemExit("recovery image changed SPL executable bytes")
    if _sha(source_payload[:DTB_OFF]) != doc["executable_sha256"]:
        raise SystemExit("source executable sha does not match the manifest")
    try:
        expected = derive_bytes(source)
    except SystemExit as exc:
        raise SystemExit(f"source backup is a different SPL build: {exc}")
    if expected != live:
        raise SystemExit("live recovery image is not the derivative of the source backup")
    return source_path


def main(argv):
    if len(argv) == 2:
        return validate(argv[1])
    if len(argv) == 4 and argv[1] == "ddr":
        return ddr_same(argv[2], argv[3])
    if len(argv) == 4 and argv[1] == "derive":
        produced = derive_bytes(_load(argv[2]))
        open(argv[3], "wb").write(produced)
        return 0
    if len(argv) == 4 and argv[1] == "recovery-manifest":
        doc = manifest_for(_load(argv[2]), _load(argv[3]))
        sys.stdout.write(json.dumps(doc, indent=2) + "\n")
        return 0
    if len(argv) == 5 and argv[1] == "recovery-source":
        sys.stdout.write(bound_source(argv[2], argv[3], argv[4]) + "\n")
        return 0
    raise SystemExit(
        "usage: preloader_image.py IMAGE"
        " | preloader_image.py ddr IMAGE IMAGE"
        " | preloader_image.py derive SOURCE DEST"
        " | preloader_image.py recovery-manifest SOURCE RECOVERY"
        " | preloader_image.py recovery-source MANIFEST LIVE DIR"
    )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
