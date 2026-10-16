#!/usr/bin/env python3
"""Import PlatformZlyme from the pinned PortMaster platform.py."""
import hashlib
import py_compile
import shutil
import subprocess
import sys
import tempfile
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).resolve().parent / "fixtures" / "portmaster-2026.06.23-0015-platform.py"
PATCH = ROOT / "package" / "system" / "portmaster" / "patch-hardware.py"
EXPECT = "81731731a807e73f6ca717f12fa3e2dde5678d2c42578926fba754009dd2baa7"


def fail(msg: str) -> None:
    print("portmaster-platform: " + msg, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    digest = hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
    if digest != EXPECT:
        fail("pinned platform.py checksum changed")
    work = Path(tempfile.mkdtemp())
    try:
        pkg = work / "harbourmaster"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "config.py").write_text("")
        (pkg / "util.py").write_text("")
        shutil.copy(FIXTURE, pkg / "platform.py")
        (pkg / "hardware.py").write_text(
            "HW = [('miyoo flip*', 'miyoo-flip')]\n"
            'DEVICES = {"Miyoo Flip": {"device": "miyoo-flip", '
            '"manufacturer": "Miyoo", "cfw": ["Zlyme", "ROCKNIX"]}}\n'
        )
        proc = subprocess.run(
            [sys.executable, str(PATCH), str(pkg / "hardware.py")],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            fail(proc.stderr.strip() or "patch failed")
        py_compile.compile(str(pkg / "platform.py"), doraise=True)
        utility = types.ModuleType("utility")
        utility.cprint = lambda *args, **kwargs: None
        utility.cstrip = lambda text, *args, **kwargs: text
        sys.modules["utility"] = utility
        loguru = types.ModuleType("loguru")

        class Logger:
            def __getattr__(self, name):
                return lambda *args, **kwargs: None

        loguru.logger = Logger()
        sys.modules["loguru"] = loguru
        sys.path.insert(0, str(work))
        import harbourmaster.platform as plat

        cls = plat.HM_PLATFORMS["zlyme"]
        if cls.__name__ != "PlatformZlyme" or cls.__bases__ != (plat.PlatformBase,):
            fail("zlyme is not PlatformZlyme(PlatformBase)")
        if issubclass(cls, plat.PlatformJELOS) or cls.ES_NAME is not None:
            fail("PlatformZlyme inherited JELOS")
        if "ES_NAME" in cls.__dict__:
            fail("PlatformZlyme sets ES_NAME")

        class HM:
            tools_dir = work / "tools"
            ports_dir = work / "ports"
            cfg_data = {}

            def save_config(self):
                fail("PlatformZlyme wrote PortMaster config")

        before = {path.relative_to(work).as_posix() for path in work.rglob("*") if path.is_file()}
        obj = cls(HM())
        obj.first_run()
        obj.portmaster_install([])
        obj.portmaster_post_install()
        after = {path.relative_to(work).as_posix() for path in work.rglob("*") if path.is_file()}
        if after - before:
            fail("hooks created " + ", ".join(sorted(after - before)))
    finally:
        shutil.rmtree(work)
    print("portmaster platform ok")


if __name__ == "__main__":
    main()
