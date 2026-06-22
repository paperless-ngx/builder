import hashlib
import subprocess
import sys
import unittest
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory

SCRIPT = Path(__file__).resolve().parents[1] / "assemble_wheel.py"


def build(tmp, *, binary_name="vec0.so", version="0.1.10+paperless.1",
          tag="linux_x86_64"):
    src = Path(tmp) / binary_name
    src.write_bytes(b"\x7fELF fake shared object payload")
    out = Path(tmp) / "out"
    out.mkdir()
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--binary", str(src),
         "--version", version, "--platform-tag", tag, "--out", str(out)],
        capture_output=True, text=True, check=True,
    )
    wheel = Path(result.stdout.strip())
    return wheel


class TestAssembleWheel(unittest.TestCase):
    def test_filename(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            self.assertEqual(
                wheel.name,
                "sqlite_vec-0.1.10+paperless.1-py3-none-linux_x86_64.whl",
            )

    def test_contents(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            with zipfile.ZipFile(wheel) as z:
                names = set(z.namelist())
            self.assertIn("sqlite_vec/__init__.py", names)
            self.assertIn("sqlite_vec/vec0.so", names)
            self.assertIn(
                "sqlite_vec-0.1.10+paperless.1.dist-info/METADATA", names)
            self.assertIn(
                "sqlite_vec-0.1.10+paperless.1.dist-info/WHEEL", names)
            self.assertIn(
                "sqlite_vec-0.1.10+paperless.1.dist-info/RECORD", names)

    def test_dylib_binary_kept_as_dylib(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp, binary_name="vec0.dylib",
                          tag="macosx_11_0_arm64")
            with zipfile.ZipFile(wheel) as z:
                names = set(z.namelist())
            self.assertIn("sqlite_vec/vec0.dylib", names)

    def test_init_api(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            with zipfile.ZipFile(wheel) as z:
                init = z.read("sqlite_vec/__init__.py").decode()
            for token in ("def load(", "def loadable_path(",
                          "def serialize_float32(", "def serialize_int8(",
                          '__version__ = "0.1.10+paperless.1"'):
                self.assertIn(token, init)

    def test_metadata_no_todo(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            with zipfile.ZipFile(wheel) as z:
                meta = z.read(
                    "sqlite_vec-0.1.10+paperless.1.dist-info/METADATA"
                ).decode()
            self.assertNotIn("TODO", meta)
            self.assertIn("Name: sqlite-vec", meta)
            self.assertIn("Version: 0.1.10+paperless.1", meta)

    def test_wheel_tag(self):
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            with zipfile.ZipFile(wheel) as z:
                wheelmeta = z.read(
                    "sqlite_vec-0.1.10+paperless.1.dist-info/WHEEL"
                ).decode()
            self.assertIn("Root-Is-Purelib: false", wheelmeta)
            self.assertIn("Tag: py3-none-linux_x86_64", wheelmeta)

    def test_record_hashes_match(self):
        import base64
        with TemporaryDirectory() as tmp:
            wheel = build(tmp)
            with zipfile.ZipFile(wheel) as z:
                record = z.read(
                    "sqlite_vec-0.1.10+paperless.1.dist-info/RECORD"
                ).decode()
                payload = z.read("sqlite_vec/__init__.py")
            digest = base64.urlsafe_b64encode(
                hashlib.sha256(payload).digest()).rstrip(b"=").decode()
            line = next(r for r in record.splitlines()
                        if r.startswith("sqlite_vec/__init__.py,"))
            self.assertIn(f"sha256={digest}", line)


if __name__ == "__main__":
    unittest.main()
