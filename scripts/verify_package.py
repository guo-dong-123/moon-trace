#!/usr/bin/env python3
"""Check that a release ZIP includes its reproducibility and license files."""
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "moon.mod").read_text(), re.M).group(1)
    artifact = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / f"_build/publish/guo-dong-123-moon-trace-{version}.zip"
    required = {"moon.mod", "README.md", "LICENSE", "THIRD_PARTY.md", ".moonbit-version",
                "scripts/check_toolchain.py", "src/storage/atomic_native.c"}
    with zipfile.ZipFile(artifact) as archive:
        names = set(archive.namelist())
        assert not (required - names), f"Missing release files: {sorted(required - names)}"
        for name in names:
            parts = Path(name).parts
            assert not any(part in {".git", "_build", ".mooncakes", "__pycache__"} for part in parts), name
            assert not any(part.startswith(".env") and part != ".env.example" for part in parts), name
            assert not name.endswith("credentials.json"), name
        assert archive.read(".moonbit-version").decode().strip() == (ROOT / ".moonbit-version").read_text().strip()
    print(f"PASS: {artifact.name} includes toolchain pin, native helper, README and licenses; excludes local caches and credentials")


if __name__ == "__main__":
    main()
