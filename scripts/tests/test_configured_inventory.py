#!/usr/bin/env python3
"""Fixture tests for the configured show-info inventory.

These tests do not configure Buildroot, download sources, or read the
local Buildroot checkout.
"""

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock


def _load():
    path = Path(__file__).resolve().parents[1] / "inventory-configured.py"
    spec = importlib.util.spec_from_file_location("inventory_configured", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


inv = _load()
ROOT = Path("/fixture/zlyme")
UNKNOWN = {
    "declared": "LicenseRef-ROCKNIX-portmaster-compat-unspecified",
    "files": ["PROVENANCE"],
    "status": "deliberately-unknown",
}
SHELL_VERSION = {"kind": "unresolved", "value": "$(shell sha256sum manifest)"}


def _static(name, **extra):
    record = {
        "hash_status": "absent",
        "hashes": [],
        "license": {"declared": "MIT", "files": ["LICENSE"], "status": "declared"},
        "name": name,
        "site": {"status": "resolved", "value": "https://example.invalid/%s" % name},
        "source": {"status": "absent", "value": None},
        "version": {"kind": "release", "value": "1.0.0"},
    }
    record.update(extra)
    return record


def _target(name, **extra):
    record = {
        "dependencies": ["skeleton"],
        "downloads": [{"source": "%s-1.tar.gz" % name, "uris": ["https://example.invalid/a"]}],
        "install_images": False,
        "install_staging": False,
        "install_target": True,
        "license_files": ["LICENSE"],
        "licenses": "MIT",
        "name": name,
        "package_dir": "package/%s" % name,
        "type": "target",
        "version": "1.2.3",
        "virtual": False,
    }
    record.update(extra)
    return record


def _document(graphs, packages, manifest=None, describe="2026.08"):
    return inv.assemble(
        graphs,
        {"packages": packages},
        {
            "describe": describe,
            "pinned_version": "2026.08",
            "revision": "abc123",
        },
        ROOT,
        manifest=manifest
        if manifest is not None
        else {
            "checked_paths": [],
            "digests": [],
            "installed_version_evidence": "unavailable",
            "present": False,
            "status": "absent",
        },
    )


class ConfiguredInventoryTests(unittest.TestCase):
    def test_native_target_and_host_packages(self):
        document = _document(
            {
                "product": {
                    "busybox": _target("busybox"),
                    "host-cmake": {
                        "dependencies": ["host-skeleton"],
                        "downloads": [
                            {
                                "source": "cmake-4.4.0.tar.gz",
                                "uris": ["https://example.invalid/cmake"],
                            }
                        ],
                        "licenses": "BSD-3-Clause",
                        "name": "cmake",
                        "package_dir": "package/cmake",
                        "type": "host",
                        "version": "4.4.0",
                        "virtual": False,
                    },
                }
            },
            [],
        )
        by_name = {item["buildroot_name"]: item for item in document["packages"]}
        target = by_name["busybox"]
        host = by_name["host-cmake"]
        self.assertEqual(target["recipe_origin"], "buildroot")
        self.assertEqual(target["runtime_role"], "target-configured")
        self.assertEqual(target["static_match"]["status"], "not-external")
        self.assertEqual(target["version"]["resolved"], "1.2.3")
        self.assertEqual(target["install_target"]["value"], True)
        self.assertEqual(target["image_membership"], "not-established")
        self.assertEqual(host["runtime_role"], "host-build")
        self.assertEqual(host["type"]["value"], "host")
        self.assertEqual(host["install_target"]["status"], "not-applicable")
        self.assertEqual(host["version"]["resolved"], "4.4.0")
        self.assertNotEqual(host["runtime_role"], target["runtime_role"])

    def test_custom_target_and_host_join_one_recipe(self):
        document = _document(
            {
                "product": {
                    "widget": _target(
                        "widget",
                        package_dir="/fixture/zlyme/package/system/widget",
                    ),
                    "host-widget": {
                        "dependencies": [],
                        "licenses": "MIT",
                        "name": "widget",
                        "package_dir": "/fixture/zlyme/package/system/widget",
                        "type": "host",
                        "version": "9",
                        "virtual": False,
                    },
                }
            },
            [
                _static(
                    "widget",
                    hashes=[
                        {
                            "algorithm": "sha256",
                            "filename": "widget-1.0.0.tar.gz",
                            "role": "source-archive",
                            "value": "aa",
                        }
                    ],
                    hash_status="present",
                )
            ],
        )
        rows = {item["buildroot_name"]: item for item in document["packages"]}
        self.assertEqual(rows["widget"]["recipe_origin"], "br2-external")
        self.assertEqual(rows["widget"]["static_match"]["status"], "matched")
        self.assertEqual(rows["widget"]["static_match"]["recipe"], "widget")
        self.assertEqual(rows["widget"]["static_match"]["hashes"][0]["role"], "source-archive")
        self.assertEqual(rows["host-widget"]["static_match"]["recipe"], "widget")
        self.assertEqual(rows["host-widget"]["runtime_role"], "host-build")
        self.assertEqual(rows["widget"]["configuration"], "product")

    def test_install_flags_do_not_establish_image_membership(self):
        document = _document(
            {
                "product": {
                    "headers": _target(
                        "headers",
                        install_images=False,
                        install_staging=True,
                        install_target=False,
                        package_dir="/fixture/zlyme/package/system/headers",
                    ),
                    "installer": _target(
                        "installer",
                        install_images=True,
                        install_target=False,
                        package_dir="/fixture/zlyme/package/boot/installer",
                    ),
                }
            },
            [_static("headers"), _static("installer")],
        )
        rows = {item["buildroot_name"]: item for item in document["packages"]}
        self.assertEqual(rows["headers"]["install_target"]["value"], False)
        self.assertEqual(rows["headers"]["install_images"]["value"], False)
        self.assertEqual(rows["installer"]["install_target"]["value"], False)
        self.assertEqual(rows["installer"]["install_images"]["value"], True)
        self.assertEqual(rows["headers"]["image_membership"], "not-established")
        self.assertEqual(rows["installer"]["image_membership"], "not-established")
        self.assertEqual(document["image_membership"], "not-established")

    def test_same_package_stays_in_separate_configurations(self):
        busybox = _target("busybox", version="1.38.0")
        armhf_only = _target(
            "box86-armhf",
            package_dir="/fixture/zlyme/package/system/box86-armhf",
            version="bb716a2a",
        )
        document = _document(
            {
                "armhf": {"box86-armhf": armhf_only, "busybox": busybox},
                "minimal": {"busybox": busybox},
                "product": {"busybox": busybox},
            },
            [_static("box86-armhf")],
        )
        busy = [
            item["configuration"]
            for item in document["packages"]
            if item["buildroot_name"] == "busybox"
        ]
        arm = [
            item
            for item in document["packages"]
            if item["buildroot_name"] == "box86-armhf"
        ]
        self.assertEqual(busy, ["armhf", "minimal", "product"])
        self.assertEqual(len(arm), 1)
        self.assertEqual(arm[0]["configuration"], "armhf")
        self.assertEqual(arm[0]["static_match"]["recipe"], "box86-armhf")
        self.assertEqual(
            [item["configuration"] for item in document["packages"] if item["buildroot_name"] == "busybox"],
            sorted(busy),
        )

    def test_missing_metadata_manifest_and_unknown_license(self):
        document = _document(
            {
                "product": {
                    "bare": {"type": "target"},
                    "portmaster-rocknix-compat": _target(
                        "portmaster-rocknix-compat",
                        licenses="MIT",
                        package_dir="/fixture/zlyme/package/system/portmaster-rocknix-compat",
                    ),
                    "zlyme-armhf-runtime": _target(
                        "zlyme-armhf-runtime",
                        package_dir="/fixture/zlyme/package/system/zlyme-armhf-runtime",
                        version="missing",
                    ),
                }
            },
            [
                _static(
                    "portmaster-rocknix-compat",
                    license=dict(UNKNOWN),
                ),
                _static("zlyme-armhf-runtime", version=dict(SHELL_VERSION)),
            ],
        )
        rows = {item["buildroot_name"]: item for item in document["packages"]}
        self.assertEqual(rows["bare"]["version"]["status"], "absent")
        self.assertEqual(rows["bare"]["licenses"]["status"], "absent")
        self.assertEqual(rows["bare"]["downloads"]["status"], "absent")
        self.assertEqual(rows["bare"]["dependencies"]["status"], "absent")
        runtime = rows["zlyme-armhf-runtime"]["version"]
        self.assertEqual(runtime["status"], "unavailable")
        self.assertIsNone(runtime["resolved"])
        self.assertEqual(runtime["show_info"], "missing")
        self.assertEqual(runtime["static"], SHELL_VERSION)
        self.assertEqual(
            document["armhf_runtime_manifest"]["installed_version_evidence"],
            "unavailable",
        )
        self.assertEqual(
            rows["portmaster-rocknix-compat"]["static_match"]["license"], UNKNOWN
        )
        self.assertEqual(
            rows["portmaster-rocknix-compat"]["licenses"]["value"], "MIT"
        )
        self.assertEqual(document["graphs"]["armhf"]["status"], "not-provided")

    def test_host_manifest_digest_is_not_the_show_info_version(self):
        document = _document(
            {
                "product": {
                    "zlyme-armhf-runtime": _target(
                        "zlyme-armhf-runtime",
                        package_dir="/fixture/zlyme/package/system/zlyme-armhf-runtime",
                        version="missing",
                    )
                }
            },
            [_static("zlyme-armhf-runtime", version=dict(SHELL_VERSION))],
            manifest={
                "host_output": {"digest": "abc", "status": "present"},
                "installed_version_evidence": "host-output-only",
                "recipe_path": {"digest": None, "status": "absent"},
            },
        )
        version = document["packages"][0]["version"]
        self.assertEqual(version["status"], "unavailable")
        self.assertIsNone(version["resolved"])
        self.assertEqual(version["show_info"], "missing")
        self.assertIn("not used as this version", version["reason"])
        self.assertEqual(
            document["armhf_runtime_manifest"]["installed_version_evidence"],
            "host-output-only",
        )

    def test_ambiguous_identity_is_not_merged(self):
        document = _document(
            {
                "product": {
                    "host-widget": {
                        "name": "widget",
                        "package_dir": "/fixture/zlyme/package/system/widget",
                        "type": "host",
                        "version": "1",
                        "virtual": False,
                    }
                }
            },
            [_static("widget"), _static("host-widget")],
        )
        match = document["packages"][0]["static_match"]
        self.assertEqual(match["status"], "ambiguous")
        self.assertEqual(match["candidates"], ["host-widget", "widget"])
        self.assertNotIn("license", match)
        self.assertNotIn("hashes", match)

    def test_buildroot_name_collision_is_ambiguous(self):
        document = _document(
            {"product": {"busybox": _target("busybox")}},
            [_static("busybox")],
        )
        match = document["packages"][0]["static_match"]
        self.assertEqual(match["status"], "ambiguous")
        self.assertEqual(match["candidates"], ["busybox"])

    def test_unresolved_expression_remains_beside_resolved_value(self):
        document = _document(
            {
                "product": {
                    "widget": _target(
                        "widget",
                        package_dir="/fixture/zlyme/package/system/widget",
                        version="1.2.3",
                    )
                }
            },
            [
                _static(
                    "widget",
                    version={"kind": "unresolved", "value": "$(call github,example,widget,v1)"},
                )
            ],
        )
        version = document["packages"][0]["version"]
        self.assertEqual(version["status"], "resolved")
        self.assertEqual(version["resolved"], "1.2.3")
        self.assertEqual(version["static"]["value"], "$(call github,example,widget,v1)")

    def test_output_is_deterministic(self):
        graphs = {
            "minimal": {"zeta": _target("zeta"), "alpha": _target("alpha")},
            "product": {"alpha": _target("alpha")},
        }
        first = _document(graphs, [])
        second = _document(graphs, [])
        self.assertEqual(first, second)
        encoded = json.dumps(first, indent=2, sort_keys=True)
        self.assertEqual(encoded, json.dumps(json.loads(encoded), indent=2, sort_keys=True))
        self.assertEqual(
            [item["buildroot_name"] for item in first["packages"]],
            ["alpha", "zeta", "alpha"],
        )
        self.assertEqual(
            [item["configuration"] for item in first["packages"]],
            ["minimal", "minimal", "product"],
        )

    def test_incompatible_buildroot_is_refused(self):
        with self.assertRaises(inv.IncompatibleBuildroot):
            inv.assert_compatible("2025.02", "2026.08")
        with self.assertRaises(inv.IncompatibleBuildroot):
            _document({"product": {}}, [], describe="2026.02")

    def test_show_info_parser_ignores_make_banners(self):
        text = "make: Entering directory '/tmp/buildroot'\n{\"busybox\": {\"type\": \"target\"}} \nmake: Leaving directory '/tmp/buildroot'\n"
        self.assertEqual(inv.parse_show_info(text), {"busybox": {"type": "target"}})
        with self.assertRaises(ValueError):
            inv.parse_show_info("make: *** No rule to make target 'show-info'.\n")

    def _assert_disposable(self, path):
        repo = Path(__file__).resolve().parents[2]
        resolved = path.resolve()
        self.assertFalse(resolved.is_relative_to(repo.resolve()))
        self.assertTrue(Path(__file__).is_file())
        return repo

    def test_configuration_removes_only_its_directory(self):
        sandbox = Path(tempfile.mkdtemp(prefix="zlyme-cleanup-sandbox-"))
        self._assert_disposable(sandbox)
        owned = []
        kept = []

        def fake_run(cmd, **kwargs):
            output = next(Path(arg[2:]) for arg in cmd if str(arg).startswith("O="))
            work = output.parent
            if not owned:
                owned.append(work)
                (work / "escape").symlink_to(sandbox / "outside", target_is_directory=True)
                sibling = work.parent / ("%s-sibling" % work.name)
                sibling.mkdir()
                (sibling / "sentinel").write_text("keep", encoding="utf-8")
                decoy = work.parent / ("zlyme-configured-decoy-%s" % work.name)
                decoy.mkdir()
                (decoy / "sentinel").write_text("keep", encoding="utf-8")
                kept.extend((sibling, decoy))
            if str(cmd[-1]).endswith("_defconfig"):
                return inv.subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
            self.assertEqual(cmd[-1], "show-info")
            return inv.subprocess.CompletedProcess(
                cmd, 0, stdout='{"busybox": {"type": "target"}}\n', stderr=""
            )

        try:
            unrelated = sandbox / "unrelated"
            unrelated.mkdir()
            (unrelated / "sentinel").write_text("keep", encoding="utf-8")
            outside = sandbox / "outside"
            outside.mkdir()
            (outside / "sentinel").write_text("keep", encoding="utf-8")
            with mock.patch.object(inv.subprocess, "run", side_effect=fake_run):
                graphs = inv.collect_graphs(Path("/fixture/zlyme"), Path("/fixture/buildroot"))
            self.assertEqual(set(graphs), {"armhf", "minimal", "product"})
            self.assertEqual(len(owned), 1)
            work = owned[0]
            self.assertFalse(work.exists())
            self.assertTrue((unrelated / "sentinel").is_file())
            self.assertTrue((outside / "sentinel").is_file())
            self.assertEqual(len(kept), 2)
            for path in kept:
                self.assertTrue((path / "sentinel").is_file())
                self._assert_disposable(path)
            repo = Path(__file__).resolve().parents[2]
            self.assertFalse(repo.resolve() in work.parents)
            self.assertTrue(Path(__file__).is_file())
        finally:
            shutil.rmtree(sandbox)
            for path in kept:
                if path.exists():
                    shutil.rmtree(path)

    def test_configuration_cleans_up_after_failure(self):
        sandbox = Path(tempfile.mkdtemp(prefix="zlyme-cleanup-sandbox-"))
        self._assert_disposable(sandbox)
        owned = []

        def fake_run(cmd, **kwargs):
            output = next(Path(arg[2:]) for arg in cmd if str(arg).startswith("O="))
            work = output.parent
            owned.append(work)
            decoy = work.parent / ("zlyme-configured-decoy-%s" % work.name)
            if not decoy.exists():
                decoy.mkdir()
                (decoy / "sentinel").write_text("keep", encoding="utf-8")
            sibling = work.parent / ("%s-sibling" % work.name)
            if not sibling.exists():
                sibling.mkdir()
                (sibling / "sentinel").write_text("keep", encoding="utf-8")
            raise inv.subprocess.CalledProcessError(1, cmd)

        try:
            with self.assertRaises(inv.subprocess.CalledProcessError):
                with mock.patch.object(inv.subprocess, "run", side_effect=fake_run):
                    inv.collect_graphs(Path("/fixture/zlyme"), Path("/fixture/buildroot"))
            self.assertEqual(len(owned), 1)
            work = owned[0]
            self.assertFalse(work.exists())
            decoy = work.parent / ("zlyme-configured-decoy-%s" % work.name)
            sibling = work.parent / ("%s-sibling" % work.name)
            self.assertTrue((decoy / "sentinel").is_file())
            self.assertTrue((sibling / "sentinel").is_file())
            self.assertTrue(Path(__file__).is_file())
        finally:
            if sandbox.exists():
                shutil.rmtree(sandbox)
            if owned:
                work = owned[0]
                for path in (
                    work.parent / ("zlyme-configured-decoy-%s" % work.name),
                    work.parent / ("%s-sibling" % work.name),
                ):
                    if path.exists():
                        shutil.rmtree(path)

    def test_symlink_manifest_is_not_installed_evidence(self):
        parent = Path(tempfile.mkdtemp(prefix="zlyme-manifest-"))
        try:
            target = parent / "real.manifest"
            target.write_text(
                "format=1\ndefconfig=zlyme_my355_armhf_defconfig\n",
                encoding="utf-8",
            )
            link = parent / "zlyme-armhf-runtime.manifest"
            link.symlink_to(target)
            record = inv._recognized_manifest(link)
            self.assertEqual(record["status"], "symlink")
            self.assertIsNone(record["digest"])
            self.assertTrue(target.is_file())
        finally:
            shutil.rmtree(parent)


if __name__ == "__main__":
    unittest.main()
