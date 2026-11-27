#!/usr/bin/env python3
"""Read Buildroot's configured package graph and join it to the static inventory.

scripts/inventory-packages.py remains the static reading of Zlyme's
BR2_EXTERNAL recipes. This tool does not replace it and does not
resolve dependencies itself. It asks Buildroot 2026.08 for show-info
on the product, minimal, and ARMHF defconfigs, then matches those
records to the static inventory.

show-info describes the configured graph. It does not describe the
installed root filesystem. install_target true means the recipe asks
Buildroot to copy files into the target directory. It does not prove
that a file remains after image assembly. A host package is a build
tool. Product, minimal, and ARMHF graphs are recorded separately.
Configuration compiles Buildroot's Kconfig conf program into a
temporary directory created by tempfile.mkdtemp. The tool deletes
only that directory, and only after checking it is still inside the
system temporary area. It does not compile packages or a toolchain,
and it does not download package sources.

The ARMHF runtime's installed version is the hash of its compiled
manifest. A show-info value of "missing" is not that version.

Match method: the show-info key is the Buildroot package name. A
host-* name also proposes the name with that prefix removed. The
inner raw name and, for a BR2_EXTERNAL recipe, the package-directory
basename are further proposals. Proposals that name the same static
recipe are one match. Proposals that name different static recipes
are ambiguous and are not combined. A Buildroot recipe that shares a
name with an external recipe is also ambiguous. Zero proposals leave
the static fields empty.
"""

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCHEMA = "zlyme-configured-package-inventory/1"
CONFIGS = (
    ("armhf", "zlyme_my355_armhf_defconfig"),
    ("minimal", "zlyme_my355_minimal_defconfig"),
    ("product", "zlyme_my355_defconfig"),
)
ARMHF_RUNTIME = "zlyme-armhf-runtime"
MATCH_METHOD = (
    "Show-info key, host- prefix removed, raw name, and the external "
    "package-directory basename. One static recipe matches. Different "
    "static recipes are ambiguous and stay unmerged."
)
LIMITATIONS = (
    "The configured graph is not the set of files in an assembled image.",
    "install_target, install_staging, and install_images are recipe flags, not image membership.",
    "A host package is a build tool, not a target runtime package.",
    "Product, minimal, and ARMHF graphs are separate and are not merged.",
    "dependencies are Buildroot's direct dependency names, including download, extract, and patch dependencies.",
    "The recursive closure is the set of show-info objects, not a second resolver.",
    "show-info hash entries are file paths. Digest values come only from a unique static match.",
    "An unresolved static expression is preserved beside any value show-info expanded.",
    "show-info value missing is not an installed ARMHF runtime version.",
    "A deliberately-unknown static license is copied unchanged.",
    "legal-info is not run and package sources are not downloaded.",
    "Configuration compiles only Buildroot's Kconfig conf tool, in the temporary output.",
)


class IncompatibleBuildroot(ValueError):
    """The Buildroot tree is not the version build.sh pins."""


def assert_compatible(describe, pinned):
    if describe != pinned or not pinned:
        raise IncompatibleBuildroot(
            "Buildroot %s is not the pinned version %s"
            % (describe, pinned)
        )


def parse_show_info(text):
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("show-info did not contain a JSON object")
    data = json.loads(text[start : end + 1])
    if not isinstance(data, dict):
        raise ValueError("show-info JSON was not an object")
    return data


def recipe_origin(package_dir, external_root):
    if not package_dir:
        return "buildroot"
    path = Path(package_dir)
    if not path.is_absolute():
        return "buildroot"
    try:
        path.resolve().relative_to(Path(external_root).resolve())
    except ValueError:
        return "buildroot"
    return "br2-external"


def _text_field(obj, key):
    if key not in obj:
        return {"status": "absent", "value": None}
    value = obj[key]
    if not isinstance(value, str) or not value:
        return {"status": "unavailable", "value": None}
    if "$(" in value or "${" in value:
        return {"status": "unresolved", "value": value}
    return {"status": "resolved", "value": value}


def _flag(obj, key, applicable):
    if not applicable:
        return {"status": "not-applicable", "value": None}
    if key not in obj or not isinstance(obj[key], bool):
        return {"status": "unavailable", "value": None}
    return {"status": "established", "value": obj[key]}


def _string_list(obj, key):
    if key not in obj:
        return {"status": "absent", "values": []}
    value = obj[key]
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        return {"status": "unavailable", "values": []}
    return {"status": "established", "values": list(value)}


def _downloads(obj):
    if "downloads" not in obj:
        return {"status": "absent", "values": []}
    value = obj["downloads"]
    if not isinstance(value, list):
        return {"status": "unavailable", "values": []}
    rows = []
    for item in value:
        if not isinstance(item, dict) or not isinstance(item.get("source"), str):
            return {"status": "unavailable", "values": []}
        uris = item.get("uris")
        if not isinstance(uris, list) or any(not isinstance(uri, str) for uri in uris):
            return {"status": "unavailable", "values": []}
        rows.append({"source": item["source"], "uris": list(uris)})
    rows.sort(key=lambda item: item["source"])
    return {"status": "established", "values": rows}


def _base_name(name):
    if name.startswith("host-"):
        return name[len("host-") :]
    return name


def classify_version(name, show_value, static_version, manifest):
    """Keep the recipe expression and the show-info value apart."""
    raw = show_value if isinstance(show_value, str) and show_value else None
    unresolved = bool(static_version and static_version.get("kind") == "unresolved")
    runtime = _base_name(name) == ARMHF_RUNTIME
    evidence = (manifest or {}).get("installed_version_evidence")
    if runtime and raw == "missing":
        if evidence == "host-output-only":
            reason = (
                "show-info reported missing because the recipe manifest path "
                "is absent. The host output manifest digest is recorded "
                "separately and is not used as this version."
            )
        elif evidence == "recipe-path":
            reason = (
                "show-info reported missing. That value is not the runtime "
                "manifest digest recorded separately."
            )
        else:
            reason = (
                "installed-version evidence is unavailable because the "
                "ARMHF runtime manifest is absent"
            )
        return {
            "reason": reason,
            "resolved": None,
            "show_info": raw,
            "static": static_version,
            "status": "unavailable",
        }
    if unresolved and raw == "missing":
        return {
            "reason": "show-info expanded an unresolved recipe expression to missing",
            "resolved": None,
            "show_info": raw,
            "static": static_version,
            "status": "unavailable",
        }
    if raw is None:
        return {
            "reason": None,
            "resolved": None,
            "show_info": None,
            "static": static_version,
            "status": "absent",
        }
    if "$(" in raw or "${" in raw:
        return {
            "reason": "show-info left a Make expression unresolved",
            "resolved": None,
            "show_info": raw,
            "static": static_version,
            "status": "unresolved",
        }
    return {
        "reason": None,
        "resolved": raw,
        "show_info": raw,
        "static": static_version,
        "status": "resolved",
    }


def _index_static(packages):
    index = {}
    duplicates = set()
    for record in packages:
        name = record.get("name")
        if not isinstance(name, str):
            continue
        if name in index:
            duplicates.add(name)
        index[name] = record
    return index, duplicates


def _proposals(name, raw_name, package_dir, origin):
    found = []

    def add(item):
        if isinstance(item, str) and item and item not in found:
            found.append(item)

    add(name)
    add(_base_name(name))
    add(raw_name)
    if origin == "br2-external" and package_dir:
        add(Path(package_dir).name)
    return found


def match_static(name, raw_name, package_dir, origin, index, duplicates):
    proposals = _proposals(name, raw_name, package_dir, origin)
    chosen = []
    for proposal in proposals:
        if proposal in duplicates or proposal in index:
            if proposal not in chosen:
                chosen.append(proposal)
    chosen.sort()
    if origin != "br2-external":
        if chosen:
            return {
                "candidates": chosen,
                "reason": "buildroot record shares a name with an external recipe",
                "status": "ambiguous",
            }
        return {"candidates": [], "reason": None, "status": "not-external"}
    if len(chosen) == 1 and chosen[0] not in duplicates:
        recipe = index[chosen[0]]
        return {
            "candidates": chosen,
            "hash_status": recipe.get("hash_status"),
            "hashes": recipe.get("hashes"),
            "license": recipe.get("license"),
            "reason": None,
            "recipe": chosen[0],
            "site": recipe.get("site"),
            "source": recipe.get("source"),
            "status": "matched",
            "version": recipe.get("version"),
        }
    if chosen:
        return {
            "candidates": chosen,
            "reason": "more than one external recipe matches this record",
            "status": "ambiguous",
        }
    return {
        "candidates": [],
        "reason": "external package directory has no static recipe match",
        "status": "external-unmatched",
    }


def normalize_package(
    name, obj, configuration, external_root, index, duplicates, manifest
):
    if not isinstance(obj, dict):
        obj = {}
    pkg_type = obj.get("type")
    if pkg_type not in ("target", "host", "rootfs"):
        type_field = {"status": "unavailable", "value": None}
        applicable = False
        role = "unknown"
    else:
        type_field = {"status": "established", "value": pkg_type}
        applicable = pkg_type == "target"
        role = {
            "target": "target-configured",
            "host": "host-build",
            "rootfs": "rootfs-target",
        }[pkg_type]
    package_dir = obj.get("package_dir")
    if not isinstance(package_dir, str):
        package_dir = None
    origin = "buildroot" if pkg_type == "rootfs" else recipe_origin(
        package_dir, external_root
    )
    raw_name = obj.get("name") if isinstance(obj.get("name"), str) else None
    matched = match_static(
        name, raw_name, package_dir, origin, index, duplicates
    )
    static_version = matched.get("version") if matched["status"] == "matched" else None
    return {
        "buildroot_name": name,
        "configuration": configuration,
        "configured_hash_files": _string_list(obj, "hashes"),
        "dependencies": _string_list(obj, "dependencies"),
        "downloads": _downloads(obj),
        "image_membership": "not-established",
        "install_images": _flag(obj, "install_images", applicable),
        "install_staging": _flag(obj, "install_staging", applicable),
        "install_target": _flag(obj, "install_target", applicable),
        "license_files": _string_list(obj, "license_files"),
        "licenses": _text_field(obj, "licenses"),
        "package_dir": package_dir,
        "raw_name": raw_name,
        "recipe_origin": origin,
        "runtime_role": role,
        "static_match": matched,
        "type": type_field,
        "version": classify_version(
            name, obj.get("version"), static_version, manifest
        ),
        "virtual": obj.get("virtual") if isinstance(obj.get("virtual"), bool) else None,
    }


def _recognized_manifest(path):
    import hashlib

    if path.is_symlink():
        return {
            "buildroot": None,
            "defconfig_sha256": None,
            "digest": None,
            "path": str(path),
            "status": "symlink",
        }
    if not path.is_file():
        return {
            "buildroot": None,
            "defconfig_sha256": None,
            "digest": None,
            "path": str(path),
            "status": "absent",
        }
    data = path.read_bytes()
    fields = {}
    for line in data.decode("utf-8", "replace").splitlines():
        if not line or line.startswith(("file ", "link ")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        fields.setdefault(key, value)
    recognized = (
        fields.get("format") == "1"
        and fields.get("defconfig") == "zlyme_my355_armhf_defconfig"
    )
    return {
        "buildroot": fields.get("buildroot"),
        "defconfig_sha256": fields.get("defconfig_sha256"),
        "digest": hashlib.sha256(data).hexdigest(),
        "path": str(path),
        "status": "present" if recognized else "unrecognized",
    }


def _manifest_record(root, explicit):
    if explicit is not None:
        return explicit
    root = Path(root)
    recipe = _recognized_manifest(
        Path("/zlyme/armhf") / (ARMHF_RUNTIME + ".manifest")
    )
    host = _recognized_manifest(
        root / "output-armhf" / (ARMHF_RUNTIME + ".manifest")
    )
    current = root / "configs" / "zlyme_my355_armhf_defconfig"
    if host.get("defconfig_sha256") and current.is_file():
        import hashlib

        digest = hashlib.sha256(current.read_bytes()).hexdigest()
        host["defconfig_matches_source"] = digest == host["defconfig_sha256"]
    else:
        host["defconfig_matches_source"] = None
    if recipe["status"] == "present":
        evidence = "recipe-path"
    elif host["status"] == "present":
        evidence = "host-output-only"
    else:
        evidence = "unavailable"
    return {
        "host_output": host,
        "installed_version_evidence": evidence,
        "recipe_path": recipe,
    }


def assemble(graphs, static_document, identity, external_root, manifest=None):
    assert_compatible(identity.get("describe"), identity.get("pinned_version"))
    packages = static_document.get("packages") or []
    index, duplicates = _index_static(packages)
    manifest_record = _manifest_record(external_root, manifest)
    records = []
    graph_summary = {}
    for configuration, _defconfig in CONFIGS:
        payload = graphs.get(configuration)
        if payload is None:
            graph_summary[configuration] = {
                "defconfig": dict(CONFIGS)[configuration],
                "entries": 0,
                "external": 0,
                "host": 0,
                "rootfs": 0,
                "status": "not-provided",
                "target": 0,
            }
            continue
        counts = {"host": 0, "rootfs": 0, "target": 0}
        external = 0
        for name in sorted(payload):
            record = normalize_package(
                name,
                payload[name],
                configuration,
                external_root,
                index,
                duplicates,
                manifest_record,
            )
            records.append(record)
            kind = record["type"]["value"]
            if kind in counts:
                counts[kind] += 1
            if record["recipe_origin"] == "br2-external":
                external += 1
        graph_summary[configuration] = {
            "defconfig": dict(CONFIGS)[configuration],
            "entries": len(payload),
            "external": external,
            "host": counts["host"],
            "rootfs": counts["rootfs"],
            "status": "present",
            "target": counts["target"],
        }
    records.sort(key=lambda item: (item["configuration"], item["buildroot_name"]))
    return {
        "armhf_runtime_manifest": manifest_record,
        "buildroot": {
            "describe": identity.get("describe"),
            "pinned_version": identity.get("pinned_version"),
            "revision": identity.get("revision"),
        },
        "graphs": graph_summary,
        "image_membership": "not-established",
        "limitations": list(LIMITATIONS),
        "match_method": MATCH_METHOD,
        "packages": records,
        "schema": SCHEMA,
        "scope": "configured-show-info",
    }


def load_static(root):
    path = Path(__file__).with_name("inventory-packages.py")
    spec = importlib.util.spec_from_file_location(
        "zlyme_inventory_packages", path
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.inventory(Path(root))


def buildroot_identity(buildroot, pinned):
    def git(*args):
        result = subprocess.run(
            ["git", "-C", str(buildroot), *args],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return None
        return result.stdout.strip()

    describe = git("describe", "--tags", "--exact-match")
    revision = git("rev-parse", "HEAD")
    identity = {
        "describe": describe,
        "pinned_version": pinned,
        "revision": revision,
    }
    assert_compatible(describe, pinned)
    return identity


def _pinned_version(root):
    text = (Path(root) / "build.sh").read_text(encoding="utf-8")
    for line in text.splitlines():
        if line.startswith('readonly BUILDROOT_VERSION="'):
            return line.split('"', 2)[1]
    raise IncompatibleBuildroot("build.sh does not pin BUILDROOT_VERSION")


_OWNED_TEMPS = set()


def _owned_temp_dir():
    """Create the only directory this tool is allowed to delete."""
    path = Path(tempfile.mkdtemp(prefix="zlyme-configured-"))
    _OWNED_TEMPS.add(os.path.realpath(path))
    return path


def _remove_owned_temp(path):
    """Delete a directory this process created under the system temp root.

    The path is normalized before the prefix check. A symlink is refused
    instead of followed. The temp root itself is refused. A directory
    under the temp root that this process did not create is refused,
    including a checkout that happens to live there.
    """
    root = os.path.realpath(tempfile.gettempdir())
    supplied = os.fspath(path)
    if os.path.islink(supplied):
        raise SystemExit("refusing to delete a symbolic link")
    candidate = os.path.realpath(supplied)
    if candidate == root or not candidate.startswith(root + os.sep):
        raise SystemExit("refusing to delete a directory outside the temporary area")
    if candidate not in _OWNED_TEMPS:
        raise SystemExit("refusing to delete a directory this process did not create")
    if os.path.islink(candidate) or not os.path.isdir(candidate):
        raise SystemExit("refusing to delete a path that is not a directory")
    shutil.rmtree(candidate)
    _OWNED_TEMPS.discard(candidate)


def collect_graphs(root, buildroot):
    work = _owned_temp_dir()
    env = os.environ.copy()
    env["DL_DIR"] = str(work / "dl")
    env["CCACHE_DIR"] = str(work / "ccache")
    env["CCACHE_DISABLE"] = "1"
    graphs = {}
    try:
        (work / "dl").mkdir()
        (work / "ccache").mkdir()
        for configuration, defconfig in CONFIGS:
            output = work / configuration
            common = [
                "make",
                "-C",
                str(buildroot),
                "O=%s" % output,
                "BR2_EXTERNAL=%s" % root,
            ]
            subprocess.run(
                common + [defconfig],
                check=True,
                env=env,
                stdout=subprocess.DEVNULL,
            )
            result = subprocess.run(
                common + ["show-info"],
                check=True,
                env=env,
                capture_output=True,
                text=True,
            )
            graphs[configuration] = parse_show_info(result.stdout)
    finally:
        _remove_owned_temp(work)
    return graphs


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--buildroot", type=Path, default=None)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    buildroot = (args.buildroot or (root / "buildroot")).resolve()
    pinned = _pinned_version(root)
    identity = buildroot_identity(buildroot, pinned)
    static_document = load_static(root)
    graphs = collect_graphs(root, buildroot)
    document = assemble(graphs, static_document, identity, root)
    for name in sorted(document["graphs"]):
        graph = document["graphs"][name]
        print(
            "%s entries=%s target=%s host=%s rootfs=%s external=%s"
            % (
                name,
                graph["entries"],
                graph["target"],
                graph["host"],
                graph["rootfs"],
                graph["external"],
            ),
            file=sys.stderr,
        )
    json.dump(document, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
