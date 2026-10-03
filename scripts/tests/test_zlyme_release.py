#!/usr/bin/env python3
import importlib.util
import io
import os
import sys
import tarfile
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import zlyme_release as rel  # noqa: E402


def _load_github_release():
    path = os.path.join(
        ROOT, "package", "system", "nextui", "zlyme", "github-release.py"
    )
    spec = importlib.util.spec_from_file_location("github_release", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VersionTests(unittest.TestCase):
    def test_baseline_and_point(self):
        self.assertEqual(rel.parse_version("zlyme43"), (43, None))
        self.assertTrue(rel.is_baseline("zlyme43"))
        self.assertEqual(rel.parse_version("zlyme43.1"), (43, 1))
        self.assertEqual(rel.parse_version("zlyme43.12"), (43, 12))
        self.assertFalse(rel.is_baseline("zlyme43.12"))

    def test_reject(self):
        for bad in ("zlyme43.0", "zlyme43.", "43", "zlyme43-beta", "zlyme43.1.2", ""):
            with self.assertRaises(rel.ReleaseError):
                rel.parse_version(bad)

    def test_eligible_history(self):
        published = [
            "zlyme43",
            "zlyme43.1",
            "zlyme43.5",
            "zlyme43.6",
            "zlyme43.7",
            "zlyme44",
            "not-a-version",
        ]
        self.assertEqual(rel.eligible_base_versions("zlyme43", published), [])
        self.assertEqual(
            rel.eligible_base_versions("zlyme43.8", published),
            ["zlyme43", "zlyme43.5", "zlyme43.6", "zlyme43.7"],
        )
        self.assertEqual(
            rel.eligible_base_versions("zlyme43.2", ["zlyme43", "zlyme43.1"]),
            ["zlyme43", "zlyme43.1"],
        )

    def test_cutoff(self):
        self.assertTrue(rel.under_cutoff(69, 100))
        self.assertFalse(rel.under_cutoff(70, 100))
        self.assertFalse(rel.under_cutoff(90, 100))


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.manifest = {
            "schema": 1,
            "device": "my355",
            "version": "zlyme43.1",
            "source_sha": "abc",
            "root": {"sha256": "a" * 64, "size": 10},
            "full": {"file": "full.tar", "sha256": "b" * 64, "size": 100},
            "deltas": [
                {
                    "from_version": "zlyme43",
                    "from_sha256": "c" * 64,
                    "file": "delta-big.tar",
                    "sha256": "d" * 64,
                    "size": 40,
                },
                {
                    "from_version": "zlyme43",
                    "from_sha256": "e" * 64,
                    "file": "delta-small.tar",
                    "sha256": "f" * 64,
                    "size": 10,
                },
            ],
        }

    def test_exact_hash_selects_smallest_delta(self):
        kind, chosen = rel.choose_transport(self.manifest, "e" * 64)
        self.assertEqual(kind, "delta")
        self.assertEqual(chosen["file"], "delta-small.tar")

    def test_other_hash_selects_full(self):
        kind, chosen = rel.choose_transport(self.manifest, "1" * 64)
        self.assertEqual(kind, "full")
        self.assertEqual(chosen["file"], "full.tar")

    def test_github_helper_matches(self):
        gh = _load_github_release()
        gh._UPDATE_PREFIX["v"] = "zlyme-my355-"
        self.assertTrue(gh.manifest_ok(self.manifest))
        kind, chosen = gh.choose_transport(self.manifest, "c" * 64)
        self.assertEqual(kind, "delta")
        self.assertEqual(chosen["file"], "delta-big.tar")
        kind, chosen = gh.choose_transport(self.manifest, "0" * 64)
        self.assertEqual(kind, "full")
        self.assertTrue(gh.is_legacy_full_tar("zlyme-my355-20260930-abc.tar"))
        self.assertFalse(gh.is_legacy_full_tar("zlyme-my355-delta-zlyme43.tar"))
        self.assertFalse(
            gh.is_legacy_full_tar(
                "zlyme-my355-delta-zlyme43-0123456789ab.tar"
            )
        )


class DeltaRoundTripTests(unittest.TestCase):
    def test_round_trip_and_wrong_base(self):
        directory = tempfile.mkdtemp()
        old = os.path.join(directory, "old")
        new = os.path.join(directory, "new")
        patch = os.path.join(directory, "patch.zst")
        wrong = os.path.join(directory, "wrong")
        with open(old, "wb") as handle:
            handle.write(b"old-base-content-aaaa\n")
        with open(new, "wb") as handle:
            handle.write(b"old-base-content-aaaa\nnew-line\n")
        with open(wrong, "wb") as handle:
            handle.write(b"different-base\n")
        rel.zstd_patch(old, new, patch)
        self.assertTrue(rel.round_trip_ok(old, new, patch))
        decoded = os.path.join(directory, "bad")
        self.assertNotEqual(rel.zstd_apply(wrong, patch, decoded), 0)
        self.assertFalse(os.path.exists(decoded) and os.path.getsize(decoded) == os.path.getsize(new))

    def test_delta_tar_members(self):
        directory = tempfile.mkdtemp()
        old = os.path.join(directory, "old")
        new = os.path.join(directory, "new")
        full = os.path.join(directory, "full.tar")
        delta = os.path.join(directory, "delta.tar")
        with open(old, "wb") as handle:
            handle.write(b"root-v1")
        with open(new, "wb") as handle:
            handle.write(b"root-v1-plus")
        stage = os.path.join(directory, "stage")
        os.makedirs(os.path.join(stage, "overlays"))
        os.makedirs(os.path.join(stage, "extlinux"))
        for name, body in (
            ("zlyme", b"root-v1-plus"),
            ("Image.gz", b"kernel"),
            ("rk3566-miyoo-flip.dtb", b"dtb"),
            ("idbloader.img", b"idb"),
            ("u-boot.itb", b"itb"),
            ("VERSION", b"abc\n20260930\n"),
            ("pre-update.sh", b"#!/bin/sh\n"),
            ("post-update.sh", b"#!/bin/sh\n"),
            ("splash.anim", b"splash"),
        ):
            with open(os.path.join(stage, name), "wb") as handle:
                handle.write(body)
        with open(os.path.join(stage, "overlays", "x.dtbo"), "wb") as handle:
            handle.write(b"dtbo")
        with tarfile.open(full, "w:") as archive:
            for name in os.listdir(stage):
                archive.add(os.path.join(stage, name), arcname=name)
        fields = {
            "TYPE": "delta",
            "SCHEMA": "1",
            "DEVICE": "my355",
            "FROM_VERSION": "zlyme43",
            "TARGET_VERSION": "zlyme43.1",
            "BASE_SHA256": rel.sha256_file(old),
            "TARGET_SHA256": rel.sha256_file(new),
            "TARGET_SIZE": str(os.path.getsize(new)),
            "PATCH": "zlyme.patch.zst",
        }
        rel.build_delta_tar(full, old, new, delta, fields)
        with tarfile.open(delta, "r:") as archive:
            names = set(archive.getnames())
        self.assertIn("DELTA-MANIFEST", names)
        self.assertIn("zlyme.patch.zst", names)
        self.assertNotIn("zlyme", names)
        self.assertIn("Image.gz", names)
        text = archive_member(delta, "DELTA-MANIFEST")
        parsed = rel.parse_delta_manifest_text(text)
        self.assertEqual(parsed["BASE_SHA256"], fields["BASE_SHA256"])
        with self.assertRaises(rel.ReleaseError):
            rel.parse_delta_manifest_text(text + "EVIL=$(reboot)\n")


class ReleaseWriterTests(unittest.TestCase):
    def _images(self, directory, root):
        stage = os.path.join(directory, "stage")
        os.makedirs(stage)
        with open(os.path.join(stage, "zlyme"), "wb") as handle:
            handle.write(root)
        with open(os.path.join(stage, "Image.gz"), "wb") as handle:
            handle.write(b"kernel")
        with open(os.path.join(stage, "VERSION"), "wb") as handle:
            handle.write(b"v\n")
        images = os.path.join(directory, "images")
        os.makedirs(images)
        full = os.path.join(images, "zlyme-my355-full.tar")
        with tarfile.open(full, "w:") as archive:
            for name in os.listdir(stage):
                archive.add(os.path.join(stage, name), arcname=name)
        return images

    def test_baseline_writes_no_deltas(self):
        spec = importlib.util.spec_from_file_location(
            "make_release_deltas",
            os.path.join(ROOT, "scripts", "make-release-deltas.py"),
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        directory = tempfile.mkdtemp()
        images = self._images(directory, b"baseline-root-bytes\n")
        module._write_release(images, "zlyme43", "abc123", bases=[{"unused": True}])
        with open(os.path.join(images, "release-manifest.json"), "r", encoding="utf-8") as handle:
            data = json_load(handle)
        self.assertEqual(data["deltas"], [])
        self.assertFalse(any(name.startswith("zlyme-my355-delta-") for name in os.listdir(images)))

    def _bases(self, directory, old):
        old_path = os.path.join(directory, "old")
        with open(old_path, "wb") as handle:
            handle.write(old)
        return [
            {
                "version": "zlyme43",
                "root_path": old_path,
                "root_sha256": rel.sha256_file(old_path),
            }
        ]

    def test_point_omits_delta_at_cutoff(self):
        spec = importlib.util.spec_from_file_location(
            "make_release_deltas_omit",
            os.path.join(ROOT, "scripts", "make-release-deltas.py"),
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        directory = tempfile.mkdtemp()
        images = self._images(directory, b"tiny-new\n")
        module._write_release(images, "zlyme43.1", "abc123", self._bases(directory, b"tiny-old\n"))
        with open(os.path.join(images, "release-manifest.json"), "r", encoding="utf-8") as handle:
            data = json_load(handle)
        self.assertEqual(data["deltas"], [])
        self.assertFalse(any("-delta-" in name and name.endswith(".tar") for name in os.listdir(images)))

    def test_point_publishes_a_small_delta(self):
        spec = importlib.util.spec_from_file_location(
            "make_release_deltas_keep",
            os.path.join(ROOT, "scripts", "make-release-deltas.py"),
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        directory = tempfile.mkdtemp()
        images = self._images(directory, b"A" * 200000 + b"new\n")
        bases = self._bases(directory, b"A" * 200000 + b"old\n")
        module._write_release(images, "zlyme43.1", "abc123", bases)
        with open(os.path.join(images, "release-manifest.json"), "r", encoding="utf-8") as handle:
            data = json_load(handle)
        self.assertEqual(len(data["deltas"]), 1)
        self.assertEqual(data["deltas"][0]["from_version"], "zlyme43")
        self.assertEqual(data["deltas"][0]["from_sha256"], bases[0]["root_sha256"])
        self.assertLess(data["deltas"][0]["size"], int(data["full"]["size"] * rel.DELTA_SIZE_RATIO))
        self.assertIn(bases[0]["root_sha256"][:12], data["deltas"][0]["file"])

    def test_same_version_distinct_roots_do_not_overwrite(self):
        spec = importlib.util.spec_from_file_location(
            "make_release_deltas_roots",
            os.path.join(ROOT, "scripts", "make-release-deltas.py"),
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        directory = tempfile.mkdtemp()
        images = self._images(directory, b"A" * 200000 + b"target\n")
        old_a = b"A" * 200000 + b"base-a\n"
        old_b = b"A" * 200000 + b"base-b\n"
        path_a = os.path.join(directory, "old-a")
        path_b = os.path.join(directory, "old-b")
        path_a_copy = os.path.join(directory, "old-a-copy")
        for path, body in ((path_a, old_a), (path_b, old_b), (path_a_copy, old_a)):
            with open(path, "wb") as handle:
                handle.write(body)
        bases = [
            {"version": "zlyme43", "root_path": path_a, "root_sha256": rel.sha256_file(path_a)},
            {"version": "zlyme43", "root_path": path_b, "root_sha256": rel.sha256_file(path_b)},
            {"version": "zlyme43", "root_path": path_a_copy, "root_sha256": rel.sha256_file(path_a_copy)},
        ]
        module._write_release(images, "zlyme43.1", "abc123", bases)
        with open(os.path.join(images, "release-manifest.json"), "r", encoding="utf-8") as handle:
            data = json_load(handle)
        self.assertEqual(len(data["deltas"]), 2)
        by_sha = {item["from_sha256"]: item for item in data["deltas"]}
        self.assertEqual(set(by_sha), {bases[0]["root_sha256"], bases[1]["root_sha256"]})
        names = [item["file"] for item in data["deltas"]]
        self.assertEqual(len(set(names)), 2)
        for base in bases[:2]:
            entry = by_sha[base["root_sha256"]]
            self.assertEqual(entry["from_version"], "zlyme43")
            self.assertIn(base["root_sha256"][:12], entry["file"])
            self.assertTrue(entry["file"].startswith("zlyme-my355-delta-zlyme43-"))
            self.assertTrue(os.path.isfile(os.path.join(images, entry["file"])))
            kind, chosen = rel.choose_transport(data, base["root_sha256"])
            self.assertEqual(kind, "delta")
            self.assertEqual(chosen["from_sha256"], base["root_sha256"])
            self.assertEqual(chosen["file"], entry["file"])


def json_load(handle):
    import json

    return json.load(handle)


def archive_member(path, name):
    with tarfile.open(path, "r:") as archive:
        return archive.extractfile(name).read().decode()


if __name__ == "__main__":
    unittest.main()
