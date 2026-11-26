#!/usr/bin/env python3
"""Parser tests for the external package inventory."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location(
    "inventory_packages", ROOT / "scripts" / "inventory-packages.py"
)
inv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(inv)


def _write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _fixture():
    """Build a tree with one recipe for each inventory case."""
    tmp = tempfile.TemporaryDirectory()
    root = Path(tmp.name)
    _write(
        root / "package/releasepkg/releasepkg.mk",
        "RELEASEPKG_VERSION = 1.2.3\n"
        "RELEASEPKG_SITE = https://example.invalid/releasepkg\n"
        "RELEASEPKG_SOURCE = releasepkg-1.2.3.tar.gz\n"
        "RELEASEPKG_LICENSE = MIT\n"
        "RELEASEPKG_LICENSE_FILES = LICENSE\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/releasepkg/releasepkg.hash",
        "sha256  aaaa  releasepkg-1.2.3.tar.gz\n",
    )
    _write(
        root / "package/releasepkg/Config.in",
        "config BR2_PACKAGE_RELEASEPKG\n\tbool \"releasepkg\"\n",
    )
    _write(
        root / "package/gitpkg/gitpkg.mk",
        "GITPKG_VERSION = 0123456789abcdef0123456789abcdef01234567\n"
        "GITPKG_SITE = https://example.invalid/gitpkg.git\n"
        "GITPKG_SITE_METHOD = git\n"
        "GITPKG_LICENSE = GPL-2.0-only\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/gitpkg/Config.in",
        "config BR2_PACKAGE_GITPKG\n\tbool \"gitpkg\"\n",
    )
    _write(
        root / "package/archivepkg/archivepkg.mk",
        "ARCHIVEPKG_VERSION = fedcba9876543210fedcba9876543210fedcba98\n"
        "ARCHIVEPKG_SITE = https://example.invalid/archivepkg/archive\n"
        "ARCHIVEPKG_SOURCE = $(ARCHIVEPKG_VERSION).tar.gz\n"
        "ARCHIVEPKG_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/archivepkg/archivepkg.hash",
        "# not a release version\n"
        "sha256  bbbbccccddddeeeeffff0000111122223333444455556666777788889999aaaa  "
        "fedcba9876543210fedcba9876543210fedcba98.tar.gz\n",
    )
    _write(
        root / "package/patched/patched.mk",
        "PATCHED_VERSION = 2.0\n"
        "PATCHED_SITE = https://example.invalid/patched\n"
        "PATCHED_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(root / "package/patched/0001-local.patch", "diff --git a/a b/a\n")
    _write(
        root / "package/nohash/nohash.mk",
        "NOHASH_VERSION = 3\n"
        "NOHASH_SITE = https://example.invalid/nohash\n"
        "NOHASH_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/licensed/licensed.mk",
        "LICENSED_VERSION = 1.4\n"
        "LICENSED_SOURCE = licensed-1.4.tar.gz\n"
        "LICENSED_LICENSE = MIT\n"
        "LICENSED_LICENSE_FILES = LICENSE COPYING\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/licensed/licensed.hash",
        "sha256  1111111111111111111111111111111111111111111111111111111111111111  licensed-1.4.tar.gz\n"
        "sha256  2222222222222222222222222222222222222222222222222222222222222222  LICENSE\n"
        "sha256  3333333333333333333333333333333333333333333333333333333333333333  COPYING\n"
        "sha256  4444444444444444444444444444444444444444444444444444444444444444  README\n"
        "this is not a hash line\n",
    )
    _write(
        root / "package/brokenhash/brokenhash.mk",
        "BROKENHASH_VERSION = 1\n"
        "BROKENHASH_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/brokenhash/brokenhash.hash",
        "sha256  abc\n",
    )
    _write(
        root / "package/deferred/deferred.mk",
        "DEFERRED_VERSION := 9.9.9\n"
        "DEFERRED_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/unknownlic/unknownlic.mk",
        "UNKNOWNLIC_VERSION = 1\n"
        "UNKNOWNLIC_SITE_METHOD = local\n"
        "UNKNOWNLIC_LICENSE = LicenseRef-example-unspecified\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/armhfonly/armhfonly.mk",
        "ARMHFONLY_VERSION = 1\n"
        "ARMHFONLY_SITE_METHOD = local\n"
        "ARMHFONLY_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/armhfonly/Config.in",
        "config BR2_PACKAGE_ARMHFONLY\n\tbool \"armhfonly\"\n",
    )
    _write(
        root / "package/hostonly/hostonly.mk",
        "HOSTONLY_VERSION = 1.0\n"
        "HOSTONLY_SITE = https://example.invalid/hostonly\n"
        "HOSTONLY_LICENSE = MIT\n"
        "$(eval $(host-generic-package))\n",
    )
    _write(
        root / "package/dynamic/dynamic.mk",
        "DYNAMIC_VERSION = $(shell echo missing)\n"
        "DYNAMIC_SITE_METHOD = local\n"
        "DYNAMIC_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/branchurl/branchurl.mk",
        "BRANCHURL_VERSION = 1.0.0\n"
        "BRANCHURL_SITE = https://example.invalid/packages/raw/main\n"
        "BRANCHURL_SOURCE = branchurl.tar.gz\n"
        "BRANCHURL_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "package/floating/floating.mk",
        "FLOATING_VERSION = main\n"
        "FLOATING_SITE = https://example.invalid/floating.git\n"
        "FLOATING_SITE_METHOD = git\n"
        "FLOATING_LICENSE = MIT\n"
        "$(eval $(generic-package))\n",
    )
    _write(
        root / "configs/zlyme_my355_defconfig",
        "BR2_PACKAGE_RELEASEPKG=y\n",
    )
    _write(root / "configs/zlyme_my355_minimal_defconfig", "")
    _write(
        root / "configs/zlyme_my355_armhf_defconfig",
        "BR2_PACKAGE_ARMHFONLY=y\n"
        "BR2_PACKAGE_UPSTREAM_ONLY=y\n",
    )
    return tmp, root


class FixtureTests(unittest.TestCase):
    def setUp(self):
        self.tmp, self.root = _fixture()
        self.data = inv.inventory(self.root)
        self.by_name = {item["name"]: item for item in self.data["packages"]}

    def tearDown(self):
        self.tmp.cleanup()

    def test_release_version_and_archive_hash(self):
        item = self.by_name["releasepkg"]
        self.assertEqual(item["version"], {"kind": "release", "value": "1.2.3"})
        self.assertEqual(item["hash_status"], "present")
        self.assertEqual(item["hashes"][0]["value"], "aaaa")
        self.assertEqual(item["hashes"][0]["filename"], "releasepkg-1.2.3.tar.gz")
        self.assertEqual(item["hashes"][0]["role"], "source-archive")
        self.assertEqual(item["unparsed_hash_lines"], [])
        self.assertEqual(item["license"]["status"], "declared")
        self.assertEqual(item["direct_defconfig_selection"], ["product"])
        self.assertEqual(item["shipped"], "not-established")

    def test_git_commit_is_not_a_release(self):
        item = self.by_name["gitpkg"]
        self.assertEqual(item["version"]["kind"], "git-commit")
        self.assertEqual(
            item["version"]["value"],
            "0123456789abcdef0123456789abcdef01234567",
        )
        self.assertEqual(item["hash_status"], "absent")
        self.assertEqual(item["hashes"], [])
        self.assertEqual(item["version_authority"], "pinned-commit")

    def test_archive_hash_stays_distinct_from_the_commit(self):
        item = self.by_name["archivepkg"]
        self.assertEqual(item["version"]["kind"], "git-commit")
        self.assertEqual(item["source"]["status"], "unresolved")
        self.assertNotEqual(item["hashes"][0]["value"], item["version"]["value"])
        self.assertEqual(item["hashes"][0]["role"], "source-archive")
        self.assertEqual(len(item["hashes"][0]["value"]), 64)

    def test_local_patch_is_recorded(self):
        item = self.by_name["patched"]
        self.assertEqual(item["patches"], ["0001-local.patch"])

    def test_hash_roles_and_malformed_lines(self):
        item = self.by_name["licensed"]
        roles = {row["filename"]: row["role"] for row in item["hashes"]}
        self.assertEqual(roles["licensed-1.4.tar.gz"], "source-archive")
        self.assertEqual(roles["LICENSE"], "license-file")
        self.assertEqual(roles["COPYING"], "license-file")
        self.assertEqual(roles["README"], "unclassified")
        self.assertEqual(item["hash_status"], "present")
        self.assertEqual(item["unparsed_hash_lines"], [{"line": 5, "text": "this is not a hash line"}])
        self.assertTrue(item["hashes"][0]["evidence"].endswith("licensed.hash"))
        broken = self.by_name["brokenhash"]
        self.assertEqual(broken["hash_status"], "unparsed")
        self.assertEqual(broken["hashes"], [])
        self.assertEqual(broken["unparsed_hash_lines"][0]["line"], 1)

    def test_alternate_assignment_is_not_invented(self):
        item = self.by_name["deferred"]
        self.assertEqual(item["version"]["kind"], "absent")

    def test_missing_hash_stays_absent(self):
        item = self.by_name["nohash"]
        self.assertEqual(item["hash_status"], "absent")
        self.assertEqual(item["hashes"], [])

    def test_unknown_license_is_not_replaced(self):
        item = self.by_name["unknownlic"]
        self.assertEqual(item["license"]["declared"], "LicenseRef-example-unspecified")
        self.assertEqual(item["license"]["status"], "deliberately-unknown")

    def test_armhf_selection_and_upstream_symbol(self):
        item = self.by_name["armhfonly"]
        self.assertEqual(item["direct_defconfig_selection"], ["armhf"])
        self.assertIn(
            "BR2_PACKAGE_UPSTREAM_ONLY",
            self.data["unmatched_defconfig_packages"]["armhf"],
        )
        self.assertNotIn("armhfonly", [pkg["name"] for pkg in self.data["packages"] if "UPSTREAM" in pkg["name"]])

    def test_host_only_package(self):
        item = self.by_name["hostonly"]
        self.assertEqual(item["provides"], "host")
        self.assertEqual(item["direct_defconfig_selection"], [])

    def test_dynamic_version_is_unresolved(self):
        item = self.by_name["dynamic"]
        self.assertEqual(item["version"]["kind"], "unresolved")
        self.assertEqual(item["version"]["value"], "$(shell echo missing)")

    def test_branch_url_is_not_a_fixed_release(self):
        item = self.by_name["branchurl"]
        self.assertEqual(item["version"], {"kind": "release", "value": "1.0.0"})
        self.assertEqual(item["site_pin"], "floating-branch")
        self.assertEqual(item["version_authority"], "floating-branch")
        self.assertEqual(item["hash_status"], "absent")

    def test_floating_branch(self):
        item = self.by_name["floating"]
        self.assertEqual(item["version"]["kind"], "floating-branch")
        self.assertEqual(item["version_authority"], "floating-branch")

    def test_output_is_sorted_and_stable(self):
        names = [item["name"] for item in self.data["packages"]]
        self.assertEqual(names, sorted(names))
        again = inv.inventory(self.root)
        self.assertEqual(self.data, again)
        encoded = json.dumps(self.data, indent=2, sort_keys=True)
        self.assertEqual(encoded, json.dumps(again, indent=2, sort_keys=True))


class RepositoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = inv.inventory(ROOT)
        cls.by_name = {item["name"]: item for item in cls.data["packages"]}

    def test_show_info_is_not_run(self):
        info = self.data["buildroot"]["show_info"]
        self.assertFalse(info["invoked"])
        self.assertTrue(info["target_present"])
        self.assertEqual(self.data["buildroot"]["pinned_version"], "2026.08")

    def test_recipe_count_matches_the_tree(self):
        count = 0
        for makefile in (ROOT / "package").rglob("*.mk"):
            if makefile.stem != makefile.parent.name:
                continue
            text = makefile.read_text(encoding="utf-8")
            if "$(eval $(" in text and "-package))" in text:
                count += 1
        self.assertEqual(len(self.data["packages"]), count)
        self.assertGreater(count, 80)

    def test_installer_commit_and_archive_hash(self):
        item = self.by_name["my355-fw-installer"]
        self.assertEqual(
            item["version"]["value"],
            "e09d37bb0f03c34e564d61bd02164f332d8515a8",
        )
        self.assertEqual(item["version"]["kind"], "git-commit")
        self.assertEqual(item["site"]["value"], "https://github.com/apommel/FlipBase/archive")
        digest = "49d103c5f6ff8c56d234f51553bad00c5b204ed74f3044e36f56b3c5b9b0871e"
        self.assertIn(digest, [row["value"] for row in item["hashes"]])
        self.assertEqual(
            [row["role"] for row in item["hashes"] if row["value"] == digest],
            ["source-archive"],
        )
        self.assertNotEqual(digest, item["version"]["value"])
        self.assertEqual(item["license"]["declared"], "MIT")
        self.assertEqual(item["license"]["status"], "declared")
        self.assertEqual(item["shipped"], "not-established")
        self.assertIn("product", item["direct_defconfig_selection"])
        self.assertIn("minimal", item["direct_defconfig_selection"])

    def test_nextui_commit_and_patch(self):
        item = self.by_name["nextui"]
        self.assertEqual(item["version"]["kind"], "git-commit")
        self.assertEqual(
            item["version"]["value"],
            "3aff9c42777bf69ff476601b7011b05f753ba8cd",
        )
        self.assertIn("0001-logs-take-effect-on-next-boot.patch", item["patches"])
        self.assertEqual(item["dependency_closure"], "not-computed")

    def test_unknown_licenses_stay_unspecified(self):
        rocknix = self.by_name["portmaster-rocknix-compat"]
        self.assertEqual(
            rocknix["license"]["declared"],
            "LicenseRef-ROCKNIX-portmaster-compat-unspecified",
        )
        self.assertEqual(rocknix["license"]["status"], "deliberately-unknown")
        preloader = self.by_name["zlyme-preloader"]
        self.assertIn(
            "LicenseRef-Miyoo-vendor-preloader-unspecified",
            preloader["license"]["declared"],
        )
        self.assertEqual(preloader["license"]["status"], "deliberately-unknown")

    def test_armhf_runtime_version_is_not_executed(self):
        item = self.by_name["zlyme-armhf-runtime"]
        self.assertEqual(item["version"]["kind"], "unresolved")
        self.assertIn("$(shell", item["version"]["value"])
        self.assertIn("product", item["direct_defconfig_selection"])
        box = self.by_name["box86-armhf"]
        self.assertEqual(box["version"]["kind"], "git-commit")
        self.assertEqual(box["site"]["status"], "unresolved")
        self.assertIn("$(call github", box["site"]["value"])
        self.assertEqual(box["direct_defconfig_selection"], ["armhf"])
        self.assertEqual(self.by_name["aethersx2"]["version"]["value"], "1.0.0")
        self.assertEqual(self.by_name["aethersx2"]["site_pin"], "floating-branch")
        self.assertEqual(
            self.by_name["aethersx2"]["version_authority"], "floating-branch"
        )
        theora = self.by_name["portmaster-theora-compat"]
        theora_roles = {row["filename"]: row["role"] for row in theora["hashes"]}
        self.assertEqual(theora_roles["libtheora-1.1.1.tar.xz"], "source-archive")
        self.assertEqual(theora_roles["COPYING"], "license-file")
        self.assertEqual(theora_roles["LICENSE"], "license-file")
        self.assertNotEqual(
            theora["version"]["value"],
            theora_roles and next(
                row["value"]
                for row in theora["hashes"]
                if row["role"] == "source-archive"
            ),
        )
        self.assertIn(
            "474bf47f4f03d40f0c664578c9eee90f29eaf3d25f5d86ffe4e50c603a44eaa6",
            [
                row["value"]
                for row in box["hashes"]
                if row["role"] == "source-archive"
            ],
        )
        self.assertEqual(
            [
                row["role"]
                for row in box["hashes"]
                if row["filename"] == "LICENSE"
            ],
            ["license-file"],
        )
        plumber = self.by_name["inputplumber"]
        self.assertEqual(
            [
                row["role"]
                for row in plumber["hashes"]
                if row["filename"].endswith("-git4-cargo6.tar.gz")
            ],
            ["source-archive"],
        )

    def test_upstream_buildroot_package_is_not_invented(self):
        self.assertNotIn("mesa3d", self.by_name)
        self.assertIn(
            "BR2_PACKAGE_MESA3D",
            self.data["unmatched_defconfig_packages"]["product"],
        )

    def test_defconfig_literals(self):
        literals = {
            (item["source"], item["key"]): item["value"]
            for item in self.data["defconfig_literals"]
        }
        self.assertEqual(
            literals[("configs/zlyme_my355_defconfig", "BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE")],
            "7.2.10",
        )
        self.assertEqual(
            literals[("configs/zlyme_my355_defconfig", "BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE")],
            "2026.01",
        )

    def test_cli_is_deterministic(self):
        command = [sys.executable, str(ROOT / "scripts/inventory-packages.py")]
        first = subprocess.check_output(command, cwd=ROOT)
        second = subprocess.check_output(command, cwd=ROOT)
        self.assertEqual(first, second)
        parsed = json.loads(first)
        self.assertEqual(parsed["schema"], inv.SCHEMA)
        self.assertFalse(parsed["buildroot"]["show_info"]["invoked"])


if __name__ == "__main__":
    unittest.main()
