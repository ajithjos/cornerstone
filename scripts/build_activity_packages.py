#!/usr/bin/env python3
"""Bundle the shared activity foundation and refresh package integrity manifests.

Run from any directory. --check verifies generated assets without rewriting.
Published bundles are self-contained and never import a mutable shared URL.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOUNDATION = ROOT / "content/activity_foundation"
PACKAGES = ROOT / "content/activity_packages"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    dirty = []
    for entry in json.loads((PACKAGES / "registry.json").read_text())["packages"]:
        directory = PACKAGES / entry["path"]
        for name in ("bridge.js", "foundation.css"):
            data = (FOUNDATION / name).read_bytes()
            target = directory / name
            if args.check:
                if not target.exists() or target.read_bytes() != data:
                    dirty.append(str(target.relative_to(ROOT)))
            else:
                target.write_bytes(data)
        manifest_path = directory / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        files = sorted(set(manifest["files"]) | {"bridge.js", "foundation.css"})
        hashes = {
            name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
            for name in files if (directory / name).exists()
        }
        if args.check:
            if manifest["files"] != files or manifest["sha256"] != hashes:
                dirty.append(str(manifest_path.relative_to(ROOT)))
        else:
            manifest.update(files=files, sha256=hashes)
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    if dirty:
        raise SystemExit("Rebuild activity packages: " + ", ".join(dirty))


if __name__ == "__main__":
    main()
