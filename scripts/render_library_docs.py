from __future__ import annotations

import shutil
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTENT_ROOT = REPO_ROOT / "content"
LIBRARY_SOURCE_ROOT = CONTENT_ROOT / "library"
DOCS_SOURCE_ROOT = REPO_ROOT / "docs"
DOCS_ROOT = REPO_ROOT / "docs_site" / "docs"
GENERATED_ROOT = DOCS_ROOT / "generated"
LIBRARY_DOCS_ROOT = DOCS_ROOT / "library"
LEGACY_MATERIALS_ROOT = DOCS_ROOT / "materials"
DEVELOPER_ROOT = DOCS_ROOT / "developer"

VALID_MODES = {"production", "developer"}


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def read_markdown_frontmatter(path: Path) -> tuple[dict, str]:
    raw = path.read_text()
    if not raw.startswith("---\n"):
        raise ValueError(f"{path} is missing YAML frontmatter")
    end = raw.find("\n---\n", 4)
    if end == -1:
        raise ValueError(f"{path} has an unterminated frontmatter block")
    frontmatter = yaml.safe_load(raw[4:end]) or {}
    body = raw[end + 5 :].strip()
    return frontmatter, body


def extract_markdown_title(body: str) -> str:
    for line in body.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    raise ValueError("markdown document is missing an H1 title")


def first_paragraph(body: str) -> str:
    saw_title = False
    lines: list[str] = []
    for line in body.splitlines():
        trimmed = line.strip()
        if not saw_title:
            if trimmed.startswith("# "):
                saw_title = True
            continue
        if not trimmed:
            if lines:
                break
            continue
        if trimmed.startswith("## "):
            if lines:
                break
            continue
        if trimmed.startswith("- ") and not lines:
            continue
        lines.append(trimmed)
    return " ".join(lines).strip()


def extract_labeled_bullet(body: str, label: str) -> str | None:
    prefix = f"- {label}:"
    for line in body.splitlines():
        trimmed = line.strip()
        if trimmed.startswith(prefix):
            return trimmed[len(prefix) :].strip()
    return None


def summarize_skill(body: str) -> str:
    bullets = [line.strip()[2:] for line in body.splitlines() if line.strip().startswith("- ")]
    if bullets:
        return " ".join(bullets)
    return first_paragraph(body)


def age_band_label(age: int) -> str:
    if age <= 6:
        return "early"
    if age <= 8:
        return "core"
    return "extension"


def age_range_text(min_age: int, max_age: int) -> str:
    if min_age == max_age:
        return str(min_age)
    return f"{min_age} to {max_age}"


def relative_library_path(path: Path) -> str:
    return path.relative_to(LIBRARY_SOURCE_ROOT).as_posix()


def load_library_content() -> dict:
    registry = load_yaml(LIBRARY_SOURCE_ROOT / "registry.yaml")
    library = {
        "subjects": registry["subjects"],
        "areas": registry["areas"],
        "pathways": [],
        "stages": [],
        "skills": [],
        "playlists": [],
        "materials": [],
    }

    for pathway_entry in registry["pathways"]:
        pathway_source = LIBRARY_SOURCE_ROOT / pathway_entry["path"]
        pathway_root = pathway_source.parent
        pathway_meta, pathway_body = read_markdown_frontmatter(pathway_source)
        pathway_subject_id = pathway_meta["subject_id"]
        pathway_area_id = pathway_meta["area_id"]
        pathway_age_min = int(pathway_meta["recommended_age_min"])
        pathway_age_max = int(pathway_meta["recommended_age_max"])

        library["pathways"].append(
            {
                "pathway_id": pathway_meta["id"],
                "title": pathway_meta["title"],
                "subject_id": pathway_subject_id,
                "area_id": pathway_area_id,
                "recommended_age_min": pathway_age_min,
                "recommended_age_max": pathway_age_max,
                "stage_ids": pathway_meta["stage_ids"],
                "playlist_ids": pathway_meta["playlist_ids"],
                "entry_points": pathway_meta["entry_points"],
                "description": first_paragraph(pathway_body),
                "path": relative_library_path(pathway_source),
            }
        )

        stage_skill_map: dict[str, list[str]] = {}
        for skill_path in sorted((pathway_root / "skills").glob("*.md")):
            skill_meta, skill_body = read_markdown_frontmatter(skill_path)
            skill_id = skill_meta["id"]
            for stage_id in skill_meta["stage_ids"]:
                stage_skill_map.setdefault(stage_id, []).append(skill_id)
            description = summarize_skill(skill_body)
            library["skills"].append(
                {
                    "skill_id": skill_id,
                    "subject_id": pathway_subject_id,
                    "area_id": pathway_area_id,
                    "title": skill_meta["title"],
                    "recommended_age": pathway_age_min,
                    "recommended_level": age_band_label(pathway_age_min),
                    "description": description,
                    "success_criteria": extract_labeled_bullet(skill_body, "successful performance") or description,
                    "path": relative_library_path(skill_path),
                }
            )

        stage_documents: dict[str, dict] = {}
        for stage_path in sorted((pathway_root / "stages").glob("*.md")):
            stage_meta, stage_body = read_markdown_frontmatter(stage_path)
            stage_documents[stage_meta["id"]] = {
                "stage_id": stage_meta["id"],
                "subject_id": pathway_subject_id,
                "area_id": pathway_area_id,
                "title": stage_meta["title"],
                "recommended_age": pathway_age_min,
                "recommended_level": age_band_label(pathway_age_min),
                "description": first_paragraph(stage_body),
                "skill_ids": sorted(stage_skill_map.get(stage_meta["id"], [])),
                "sequence": int(stage_meta["sequence"]),
                "path": relative_library_path(stage_path),
            }
        for stage_id in pathway_meta["stage_ids"]:
            library["stages"].append(stage_documents[stage_id])

        playlist_documents: dict[str, dict] = {}
        for playlist_path in sorted((pathway_root / "playlists").glob("*.md")):
            playlist_meta, _ = read_markdown_frontmatter(playlist_path)
            recommended_age_min = int(playlist_meta["recommended_age_min"])
            recommended_age_max = int(playlist_meta["recommended_age_max"])
            sessions = [
                {
                    "day_offset": index,
                    "title": session["title"],
                    "skill_ids": session["skill_ids"],
                    "material_ids": session["material_ids"],
                }
                for index, session in enumerate(playlist_meta["sessions"])
            ]
            playlist_documents[playlist_meta["id"]] = {
                "playlist_id": playlist_meta["id"],
                "title": playlist_meta["title"],
                "subject_id": pathway_subject_id,
                "area_id": pathway_area_id,
                "recommended_age": recommended_age_min,
                "recommended_age_min": recommended_age_min,
                "recommended_age_max": recommended_age_max,
                "recommended_level": age_band_label(recommended_age_min),
                "stage_ids": playlist_meta["stage_ids"],
                "skill_ids": playlist_meta["skill_ids"],
                "duration_days": len(sessions),
                "session_pattern": {"sessions": sessions},
                "path": relative_library_path(playlist_path),
            }
        for playlist_id in pathway_meta["playlist_ids"]:
            library["playlists"].append(playlist_documents[playlist_id])

        for material_path in sorted((pathway_root / "materials").glob("*.md")):
            material_meta, material_body = read_markdown_frontmatter(material_path)
            recommended_age = int(material_meta.get("recommended_age", pathway_age_min))
            library["materials"].append(
                {
                    "material_id": material_meta["id"],
                    "id": material_meta["id"],
                    "title": extract_markdown_title(material_body),
                    "type": material_meta["type"],
                    "subject_id": pathway_subject_id,
                    "area_id": pathway_area_id,
                    "skill_ids": material_meta["skill_ids"],
                    "stage_ids": material_meta["stage_ids"],
                    "recommended_age": recommended_age,
                    "difficulty": material_meta.get("difficulty", "core"),
                    "estimated_minutes": int(material_meta["estimated_minutes"]),
                    "path": relative_library_path(material_path),
                }
            )

    return library


def render_markdown(mode: str = "production") -> None:
    if mode not in VALID_MODES:
        raise ValueError(f"unsupported mode: {mode}")

    library = load_library_content()
    subjects = library["subjects"]
    areas = library["areas"]
    pathways = library["pathways"]
    skills = library["skills"]
    stages = library["stages"]
    playlists = library["playlists"]
    materials = library["materials"]

    reset_output_dirs()

    write_file(
        GENERATED_ROOT / "library-overview.md",
        "\n".join(
            [
                "---",
                "title: Library Overview",
                "---",
                "",
                "# Library Overview",
                "",
                f"- subjects: {len(subjects)}",
                f"- areas: {len(areas)}",
                f"- pathways: {len(pathways)}",
                f"- skills: {len(skills)}",
                f"- stages: {len(stages)}",
                f"- playlists: {len(playlists)}",
                f"- materials: {len(materials)}",
                "",
                "The pages in this section are generated from the repo-owned pathway library under `content/library/`.",
            ]
        ),
    )

    write_file(
        GENERATED_ROOT / "pathways.md",
        render_sections(
            "Pathways",
            pathways,
            lambda item: [
                f"## `{item['pathway_id']}`",
                "",
                f"- subject: `{item['subject_id']}`",
                f"- area: `{item['area_id']}`",
                f"- recommended ages: `{age_range_text(item['recommended_age_min'], item['recommended_age_max'])}`",
                f"- source: `{item['path']}`",
                "",
                item["description"],
                "",
                "Entry points:",
                *[f"- `{key}` -> `{playlist_id}`" for key, playlist_id in sorted(item["entry_points"].items())],
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "areas.md",
        render_sections(
            "Areas",
            areas,
            lambda item: [
                f"## `{item['area_id']}`",
                "",
                f"- subject: `{item['subject_id']}`",
                "",
                item["description"],
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "skills.md",
        render_sections(
            "Skills",
            skills,
            lambda item: [
                f"## `{item['skill_id']}`",
                "",
                f"- subject: `{item['subject_id']}`",
                f"- area: `{item['area_id']}`",
                f"- recommended age: `{item['recommended_age']}`",
                f"- recommended level: {item['recommended_level']}",
                "",
                item["description"],
                "",
                f"Success criteria: {item['success_criteria']}",
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "stages.md",
        render_sections(
            "Stages",
            stages,
            lambda item: [
                f"## `{item['stage_id']}`",
                "",
                f"- subject: `{item['subject_id']}`",
                f"- area: `{item['area_id']}`",
                f"- recommended age: `{item['recommended_age']}`",
                f"- recommended level: {item['recommended_level']}",
                f"- source: `{item['path']}`",
                "",
                item["description"],
                "",
                "Skills:",
                *[f"- `{skill_id}`" for skill_id in item["skill_ids"]],
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "playlists.md",
        render_sections(
            "Playlists",
            playlists,
            lambda item: [
                f"## `{item['playlist_id']}`",
                "",
                f"- title: {item['title']}",
                f"- subject: `{item['subject_id']}`",
                f"- area: `{item['area_id']}`",
                f"- recommended ages: `{age_range_text(item['recommended_age_min'], item['recommended_age_max'])}`",
                f"- recommended level: {item['recommended_level']}",
                f"- duration days: `{item['duration_days']}`",
                f"- source: `{item['path']}`",
                "",
                "Stages:",
                *[f"- `{stage_id}`" for stage_id in item["stage_ids"]],
                "",
                "Skills:",
                *[f"- `{skill_id}`" for skill_id in item["skill_ids"]],
                "",
                "Sessions:",
                *[
                    f"- day {session['day_offset']}: {session['title']} -> skills {', '.join(session['skill_ids'])}"
                    for session in item["session_pattern"]["sessions"]
                ],
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "materials.md",
        render_sections(
            "Materials",
            materials,
            lambda item: [
                f"## `{item['material_id']}`",
                "",
                f"- type: `{item['type']}`",
                f"- subject: `{item['subject_id']}`",
                f"- area: `{item['area_id']}`",
                f"- path: `{item['path']}`",
                f"- recommended age: `{item['recommended_age']}`",
                f"- estimated minutes: `{item['estimated_minutes']}`",
                "",
                "Skills:",
                *[f"- `{skill_id}`" for skill_id in item["skill_ids"]],
            ],
        ),
    )

    write_file(
        GENERATED_ROOT / "subjects.md",
        render_sections(
            "Subjects",
            subjects,
            lambda item: [
                f"## `{item['subject_id']}`",
                "",
                item["description"],
            ],
        ),
    )

    copy_library_markdown()
    if mode == "developer":
        copy_developer_docs()


def reset_output_dirs() -> None:
    legacy_directories = (LEGACY_MATERIALS_ROOT,)
    for directory in legacy_directories:
        if directory.exists():
            shutil.rmtree(directory)

    for directory in (GENERATED_ROOT, LIBRARY_DOCS_ROOT, DEVELOPER_ROOT):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True, exist_ok=True)


def copy_library_markdown() -> None:
    source_root = LIBRARY_SOURCE_ROOT
    for source in source_root.rglob("*.md"):
        target = LIBRARY_DOCS_ROOT / source.relative_to(source_root)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source.read_text())


def copy_developer_docs() -> None:
    for source in DOCS_SOURCE_ROOT.rglob("*.md"):
        target = DEVELOPER_ROOT / source.relative_to(DOCS_SOURCE_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source.read_text())


def render_sections(title: str, items: list[dict], builder) -> str:
    lines = ["---", f"title: {title}", "---", "", f"# {title}", ""]
    for item in items:
        lines.extend(builder(item))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


if __name__ == "__main__":
    selected_mode = sys.argv[1] if len(sys.argv) > 1 else "production"
    render_markdown(selected_mode)
