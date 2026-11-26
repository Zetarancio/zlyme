#!/usr/bin/env python3
"""Inventory Zlyme's BR2_EXTERNAL package recipes.

This is a static reading of the external tree. It does not configure
Buildroot, run show-info, download sources, or decide which packages
are installed in an image. A recipe's presence is not a shipment.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA = "zlyme-package-inventory/1"
DECONFIGS = (
    ("product", "configs/zlyme_my355_defconfig"),
    ("minimal", "configs/zlyme_my355_minimal_defconfig"),
    ("armhf", "configs/zlyme_my355_armhf_defconfig"),
)
LITERAL_KEYS = (
    "BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE",
    "BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE",
    "BR2_PACKAGE_ROCKCHIP_RKBIN_TPL_FILENAME",
    "BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME",
)
FLOATING = {"main", "master", "HEAD", "trunk", "next", "develop"}
HASH_LINE = re.compile(
    r"^(md5|sha1|sha224|sha256|sha384|sha512)\s+(\S+)\s+(\S+)\s*$"
)
ASSIGN = re.compile(r"^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$")
EVAL = re.compile(r"\$\(eval \$\((host-)?([a-z0-9]+)-package\)\)")
SYMBOL = re.compile(r"^config (BR2_PACKAGE_[A-Z0-9_]+)\s*$")
SELECTED = re.compile(r"^(BR2_PACKAGE_[A-Z0-9_]+)=y\s*$")
LITERAL = re.compile(r'^([A-Z0-9_]+)="(.*)"\s*$')
VERSION_PIN = re.compile(
    r'^readonly BUILDROOT_VERSION="([^"]+)"\s*$', re.M
)
LIMITATIONS = (
    "External recipes only. Buildroot's own package directory is not enumerated.",
    "show-info is not run. Dependency closure and the installed rootfs are not computed.",
    "A direct defconfig symbol is not evidence that the package is shipped.",
    "Make functions and $(shell) values are left unresolved.",
    "A forty-character hex version is a commit pin, separate from any archive hash.",
    "A literal version does not pin a site that contains /raw/main, /raw/master, or /refs/heads/.",
    "An absent .hash file is recorded as absent. It is not rewritten into a hash.",
    "License text is copied from the recipe. An unspecified LicenseRef stays unknown.",
)


def _joined_lines(text):
    joined = []
    pending = None
    for line in text.splitlines():
        if pending is None:
            pending = line
        else:
            pending = pending[:-1].rstrip() + " " + line.strip()
        if pending.endswith("\\"):
            continue
        joined.append(pending)
        pending = None
    if pending is not None:
        joined.append(pending)
    return joined


def _assignments(text):
    values = {}
    for line in _joined_lines(text):
        if not line or line[0].isspace() or line.startswith("#"):
            continue
        match = ASSIGN.match(line)
        if match:
            values[match.group(1)] = match.group(2).strip()
    return values


def _status_value(value):
    if value is None:
        return {"status": "absent", "value": None}
    if "$(" in value or "${" in value:
        return {"status": "unresolved", "value": value}
    return {"status": "known", "value": value}


def _version(value, site_method, site):
    if value is None:
        return {"kind": "absent", "value": None}
    if "$(" in value or "${" in value:
        return {"kind": "unresolved", "value": value}
    if value in FLOATING:
        return {"kind": "floating-branch", "value": value}
    if re.fullmatch(r"[0-9a-f]{40}", value):
        return {"kind": "git-commit", "value": value}
    if site_method == "git" or (site and site.endswith(".git")):
        return {"kind": "git-ref", "value": value}
    return {"kind": "release", "value": value}


def _site_pin(site):
    if site is None:
        return "absent"
    if "$(" in site or "${" in site:
        return "unresolved"
    markers = ("/raw/main", "/raw/master", "/refs/heads/")
    if any(marker in site for marker in markers):
        return "floating-branch"
    return "literal"


def _authority(version_kind, site_method, site_pin):
    if site_pin == "floating-branch" or version_kind == "floating-branch":
        return "floating-branch"
    if version_kind == "unresolved":
        return "not-established"
    if version_kind == "git-commit":
        return "pinned-commit"
    if version_kind == "git-ref":
        return "git-ref"
    if site_method == "local":
        return "local-tree"
    if version_kind == "release":
        return "recipe-version"
    return "not-established"


def _license(declared, files):
    names = files.split() if files else []
    if declared is None:
        return {"declared": None, "files": names, "status": "absent"}
    if "unspecified" in declared:
        status = "deliberately-unknown"
    else:
        status = "declared"
    return {"declared": declared, "files": names, "status": status}


def _hashes(path):
    if path is None or not path.is_file():
        return [], "absent"
    found = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = HASH_LINE.match(stripped)
        if not match:
            continue
        found.append(
            {
                "algorithm": match.group(1),
                "filename": match.group(3),
                "value": match.group(2),
            }
        )
    found.sort(key=lambda item: (item["filename"], item["algorithm"], item["value"]))
    return found, ("present" if found else "absent")


def _symbols(package_dir):
    found = []
    for name in ("Config.in", "Config.in.host"):
        path = package_dir / name
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            match = SYMBOL.match(line)
            if match:
                found.append(match.group(1))
    return sorted(set(found))


def _selected(path, source):
    selected = set()
    literals = []
    if not path.is_file():
        return None, None
    for line in path.read_text(encoding="utf-8").splitlines():
        selected_match = SELECTED.match(line)
        if selected_match:
            selected.add(selected_match.group(1))
        literal_match = LITERAL.match(line)
        if literal_match and literal_match.group(1) in LITERAL_KEYS:
            literals.append(
                {
                    "key": literal_match.group(1),
                    "source": source,
                    "value": literal_match.group(2),
                }
            )
    return selected, literals


def _provides(text):
    target = False
    host = False
    for match in EVAL.finditer(text):
        if match.group(1):
            host = True
        else:
            target = True
    if target and host:
        return "target-and-host"
    if host:
        return "host"
    if target:
        return "target"
    return "absent"


def _packages(root):
    package_root = root / "package"
    records = []
    symbol_owner = {}
    if not package_root.is_dir():
        return records, symbol_owner
    for makefile in sorted(package_root.rglob("*.mk")):
        if makefile.parent == package_root:
            continue
        if makefile.stem != makefile.parent.name:
            continue
        text = makefile.read_text(encoding="utf-8")
        if _provides(text) == "absent":
            continue
        prefix = makefile.stem.upper().replace("-", "_")
        assigned = _assignments(text)
        site = assigned.get(prefix + "_SITE")
        site_method = assigned.get(prefix + "_SITE_METHOD")
        source = assigned.get(prefix + "_SOURCE")
        version = _version(
            assigned.get(prefix + "_VERSION"), site_method, site
        )
        symbols = _symbols(makefile.parent)
        for symbol in symbols:
            symbol_owner.setdefault(symbol, makefile.parent.name)
        patches = sorted(
            path.name
            for path in makefile.parent.iterdir()
            if path.is_file() and path.suffix == ".patch"
        )
        hash_path = makefile.parent / (makefile.stem + ".hash")
        hashes, hash_status = _hashes(hash_path if hash_path.is_file() else None)
        evidence = [makefile.relative_to(root).as_posix()]
        for extra in ("Config.in", "Config.in.host", makefile.stem + ".hash"):
            extra_path = makefile.parent / extra
            if extra_path.is_file():
                evidence.append(extra_path.relative_to(root).as_posix())
        for patch in patches:
            evidence.append(
                (makefile.parent / patch).relative_to(root).as_posix()
            )
        category = makefile.parent.parent.name
        if makefile.parent.parent == package_root:
            category = makefile.parent.name
        records.append(
            {
                "archive_hashes": hashes,
                "category": category,
                "config_symbols": symbols,
                "dependency_closure": "not-computed",
                "direct_defconfig_selection": [],
                "evidence": evidence,
                "hash_status": hash_status,
                "license": _license(
                    assigned.get(prefix + "_LICENSE"),
                    assigned.get(prefix + "_LICENSE_FILES"),
                ),
                "name": makefile.parent.name,
                "patches": patches,
                "provides": _provides(text),
                "shipped": "not-established",
                "site": _status_value(site),
                "site_method": site_method,
                "site_pin": _site_pin(site),
                "source": _status_value(source),
                "version": version,
                "version_authority": _authority(
                    version["kind"], site_method, _site_pin(site)
                ),
            }
        )
    records.sort(key=lambda item: item["name"])
    return records, symbol_owner


def _buildroot(root):
    script = root / "build.sh"
    pinned = None
    if script.is_file():
        match = VERSION_PIN.search(script.read_text(encoding="utf-8"))
        if match:
            pinned = match.group(1)
    makefile = root / "buildroot" / "Makefile"
    present = "not-established"
    if makefile.is_file():
        text = makefile.read_text(encoding="utf-8", errors="replace")
        present = any(
            line.startswith("show-info:") for line in text.splitlines()
        )
    return {
        "pinned_version": pinned if pinned is not None else "not-established",
        "show_info": {"invoked": False, "target_present": present},
    }


def inventory(root):
    root = root.resolve()
    packages, owners = _packages(root)
    by_name = {record["name"]: record for record in packages}
    literals = []
    unmatched = {}
    for context, relative in DECONFIGS:
        path = root / relative
        selected, found_literals = _selected(path, relative)
        if selected is None:
            unmatched[context] = "not-established"
            continue
        literals.extend(found_literals)
        missing = []
        for symbol in sorted(selected):
            owner = owners.get(symbol)
            if owner is None:
                missing.append(symbol)
                continue
            record = by_name[owner]
            if context not in record["direct_defconfig_selection"]:
                record["direct_defconfig_selection"].append(context)
        unmatched[context] = missing
    for record in packages:
        record["direct_defconfig_selection"].sort()
    literals.sort(key=lambda item: (item["source"], item["key"]))
    return {
        "buildroot": _buildroot(root),
        "defconfig_literals": literals,
        "limitations": list(LIMITATIONS),
        "packages": packages,
        "schema": SCHEMA,
        "scope": "br2-external-recipes",
        "unmatched_defconfig_packages": unmatched,
    }


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="tree that contains package/ and configs/",
    )
    args = parser.parse_args(argv)
    json.dump(inventory(args.root), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
