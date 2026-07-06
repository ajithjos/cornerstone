from __future__ import annotations

from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
LIBRARY_ROOT = REPO_ROOT / "content" / "library"
LEGACY_CATALOG_ROOT = REPO_ROOT / "content" / "catalog"
LEGACY_MATERIALS_ROOT = REPO_ROOT / "content" / "materials"
SUPPORTED_MATERIAL_KINDS = {
    "lesson_note",
    "teaching_note",
    "worksheet",
    "drill",
    "quick_check",
}
LEARNER_FACING_KINDS = {"lesson_note", "worksheet", "drill", "quick_check"}
PRACTICE_KINDS = {"worksheet", "drill"}
FACT_FLUENCY_PATHWAY_ID = "arithmetic_fact_fluency"


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def load_markdown_frontmatter(path: Path) -> dict:
    text = path.read_text()
    assert text.startswith("---\n"), f"missing frontmatter start: {path}"
    end = text.find("\n---\n", 4)
    assert end != -1, f"missing frontmatter end: {path}"
    return yaml.safe_load(text[4:end])


def collect_markdown(directory: Path) -> dict[str, dict]:
    items: dict[str, dict] = {}
    for path in sorted(directory.glob("*.md")):
        item = load_markdown_frontmatter(path)
        items[item["id"]] = item
    return items


def validate_pathway_tree(pathway_entry: dict) -> None:
    pathway_path = LIBRARY_ROOT / pathway_entry["path"]
    pathway_root = pathway_path.parent
    assert pathway_path.exists()

    pathway = load_markdown_frontmatter(pathway_path)
    stages = collect_markdown(pathway_root / "stages")
    skills = collect_markdown(pathway_root / "skills")
    playlists = collect_markdown(pathway_root / "playlists")
    materials = collect_markdown(pathway_root / "materials")

    assert pathway["id"] == pathway_entry["pathway_id"]
    assert pathway["subject_id"] == pathway_entry["subject_id"]
    assert pathway["area_id"] == pathway_entry["area_id"]
    assert set(pathway["stage_ids"]) == set(stages)
    assert set(pathway["playlist_ids"]) == set(playlists)
    assert pathway["entry_points"]

    for age_key, playlist_id in pathway["entry_points"].items():
        assert age_key.startswith("age_")
        assert playlist_id in playlists

    for age_key in ("age_7", "age_10"):
        assert age_key in pathway["entry_points"]

    stage_ids_from_skills = set()
    skill_ids_in_materials = set()
    material_ids_seen = set()
    for skill in skills.values():
        assert skill["stage_ids"]
        for stage_id in skill["stage_ids"]:
            assert stage_id in stages
            stage_ids_from_skills.add(stage_id)

    stage_ids_from_materials = set()
    for material in materials.values():
        material_kind = material["type"]
        assert material_kind in SUPPORTED_MATERIAL_KINDS
        assert material["stage_ids"]
        assert material["skill_ids"]
        for stage_id in material["stage_ids"]:
            assert stage_id in stages
            stage_ids_from_materials.add(stage_id)
        for skill_id in material["skill_ids"]:
            assert skill_id in skills
            skill_ids_in_materials.add(skill_id)
        material_ids_seen.add(material["id"])

    playlist_stage_ids = set()
    playlist_skill_ids = set()
    playlist_material_ids = set()
    for playlist in playlists.values():
        assert playlist["stage_ids"]
        assert playlist["skill_ids"]
        assert playlist["sessions"]
        has_lesson_note = False
        has_practice = False
        has_quick_check = False
        lesson_note_seen = False

        for stage_id in playlist["stage_ids"]:
            assert stage_id in stages
            playlist_stage_ids.add(stage_id)
        for skill_id in playlist["skill_ids"]:
            assert skill_id in skills
            playlist_skill_ids.add(skill_id)

        playlist_session_ids = set()
        for session in playlist["sessions"]:
            assert session["id"]
            assert session["id"] not in playlist_session_ids
            playlist_session_ids.add(session["id"])
            assert session["material_ids"]
            assert session["skill_ids"]
            session_material_kinds = []

            for material_id in session["material_ids"]:
                assert material_id in materials
                playlist_material_ids.add(material_id)
                session_material_kinds.append(materials[material_id]["type"])
            for skill_id in session["skill_ids"]:
                assert skill_id in skills
                assert skill_id in playlist["skill_ids"]

            if "lesson_note" in session_material_kinds:
                has_lesson_note = True
                lesson_note_seen = True
            if any(kind in PRACTICE_KINDS for kind in session_material_kinds):
                has_practice = True
                assert lesson_note_seen, f"playlist {playlist['id']} schedules practice before any lesson note"
            if "quick_check" in session_material_kinds:
                has_quick_check = True
                assert lesson_note_seen, f"playlist {playlist['id']} schedules a quick check before any lesson note"
            if "teaching_note" in session_material_kinds:
                assert any(kind in LEARNER_FACING_KINDS for kind in session_material_kinds), (
                    f"playlist {playlist['id']} includes a teaching-note-only session"
                )

        assert has_lesson_note, f"playlist {playlist['id']} is missing a lesson note"
        assert has_practice, f"playlist {playlist['id']} is missing practice material"
        assert has_quick_check, f"playlist {playlist['id']} is missing a quick check"

        if pathway["id"] == FACT_FLUENCY_PATHWAY_ID:
            drill_material_ids = [
                material_id
                for session in playlist["sessions"]
                for material_id in session["material_ids"]
                if materials[material_id]["type"] == "drill"
            ]
            quick_check_material_ids = [
                material_id
                for session in playlist["sessions"]
                for material_id in session["material_ids"]
                if materials[material_id]["type"] == "quick_check"
            ]

            assert drill_material_ids, f"fact-fluency playlist {playlist['id']} is missing a drill session"
            for material_id in drill_material_ids:
                assert "runtime" in materials[material_id], (
                    f"fact-fluency drill {material_id} in playlist {playlist['id']} is missing a runtime block"
                )
            for material_id in quick_check_material_ids:
                runtime = materials[material_id].get("runtime")
                assert runtime is not None, (
                    f"fact-fluency quick check {material_id} in playlist {playlist['id']} is missing a runtime block"
                )
                gate = runtime.get("gate")
                assert gate is not None, (
                    f"fact-fluency quick check {material_id} in playlist {playlist['id']} is missing a gate"
                )
                assert gate["requires_ready_material_id"] in drill_material_ids, (
                    f"fact-fluency quick check {material_id} in playlist {playlist['id']} must gate on that playlist's drill"
                )

    assert set(stages) <= stage_ids_from_skills | stage_ids_from_materials | playlist_stage_ids
    assert set(skills) <= skill_ids_in_materials | playlist_skill_ids
    assert set(materials) == material_ids_seen == playlist_material_ids
    assert set(playlists) == set(pathway["playlist_ids"])


def test_legacy_content_trees_are_absent() -> None:
    assert not LEGACY_CATALOG_ROOT.exists()
    assert not LEGACY_MATERIALS_ROOT.exists()


def test_authored_pathway_trees_are_coherent() -> None:
    registry = load_yaml(LIBRARY_ROOT / "registry.yaml")
    for pathway_entry in registry["pathways"]:
        validate_pathway_tree(pathway_entry)
