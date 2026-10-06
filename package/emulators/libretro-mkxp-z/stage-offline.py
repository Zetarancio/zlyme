#!/usr/bin/env python3
"""Stage MKXP-Z inputs that Buildroot already downloaded.

No network. Wrap-git trees are extracted and their wrap patches applied
here, because Meson --wrap-mode=nodownload will not clone them. Wrap-file
archives are extracted the same way: host Python cannot unpack every
format Meson would, and the patch directory has to land before configure.
"""

import shutil
import subprocess
import sys
from pathlib import Path


def parse_wrap(path):
    section = None
    vals = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        vals[key.strip()] = value.strip()
    return section, vals


def extract_archive(archive, dest):
    tmp = dest.parent / (".extract-" + dest.name)
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    name = archive.name
    if name.endswith(".zip"):
        subprocess.run(["unzip", "-q", str(archive), "-d", str(tmp)], check=True)
    elif name.endswith(".tar.xz"):
        subprocess.run(["tar", "-xJf", str(archive), "-C", str(tmp)], check=True)
    elif name.endswith(".tar.gz") or name.endswith(".tgz"):
        subprocess.run(["tar", "-xzf", str(archive), "-C", str(tmp)], check=True)
    else:
        raise SystemExit(f"unknown archive {archive}")
    children = [p for p in tmp.iterdir() if p.name != "__MACOSX"]
    if len(children) != 1 or not children[0].is_dir():
        raise SystemExit(f"{archive} does not have one top directory")
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(children[0]), str(dest))
    shutil.rmtree(tmp)


def apply_diffs(dest, filesdir, names):
    for name in names:
        patch = filesdir / name.strip()
        if not patch.is_file():
            raise SystemExit(f"missing diff {patch}")
        subprocess.run(
            ["patch", "-l", "-f", "-p1", "-i", str(patch)],
            cwd=dest,
            check=True,
        )


def copy_tree(src, dest):
    if not src.is_dir():
        raise SystemExit(f"missing patch directory {src}")
    dest.mkdir(parents=True, exist_ok=True)
    for item in src.rglob("*"):
        rel = item.relative_to(src)
        target = dest / rel
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def git_apply(dest, patch):
    subprocess.run(["git", "apply", str(patch)], cwd=dest, check=True)


def stage_wrap(src, dl, name, archive_name):
    wrap_path = src / "subprojects" / f"{name}.wrap"
    _section, vals = parse_wrap(wrap_path)
    directory = vals.get("directory", name)
    dest = src / "subprojects" / directory
    extract_archive(dl / archive_name, dest)
    filesdir = src / "subprojects" / "packagefiles"
    patch_dir = vals.get("patch_directory")
    if patch_dir:
        copy_tree(filesdir / patch_dir, dest)
    diffs = vals.get("diff_files", "")
    if diffs:
        apply_diffs(dest, filesdir, diffs.split(","))


def stage_host(src, dl, entries):
    libretro = src / "libretro"
    downloads = libretro / "build" / "downloads"
    by_role = {}
    gems = []
    for role, name, archive in entries:
        if role == "host-gem":
            gems.append(archive)
        else:
            by_role[role] = archive

    ruby = downloads / "ruby"
    extract_archive(dl / by_role["host-ruby"], ruby)
    for patch in (
        "ruby-compat.patch",
        "ruby-prng-time.patch",
        "ruby-lto.patch",
        "ruby-sockets.patch",
        "ruby-user-threads.patch",
    ):
        git_apply(ruby, libretro / patch)
    include = f'#include "{libretro / "ruby-bindings.h"}"\n'
    gc = ruby / "gc.c"
    text = gc.read_text()
    if include not in text:
        gc.write_text(text + include)
    guess = dl / by_role["host-guess"]
    sub = dl / by_role["host-sub"]
    tool = ruby / "tool"
    cache = ruby / ".downloaded-cache"
    cache.mkdir(parents=True, exist_ok=True)
    for src_file, dest_name in ((guess, "config.guess"), (sub, "config.sub")):
        for folder in (tool, cache):
            target = folder / dest_name
            shutil.copy2(src_file, target)
            target.chmod(0o755)
    gem_dir = ruby / "gems"
    gem_dir.mkdir(parents=True, exist_ok=True)
    for gem in gems:
        shutil.copy2(dl / gem, gem_dir / gem)
        shutil.copy2(dl / gem, cache / gem)

    extract_archive(dl / by_role["host-wabt"], downloads / "wabt")
    git_apply(downloads / "wabt", libretro / "wasm2c-data-segments.patch")
    extract_archive(dl / by_role["host-yaml"], downloads / "libyaml")
    extract_archive(dl / by_role["host-zlib"], downloads / "zlib")
    pico = downloads / "picosha2"
    pico.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dl / by_role["host-picosha2"], pico / "picosha2.h")
    extract_archive(
        dl / by_role["host-predef"],
        libretro / "build" / "libretro-stage1" / "boost_predef",
    )


def stage_gcem(src, dl, archive_name):
    fluidsynth = src / "subprojects" / "fluidsynth"
    if not fluidsynth.is_dir():
        raise SystemExit("fluidsynth was not staged")
    tmp = src / "subprojects" / ".gcem-extract"
    if tmp.exists():
        shutil.rmtree(tmp)
    extract_archive(dl / archive_name, tmp)
    gcem = fluidsynth / "gcem"
    if gcem.exists():
        shutil.rmtree(gcem)
    shutil.copytree(tmp, gcem)
    shutil.rmtree(tmp)
    cmake_admin = fluidsynth / "cmake_admin"
    cmake_admin.mkdir(parents=True, exist_ok=True)
    shutil.copy2(
        Path(__file__).with_name("fluidsynth-FindGCEM.cmake"),
        cmake_admin / "FindGCEM.cmake",
    )


def load_list(path):
    rows = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        role, name, archive = line.split()
        rows.append((role, name, archive))
    return rows


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: stage-offline.py host|target DL_DIR SOURCE")
    mode, dl_s, src_s = sys.argv[1:]
    dl = Path(dl_s)
    src = Path(src_s)
    entries = load_list(Path(__file__).with_name("mkxp-offline.list"))
    if mode == "host":
        stage_host(src, dl, entries)
        return
    if mode != "target":
        raise SystemExit(f"unknown mode {mode}")
    for role, name, archive in entries:
        if role == "wrap":
            stage_wrap(src, dl, name, archive)
    for role, _name, archive in entries:
        if role == "gcem":
            stage_gcem(src, dl, archive)


if __name__ == "__main__":
    main()
