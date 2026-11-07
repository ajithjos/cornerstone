"""Package tracked deployment sources and one explicit Flutter web build."""

import argparse
import subprocess
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = Path("fe/flutter/apps/cornerstone/build/web")


def application_paths() -> list[str]:
    return sorted(
        value
        for value in subprocess.check_output(
            [
                "git",
                "-C",
                str(ROOT),
                "ls-files",
                "--",
                "rust",
                "content",
                "fe/flutter/apps/cornerstone",
                "deploy/config/runtime_defaults",
            ],
            text=True,
        ).splitlines()
        if not value.startswith("rust/target/")
    )


def package(destination: Path, frontend: Path | None = None) -> None:
    frontend = frontend or ROOT / FRONTEND
    if not destination.is_absolute() or not frontend.is_absolute() or not (frontend / "index.html").is_file():
        raise ValueError("Package output and complete frontend build must use absolute paths")
    if destination.exists() or destination.is_symlink():
        raise ValueError("Release package output already exists")
    paths = (
        subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--recurse-submodules", "-z"]).decode().split("\0")
    )
    with tarfile.open(destination, "w:gz") as archive:
        for name in paths:
            if not name:
                continue
            if "/local/secrets/" in name or name.endswith("/.env"):
                raise ValueError("A credential file is tracked; refusing release packaging")
            path = ROOT / name
            if path.is_file() or path.is_symlink():
                archive.add(path, arcname=name, recursive=False)
        archive.add(frontend, arcname=str(FRONTEND))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--frontend", type=Path)
    args = parser.parse_args()
    package(args.destination, args.frontend)
