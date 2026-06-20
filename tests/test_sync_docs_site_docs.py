import importlib.util
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "sync_docs_site_docs.py"
SPEC = importlib.util.spec_from_file_location("sync_docs_site_docs", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_sync_docs_site_docs_copies_repo_docs_only() -> None:
    MODULE.sync_docs_site_docs()
    assert (MODULE.DEVELOPER_ROOT / "README.md").exists()
    assert (MODULE.DEVELOPER_ROOT / "architecture" / "learning-product-definition.md").exists()
    for removed_root in MODULE.REMOVED_ROOTS:
        assert not removed_root.exists()


def test_sync_docs_site_docs_overwrites_stale_developer_tree() -> None:
    MODULE.DEVELOPER_ROOT.mkdir(parents=True, exist_ok=True)
    stale_file = MODULE.DEVELOPER_ROOT / "stale.md"
    stale_file.write_text("stale")

    MODULE.sync_docs_site_docs()

    assert not stale_file.exists()
    assert (MODULE.DEVELOPER_ROOT / "README.md").exists()
