#!/usr/bin/env python3
"""The pre-publication gate fails closed on a missing or corrupt asset."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT = os.path.join(ROOT, "scripts", "check-release-assets.py")
SHA = "a" * 40


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        h.update(handle.read())
    return h.hexdigest()


def sidecar(path):
    name = os.path.basename(path)
    with open(path + ".sha256", "w", encoding="utf-8") as handle:
        handle.write("%s  %s\n" % (digest(path), name))


def blob(path, text):
    with open(path, "wb") as handle:
        handle.write(text.encode("utf-8"))


class GateTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.mkdtemp(prefix="zlyme-release-assets-")
        self.images = os.path.join(self.work, "images")
        os.makedirs(self.images)
        self.notes = os.path.join(self.work, "notes.md")
        with open(self.notes, "w", encoding="utf-8") as handle:
            handle.write("## [zlyme44.5]\n\n- A change.\n")
        self.version = os.path.join(self.work, "ZLYME_VERSION")
        with open(self.version, "w", encoding="utf-8") as handle:
            handle.write("zlyme44.5\n")
        self._good()

    def tearDown(self):
        shutil.rmtree(self.work)

    def _good(self):
        stage = os.path.join(self.work, "stage")
        os.makedirs(stage)
        for name in (
            "zlyme",
            "Image.gz",
            "rk3566-miyoo-flip.dtb",
            "idbloader.img",
            "u-boot.itb",
        ):
            blob(os.path.join(stage, name), name + "-bytes")
        blob(os.path.join(stage, "VERSION"), "abc123def456\n20261118\n")
        tar_name = "zlyme-my355-20261118-abc123def456.tar"
        tar_path = os.path.join(self.images, tar_name)
        with tarfile.open(tar_path, "w") as archive:
            for name in sorted(os.listdir(stage)):
                archive.add(os.path.join(stage, name), arcname=name)
        sidecar(tar_path)
        for name in (
            "zlyme.img",
            "miyoo355_fw.img",
            "miyoo355_fw-multiboot.img",
            "miyoo355_fw-maskrom.img",
            "miyoo355_fw-restore.img",
        ):
            path = os.path.join(self.images, name)
            blob(path, name)
            sidecar(path)
        root = os.path.join(stage, "zlyme")
        manifest = {
            "schema": 1,
            "device": "my355",
            "version": "zlyme44.5",
            "source_sha": SHA,
            "root": {"sha256": digest(root), "size": os.path.getsize(root)},
            "full": {
                "file": tar_name,
                "sha256": digest(tar_path),
                "size": os.path.getsize(tar_path),
            },
            "deltas": [],
        }
        with open(os.path.join(self.images, "release-manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(manifest, handle)
        self.tar_path = tar_path
        self.manifest = manifest

    def run_gate(self):
        return subprocess.run(
            [
                sys.executable,
                SCRIPT,
                "--images-dir",
                self.images,
                "--version-file",
                self.version,
                "--source-sha",
                SHA,
                "--notes",
                self.notes,
            ],
            capture_output=True,
            text=True,
        )

    def test_accepts_a_complete_set(self):
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release assets ok", result.stdout)

    def test_missing_image_fails(self):
        os.remove(os.path.join(self.images, "zlyme.img"))
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_empty_image_fails(self):
        open(os.path.join(self.images, "zlyme.img"), "wb").close()
        sidecar(os.path.join(self.images, "zlyme.img"))
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_bad_checksum_fails(self):
        with open(self.tar_path + ".sha256", "w", encoding="utf-8") as handle:
            handle.write("%s  %s\n" % ("b" * 64, os.path.basename(self.tar_path)))
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_wrong_manifest_version_fails(self):
        self.manifest["version"] = "zlyme44.4"
        with open(os.path.join(self.images, "release-manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(self.manifest, handle)
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_wrong_source_sha_fails(self):
        self.manifest["source_sha"] = "b" * 40
        with open(os.path.join(self.images, "release-manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(self.manifest, handle)
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_root_hash_mismatch_fails(self):
        self.manifest["root"]["sha256"] = "c" * 64
        with open(os.path.join(self.images, "release-manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(self.manifest, handle)
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_missing_delta_fails(self):
        self.manifest["deltas"] = [
            {
                "from_version": "zlyme44.4",
                "from_sha256": "d" * 64,
                "file": "zlyme-my355-delta-zlyme44.4-dddddddddddd.tar",
                "sha256": "e" * 64,
                "size": 4,
            }
        ]
        with open(os.path.join(self.images, "release-manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(self.manifest, handle)
        self.assertNotEqual(self.run_gate().returncode, 0)

    def test_notes_from_another_release_fail(self):
        with open(self.notes, "w", encoding="utf-8") as handle:
            handle.write("## [zlyme44.5]\n\n- A change.\n\n## [Unreleased]\n")
        self.assertNotEqual(self.run_gate().returncode, 0)


if __name__ == "__main__":
    unittest.main()
