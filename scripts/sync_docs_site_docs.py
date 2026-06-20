from __future__ import annotations

import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_SOURCE_ROOT = REPO_ROOT / "docs"
DOCS_SITE_ROOT = REPO_ROOT / "docs_site" / "docs"
DEVELOPER_ROOT = DOCS_SITE_ROOT / "developer"
REMOVED_ROOTS = (
    DOCS_SITE_ROOT / "generated",
    DOCS_SITE_ROOT / "library",
    DOCS_SITE_ROOT / "materials",
)


def sync_docs_site_docs() -> None:
    for directory in REMOVED_ROOTS:
        if directory.exists():
            shutil.rmtree(directory)

    if DEVELOPER_ROOT.exists():
        shutil.rmtree(DEVELOPER_ROOT)
    DEVELOPER_ROOT.mkdir(parents=True, exist_ok=True)

    for source in DOCS_SOURCE_ROOT.rglob("*.md"):
        target = DEVELOPER_ROOT / source.relative_to(DOCS_SOURCE_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source.read_text())


if __name__ == "__main__":
    sync_docs_site_docs()
