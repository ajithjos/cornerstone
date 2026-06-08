use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Component, Path, PathBuf};

use anyhow::{Context, anyhow, bail};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;

const LESSON_NOTE_KIND: &str = "lesson_note";
const TEACHING_NOTE_KIND: &str = "teaching_note";
const WORKSHEET_KIND: &str = "worksheet";
const DRILL_KIND: &str = "drill";
const QUICK_CHECK_KIND: &str = "quick_check";

fn is_supported_material_kind(kind: &str) -> bool {
    matches!(
        kind,
        LESSON_NOTE_KIND | TEACHING_NOTE_KIND | WORKSHEET_KIND | DRILL_KIND | QUICK_CHECK_KIND
    )
}

fn runtime_allowed_for_kind(kind: &str) -> bool {
    matches!(kind, DRILL_KIND | QUICK_CHECK_KIND)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubjectCatalog {
    pub subjects: Vec<Subject>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AreaCatalog {
    pub areas: Vec<Area>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Subject {
    pub subject_id: String,
    pub title: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Area {
    pub area_id: String,
    pub subject_id: String,
    pub title: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pathway {
    pub pathway_id: String,
    pub title: String,
    pub subject_id: String,
    pub area_id: String,
    pub recommended_age_min: u8,
    pub recommended_age_max: u8,
    pub stage_ids: Vec<String>,
    pub playlist_ids: Vec<String>,
    pub entry_points: HashMap<String, String>,
    pub description: String,
    pub source_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillCatalog {
    pub skills: Vec<Skill>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skill {
    pub skill_id: String,
    pub subject_id: String,
    pub area_id: String,
    pub title: String,
    pub recommended_age: u8,
    pub recommended_level: String,
    pub description: String,
    pub success_criteria: String,
    pub source_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StageCatalog {
    pub stages: Vec<Stage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Stage {
    pub stage_id: String,
    pub subject_id: String,
    pub area_id: String,
    pub title: String,
    pub recommended_age: u8,
    pub recommended_level: String,
    pub description: String,
    pub skill_ids: Vec<String>,
    pub source_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistCatalog {
    pub playlists: Vec<Playlist>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Playlist {
    pub playlist_id: String,
    pub title: String,
    pub subject_id: String,
    pub area_id: String,
    pub recommended_age: u8,
    pub recommended_level: String,
    pub stage_ids: Vec<String>,
    pub skill_ids: Vec<String>,
    pub duration_days: i32,
    pub session_pattern: SessionPattern,
    pub source_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionPattern {
    pub sessions: Vec<PlaylistSession>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistSession {
    pub day_offset: i32,
    pub title: String,
    pub skill_ids: Vec<String>,
    pub material_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterialCatalog {
    pub materials: Vec<MaterialIndexItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MaterialIndexItem {
    pub material_id: String,
    pub path: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub subject_id: String,
    pub area_id: String,
    pub skill_ids: Vec<String>,
    pub stage_ids: Vec<String>,
    pub recommended_age: u8,
    pub difficulty: String,
    pub estimated_minutes: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterialDocument {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub subject_id: String,
    pub area_id: String,
    pub skill_ids: Vec<String>,
    pub stage_ids: Vec<String>,
    pub recommended_age: u8,
    pub difficulty: String,
    pub estimated_minutes: u16,
    pub runtime: Option<MaterialRuntime>,
    pub title: String,
    pub body: String,
    pub source_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterialRuntime {
    pub engine_id: String,
    pub spec_version: u16,
    pub template_id: String,
    #[serde(default)]
    pub parameters: JsonValue,
    pub scoring: Option<MaterialRuntimeScoring>,
    pub persistence: Option<MaterialRuntimePersistence>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterialRuntimeScoring {
    pub pass_accuracy: Option<f64>,
    pub soft_time_limit_seconds: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterialRuntimePersistence {
    #[serde(default)]
    pub store_response_log: bool,
    #[serde(default = "default_store_summary")]
    pub store_summary: bool,
}

fn default_store_summary() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryDocument {
    pub route_path: String,
    pub source_path: String,
    pub kind: String,
    pub document_id: String,
    pub title: String,
    pub subject_id: String,
    pub area_id: String,
    pub pathway_id: String,
    pub description: String,
    pub body: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryContent {
    pub bundle: LibraryBundle,
    pub documents: Vec<LibraryDocument>,
    pub report: LibraryValidationReport,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryBundle {
    pub subjects: Vec<Subject>,
    pub areas: Vec<Area>,
    #[serde(default)]
    pub pathways: Vec<Pathway>,
    pub skills: Vec<Skill>,
    pub stages: Vec<Stage>,
    pub playlists: Vec<Playlist>,
    pub materials: Vec<MaterialDocument>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryValidationReport {
    pub loaded_at_utc: String,
    pub subject_count: usize,
    pub area_count: usize,
    pub pathway_count: usize,
    pub skill_count: usize,
    pub stage_count: usize,
    pub playlist_count: usize,
    pub material_count: usize,
}

#[derive(Debug, Deserialize)]
struct LibraryRegistry {
    subjects: Vec<Subject>,
    areas: Vec<Area>,
    pathways: Vec<LibraryPathwayIndex>,
}

#[derive(Debug, Deserialize)]
struct LibraryPathwayIndex {
    pathway_id: String,
    subject_id: String,
    area_id: String,
    title: String,
    path: String,
}

#[derive(Debug, Deserialize)]
struct PathwayFrontmatter {
    id: String,
    title: String,
    subject_id: String,
    area_id: String,
    recommended_age_min: u8,
    recommended_age_max: u8,
    stage_ids: Vec<String>,
    playlist_ids: Vec<String>,
    entry_points: HashMap<String, String>,
}

#[derive(Debug, Deserialize)]
struct StageFrontmatter {
    id: String,
    title: String,
    sequence: i32,
}

#[derive(Debug, Deserialize)]
struct SkillFrontmatter {
    id: String,
    title: String,
    stage_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct PlaylistFrontmatter {
    id: String,
    title: String,
    stage_ids: Vec<String>,
    skill_ids: Vec<String>,
    recommended_age_min: u8,
    recommended_age_max: u8,
    sessions: Vec<PlaylistFrontmatterSession>,
}

#[derive(Debug, Deserialize)]
struct PlaylistFrontmatterSession {
    title: String,
    material_ids: Vec<String>,
    skill_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct MaterialFrontmatter {
    id: String,
    #[serde(rename = "type")]
    kind: String,
    stage_ids: Vec<String>,
    skill_ids: Vec<String>,
    estimated_minutes: u16,
    recommended_age: Option<u8>,
    difficulty: Option<String>,
    runtime: Option<MaterialRuntime>,
}

#[derive(Debug, Default)]
struct LoadedLibrary {
    pathways: Vec<Pathway>,
    skills: Vec<Skill>,
    stages: Vec<Stage>,
    playlists: Vec<Playlist>,
    material_index: Vec<MaterialIndexItem>,
    material_documents: Vec<MaterialDocument>,
    documents: Vec<LibraryDocument>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityBootstrap {
    pub teams: Vec<BootstrapTeam>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BootstrapTeam {
    pub team_id: String,
    pub display_name: String,
    pub description: String,
    pub users: Vec<BootstrapUser>,
    pub memberships: Vec<BootstrapMembership>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BootstrapUser {
    pub user_id: String,
    pub username: String,
    pub display_name: String,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub email: Option<String>,
    pub google_subject: Option<String>,
    pub google_email: Option<String>,
    pub date_of_birth: Option<chrono::NaiveDate>,
    pub sex: Option<String>,
    pub current_level: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BootstrapMembership {
    pub user_id: String,
    pub role: String,
}

pub fn load_library_content(content_root: &Path) -> anyhow::Result<LibraryContent> {
    let registry: LibraryRegistry = read_yaml(content_root.join("library/registry.yaml"))?;
    let loaded = load_library_documents(content_root, &registry.pathways)?;

    validate_pathways(
        &loaded.pathways,
        &registry.subjects,
        &registry.areas,
        &loaded.stages,
        &loaded.playlists,
    )?;

    validate_catalog(
        content_root,
        &registry.subjects,
        &registry.areas,
        &loaded.skills,
        &loaded.stages,
        &loaded.playlists,
        &loaded.material_index,
        &loaded.material_documents,
    )?;

    validate_library_document_routes(&loaded.documents)?;

    let bundle = LibraryBundle {
        subjects: registry.subjects,
        areas: registry.areas,
        pathways: loaded.pathways,
        skills: loaded.skills,
        stages: loaded.stages,
        playlists: loaded.playlists,
        materials: loaded.material_documents,
    };
    let report = LibraryValidationReport {
        loaded_at_utc: Utc::now().to_rfc3339(),
        subject_count: bundle.subjects.len(),
        area_count: bundle.areas.len(),
        pathway_count: bundle.pathways.len(),
        skill_count: bundle.skills.len(),
        stage_count: bundle.stages.len(),
        playlist_count: bundle.playlists.len(),
        material_count: bundle.materials.len(),
    };
    Ok(LibraryContent {
        bundle,
        documents: loaded.documents,
        report,
    })
}

pub fn load_library_bundle(content_root: &Path) -> anyhow::Result<(LibraryBundle, LibraryValidationReport)> {
    let content = load_library_content(content_root)?;
    Ok((content.bundle, content.report))
}

pub fn load_bootstrap(bootstrap_path: &Path) -> anyhow::Result<IdentityBootstrap> {
    read_yaml(bootstrap_path)
}

impl LibraryBundle {
    pub fn skill_map(&self) -> HashMap<&str, &Skill> {
        self.skills
            .iter()
            .map(|skill| (skill.skill_id.as_str(), skill))
            .collect()
    }

    pub fn stage_map(&self) -> HashMap<&str, &Stage> {
        self.stages
            .iter()
            .map(|stage| (stage.stage_id.as_str(), stage))
            .collect()
    }

    pub fn playlist(&self, playlist_id: &str) -> Option<&Playlist> {
        self.playlists
            .iter()
            .find(|playlist| playlist.playlist_id == playlist_id)
    }

    pub fn material(&self, material_id: &str) -> Option<&MaterialDocument> {
        self.materials.iter().find(|material| material.id == material_id)
    }
}

fn read_yaml<T>(path: impl AsRef<Path>) -> anyhow::Result<T>
where
    T: for<'de> Deserialize<'de>,
{
    let path = path.as_ref();
    let raw = fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_yaml::from_str(&raw).with_context(|| format!("failed to parse yaml {}", path.display()))
}

fn load_library_documents(
    content_root: &Path,
    pathway_entries: &[LibraryPathwayIndex],
) -> anyhow::Result<LoadedLibrary> {
    let mut loaded = LoadedLibrary::default();

    for pathway_entry in pathway_entries {
        let pathway_source_path = content_root.join("library").join(&pathway_entry.path);
        let pathway_relative_path = relative_content_path(content_root, &pathway_source_path)?;
        let pathway_root = pathway_source_path
            .parent()
            .ok_or_else(|| anyhow!("{} has no parent directory", pathway_source_path.display()))?;
        let (pathway_meta, pathway_body) = read_markdown_frontmatter::<PathwayFrontmatter>(&pathway_source_path)?;

        if pathway_meta.id != pathway_entry.pathway_id {
            bail!(
                "pathway '{}' does not match registry id '{}'",
                pathway_meta.id,
                pathway_entry.pathway_id
            );
        }
        if pathway_meta.subject_id != pathway_entry.subject_id {
            bail!(
                "pathway '{}' does not match registry subject '{}'",
                pathway_meta.id,
                pathway_entry.subject_id
            );
        }
        if pathway_meta.area_id != pathway_entry.area_id {
            bail!(
                "pathway '{}' does not match registry area '{}'",
                pathway_meta.id,
                pathway_entry.area_id
            );
        }
        if pathway_meta.title != pathway_entry.title {
            bail!(
                "pathway '{}' does not match registry title '{}'",
                pathway_meta.id,
                pathway_entry.title
            );
        }

        loaded.pathways.push(Pathway {
            pathway_id: pathway_meta.id.clone(),
            title: pathway_meta.title.clone(),
            subject_id: pathway_meta.subject_id.clone(),
            area_id: pathway_meta.area_id.clone(),
            recommended_age_min: pathway_meta.recommended_age_min,
            recommended_age_max: pathway_meta.recommended_age_max,
            stage_ids: pathway_meta.stage_ids.clone(),
            playlist_ids: pathway_meta.playlist_ids.clone(),
            entry_points: pathway_meta.entry_points.clone(),
            description: markdown_first_paragraph(&pathway_body).unwrap_or_else(|| pathway_meta.title.clone()),
            source_path: pathway_relative_path,
        });
        loaded.documents.push(LibraryDocument {
            route_path: route_path_from_source_path(&loaded.pathways.last().expect("pathway document").source_path)?,
            source_path: loaded.pathways.last().expect("pathway document").source_path.clone(),
            kind: "pathway".to_string(),
            document_id: pathway_meta.id.clone(),
            title: pathway_meta.title.clone(),
            subject_id: pathway_meta.subject_id.clone(),
            area_id: pathway_meta.area_id.clone(),
            pathway_id: pathway_meta.id.clone(),
            description: markdown_first_paragraph(&pathway_body).unwrap_or_else(|| pathway_meta.title.clone()),
            body: pathway_body.clone(),
        });

        let mut stage_skill_map: HashMap<String, Vec<String>> = HashMap::new();
        for skill_path in list_markdown_files(&pathway_root.join("skills"))? {
            let skill_relative_path = relative_content_path(content_root, &skill_path)?;
            let (skill_meta, skill_body) = read_markdown_frontmatter::<SkillFrontmatter>(&skill_path)?;
            for stage_id in &skill_meta.stage_ids {
                stage_skill_map
                    .entry(stage_id.clone())
                    .or_default()
                    .push(skill_meta.id.clone());
            }

            let recommended_age = pathway_meta.recommended_age_min;
            let description = summarize_skill_body(&skill_body);
            let success_criteria =
                extract_labeled_bullet(&skill_body, "successful performance").unwrap_or_else(|| description.clone());
            loaded.skills.push(Skill {
                skill_id: skill_meta.id,
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                title: skill_meta.title,
                recommended_age,
                recommended_level: age_band_label(recommended_age),
                description,
                success_criteria,
                source_path: skill_relative_path.clone(),
            });
            loaded.documents.push(LibraryDocument {
                route_path: route_path_from_source_path(&skill_relative_path)?,
                source_path: skill_relative_path,
                kind: "skill".to_string(),
                document_id: loaded.skills.last().expect("skill document").skill_id.clone(),
                title: loaded.skills.last().expect("skill document").title.clone(),
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                pathway_id: pathway_meta.id.clone(),
                description: loaded.skills.last().expect("skill document").description.clone(),
                body: skill_body,
            });
        }

        let mut stage_documents = HashMap::new();
        for stage_path in list_markdown_files(&pathway_root.join("stages"))? {
            let stage_relative_path = relative_content_path(content_root, &stage_path)?;
            let (stage_meta, stage_body) = read_markdown_frontmatter::<StageFrontmatter>(&stage_path)?;
            let stage_description =
                markdown_first_paragraph(&stage_body).unwrap_or_else(|| "Pathway stage".to_string());
            loaded.documents.push(LibraryDocument {
                route_path: route_path_from_source_path(&stage_relative_path)?,
                source_path: stage_relative_path.clone(),
                kind: "stage".to_string(),
                document_id: stage_meta.id.clone(),
                title: stage_meta.title.clone(),
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                pathway_id: pathway_meta.id.clone(),
                description: stage_description.clone(),
                body: stage_body.clone(),
            });
            let mut skill_ids = stage_skill_map.remove(&stage_meta.id).unwrap_or_default();
            skill_ids.sort();
            stage_documents.insert(
                stage_meta.id.clone(),
                (
                    stage_meta.sequence,
                    Stage {
                        stage_id: stage_meta.id,
                        subject_id: pathway_meta.subject_id.clone(),
                        area_id: pathway_meta.area_id.clone(),
                        title: stage_meta.title,
                        recommended_age: pathway_meta.recommended_age_min,
                        recommended_level: age_band_label(pathway_meta.recommended_age_min),
                        description: stage_description,
                        skill_ids,
                        source_path: stage_relative_path,
                    },
                ),
            );
        }

        if let Some((stage_id, _)) = stage_skill_map.iter().next() {
            bail!(
                "pathway '{}' has skill files referencing missing stage '{}'",
                pathway_meta.id,
                stage_id
            );
        }

        for stage_id in &pathway_meta.stage_ids {
            let (_, stage) = stage_documents
                .remove(stage_id)
                .ok_or_else(|| anyhow!("pathway '{}' lists missing stage '{}'", pathway_meta.id, stage_id))?;
            loaded.stages.push(stage);
        }
        if let Some((stage_id, _)) = stage_documents.into_iter().next() {
            bail!(
                "pathway '{}' has stage file '{}' that is not listed in pathway.md",
                pathway_meta.id,
                stage_id
            );
        }

        let mut playlist_documents = HashMap::new();
        for playlist_path in list_markdown_files(&pathway_root.join("playlists"))? {
            let playlist_relative_path = relative_content_path(content_root, &playlist_path)?;
            let (playlist_meta, playlist_body) = read_markdown_frontmatter::<PlaylistFrontmatter>(&playlist_path)?;
            if playlist_meta.recommended_age_min > playlist_meta.recommended_age_max {
                bail!("playlist '{}' has an invalid recommended age range", playlist_meta.id);
            }
            let playlist_description =
                markdown_first_paragraph(&playlist_body).unwrap_or_else(|| playlist_meta.title.clone());
            loaded.documents.push(LibraryDocument {
                route_path: route_path_from_source_path(&playlist_relative_path)?,
                source_path: playlist_relative_path.clone(),
                kind: "playlist".to_string(),
                document_id: playlist_meta.id.clone(),
                title: playlist_meta.title.clone(),
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                pathway_id: pathway_meta.id.clone(),
                description: playlist_description.clone(),
                body: playlist_body,
            });
            let sessions = playlist_meta
                .sessions
                .into_iter()
                .enumerate()
                .map(|(index, session)| PlaylistSession {
                    day_offset: index as i32,
                    title: session.title,
                    skill_ids: session.skill_ids,
                    material_ids: session.material_ids,
                })
                .collect::<Vec<_>>();
            let recommended_age = playlist_meta.recommended_age_min;
            playlist_documents.insert(
                playlist_meta.id.clone(),
                Playlist {
                    playlist_id: playlist_meta.id,
                    title: playlist_meta.title,
                    subject_id: pathway_meta.subject_id.clone(),
                    area_id: pathway_meta.area_id.clone(),
                    recommended_age,
                    recommended_level: age_band_label(recommended_age),
                    stage_ids: playlist_meta.stage_ids,
                    skill_ids: playlist_meta.skill_ids,
                    duration_days: sessions.len() as i32,
                    session_pattern: SessionPattern { sessions },
                    source_path: playlist_relative_path,
                },
            );
        }

        for playlist_id in &pathway_meta.playlist_ids {
            let playlist = playlist_documents
                .remove(playlist_id)
                .ok_or_else(|| anyhow!("pathway '{}' lists missing playlist '{}'", pathway_meta.id, playlist_id))?;
            loaded.playlists.push(playlist);
        }
        if let Some((playlist_id, _)) = playlist_documents.into_iter().next() {
            bail!(
                "pathway '{}' has playlist file '{}' that is not listed in pathway.md",
                pathway_meta.id,
                playlist_id
            );
        }

        for material_path in list_markdown_files(&pathway_root.join("materials"))? {
            let material_relative_path = relative_content_path(content_root, &material_path)?;
            let (material_meta, material_body) = read_markdown_frontmatter::<MaterialFrontmatter>(&material_path)?;
            let recommended_age = material_meta
                .recommended_age
                .unwrap_or(pathway_meta.recommended_age_min);
            let difficulty = material_meta.difficulty.unwrap_or_else(|| "core".to_string());
            let title = extract_markdown_title(&material_body)
                .ok_or_else(|| anyhow!("{} is missing a markdown H1 title", material_path.display()))?;

            loaded.material_index.push(MaterialIndexItem {
                material_id: material_meta.id.clone(),
                path: material_relative_path.clone(),
                kind: material_meta.kind.clone(),
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                skill_ids: material_meta.skill_ids.clone(),
                stage_ids: material_meta.stage_ids.clone(),
                recommended_age,
                difficulty: difficulty.clone(),
                estimated_minutes: material_meta.estimated_minutes,
            });
            loaded.material_documents.push(MaterialDocument {
                id: material_meta.id,
                kind: material_meta.kind,
                subject_id: pathway_meta.subject_id.clone(),
                area_id: pathway_meta.area_id.clone(),
                skill_ids: material_meta.skill_ids,
                stage_ids: material_meta.stage_ids,
                recommended_age,
                difficulty,
                estimated_minutes: material_meta.estimated_minutes,
                runtime: material_meta.runtime,
                title,
                body: material_body,
                source_path: material_relative_path,
            });
            let material = loaded.material_documents.last().expect("material document");
            loaded.documents.push(LibraryDocument {
                route_path: route_path_from_source_path(&material.source_path)?,
                source_path: material.source_path.clone(),
                kind: "material".to_string(),
                document_id: material.id.clone(),
                title: material.title.clone(),
                subject_id: material.subject_id.clone(),
                area_id: material.area_id.clone(),
                pathway_id: pathway_meta.id.clone(),
                description: markdown_first_paragraph(&material.body).unwrap_or_else(|| material.title.clone()),
                body: material.body.clone(),
            });
        }
    }

    populate_derived_recommended_ages(&mut loaded);
    Ok(loaded)
}

fn split_frontmatter(raw: &str, source_path: &Path) -> anyhow::Result<(String, String)> {
    let mut lines = raw.lines();
    if lines.next() != Some("---") {
        bail!("{} is missing YAML frontmatter", source_path.display());
    }

    let mut frontmatter = Vec::new();
    for line in lines.by_ref() {
        if line == "---" {
            let body = lines.collect::<Vec<_>>().join("\n").trim().to_string();
            return Ok((frontmatter.join("\n"), body));
        }
        frontmatter.push(line.to_string());
    }

    bail!("{} has an unterminated frontmatter block", source_path.display())
}

fn read_markdown_frontmatter<T>(source_path: &Path) -> anyhow::Result<(T, String)>
where
    T: for<'de> Deserialize<'de>,
{
    let raw = fs::read_to_string(source_path).with_context(|| format!("failed to read {}", source_path.display()))?;
    let (frontmatter, body) = split_frontmatter(&raw, source_path)?;
    let metadata = serde_yaml::from_str(&frontmatter)
        .with_context(|| format!("invalid frontmatter in {}", source_path.display()))?;
    Ok((metadata, body))
}

fn list_markdown_files(directory: &Path) -> anyhow::Result<Vec<std::path::PathBuf>> {
    let mut files = Vec::new();
    for entry in fs::read_dir(directory).with_context(|| format!("failed to read {}", directory.display()))? {
        let entry = entry.with_context(|| format!("failed to read entry in {}", directory.display()))?;
        let path = entry.path();
        if path.is_file() && path.extension().and_then(|extension| extension.to_str()) == Some("md") {
            files.push(path);
        }
    }
    files.sort();
    Ok(files)
}

fn relative_content_path(content_root: &Path, source_path: &Path) -> anyhow::Result<String> {
    Ok(source_path
        .strip_prefix(content_root)
        .with_context(|| format!("{} is outside the content root", source_path.display()))?
        .to_string_lossy()
        .replace('\\', "/"))
}

fn extract_markdown_title(body: &str) -> Option<String> {
    body.lines()
        .find_map(|line| line.strip_prefix("# ").map(ToOwned::to_owned))
}

fn markdown_first_paragraph(body: &str) -> Option<String> {
    let mut saw_title = false;
    let mut lines = Vec::new();

    for line in body.lines() {
        let trimmed = line.trim();
        if !saw_title {
            if trimmed.starts_with("# ") {
                saw_title = true;
            }
            continue;
        }

        if trimmed.is_empty() {
            if lines.is_empty() {
                continue;
            }
            break;
        }
        if trimmed.starts_with("## ") {
            if lines.is_empty() {
                continue;
            }
            break;
        }
        if trimmed.starts_with("- ") && lines.is_empty() {
            continue;
        }
        lines.push(trimmed.to_string());
    }

    if lines.is_empty() { None } else { Some(lines.join(" ")) }
}

fn extract_labeled_bullet(body: &str, label: &str) -> Option<String> {
    let prefix = format!("- {}:", label);
    body.lines().find_map(|line| {
        let trimmed = line.trim();
        trimmed.strip_prefix(&prefix).map(|value| value.trim().to_string())
    })
}

fn summarize_skill_body(body: &str) -> String {
    let mut parts = Vec::new();
    for line in body.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("- ") {
            parts.push(trimmed.trim_start_matches("- ").to_string());
        }
    }
    if parts.is_empty() {
        markdown_first_paragraph(body).unwrap_or_else(|| "Skill description".to_string())
    } else {
        parts.join(" ")
    }
}

fn age_band_label(age: u8) -> String {
    match age {
        0..=6 => "early".to_string(),
        7..=8 => "core".to_string(),
        _ => "extension".to_string(),
    }
}

fn populate_derived_recommended_ages(loaded: &mut LoadedLibrary) {
    let mut stage_ages: HashMap<String, Vec<u8>> = HashMap::new();
    let mut skill_ages: HashMap<String, Vec<u8>> = HashMap::new();
    let mut material_ages: HashMap<String, Vec<u8>> = HashMap::new();

    for playlist in &loaded.playlists {
        for stage_id in &playlist.stage_ids {
            stage_ages
                .entry(stage_id.clone())
                .or_default()
                .push(playlist.recommended_age);
        }
        for skill_id in &playlist.skill_ids {
            skill_ages
                .entry(skill_id.clone())
                .or_default()
                .push(playlist.recommended_age);
        }
        for session in &playlist.session_pattern.sessions {
            for material_id in &session.material_ids {
                material_ages
                    .entry(material_id.clone())
                    .or_default()
                    .push(playlist.recommended_age);
            }
        }
    }

    for stage in &mut loaded.stages {
        if let Some(age) = stage_ages
            .get(&stage.stage_id)
            .and_then(|ages| ages.iter().min().copied())
        {
            stage.recommended_age = age;
            stage.recommended_level = age_band_label(age);
        }
    }

    for skill in &mut loaded.skills {
        if let Some(age) = skill_ages
            .get(&skill.skill_id)
            .and_then(|ages| ages.iter().min().copied())
        {
            skill.recommended_age = age;
            skill.recommended_level = age_band_label(age);
        }
    }

    for material in &mut loaded.material_documents {
        if let Some(age) = material_ages
            .get(&material.id)
            .and_then(|ages| ages.iter().min().copied())
        {
            material.recommended_age = age;
        }
    }
    for material in &mut loaded.material_index {
        if let Some(age) = material_ages
            .get(&material.material_id)
            .and_then(|ages| ages.iter().min().copied())
        {
            material.recommended_age = age;
        }
    }
}

fn validate_library_document_routes(documents: &[LibraryDocument]) -> anyhow::Result<()> {
    ensure_unique_ids(
        documents.iter().map(|document| document.source_path.as_str()),
        "library document source path",
    )?;
    ensure_unique_ids(
        documents.iter().map(|document| document.route_path.as_str()),
        "library document route path",
    )?;

    let known_source_paths: BTreeSet<_> = documents.iter().map(|document| document.source_path.as_str()).collect();

    for document in documents {
        for target in extract_markdown_link_targets(&document.body) {
            let Some(resolved_path) = resolve_library_markdown_target(&document.source_path, &target)? else {
                continue;
            };
            if !known_source_paths.contains(resolved_path.as_str()) {
                bail!(
                    "library document '{}' links to missing document '{}' via '{}'",
                    document.source_path,
                    resolved_path,
                    target
                );
            }
        }
    }

    Ok(())
}

fn extract_markdown_link_targets(body: &str) -> Vec<String> {
    let mut targets = Vec::new();
    let bytes = body.as_bytes();
    let mut index = 0usize;

    while index + 1 < bytes.len() {
        if bytes[index] == b'!' {
            index += 1;
            continue;
        }
        if bytes[index] == b']' && bytes[index + 1] == b'(' {
            let start = index + 2;
            let mut end = start;
            while end < bytes.len() && bytes[end] != b')' {
                end += 1;
            }
            if end < bytes.len() {
                let candidate = body[start..end].trim();
                if !candidate.is_empty() {
                    targets.push(candidate.to_string());
                }
                index = end;
            }
        }
        index += 1;
    }

    targets
}

fn resolve_library_markdown_target(current_source_path: &str, target: &str) -> anyhow::Result<Option<String>> {
    if target.starts_with('#')
        || target.starts_with("http://")
        || target.starts_with("https://")
        || target.starts_with("mailto:")
    {
        return Ok(None);
    }

    let without_fragment = target.split('#').next().unwrap_or("");
    let without_query = without_fragment.split('?').next().unwrap_or("").trim();
    if without_query.is_empty() || !without_query.ends_with(".md") {
        return Ok(None);
    }

    let current_parent = Path::new(current_source_path)
        .parent()
        .ok_or_else(|| anyhow!("document '{}' has no parent path", current_source_path))?;
    let joined = current_parent.join(without_query);
    let normalized = normalize_relative_path(&joined);

    if !normalized.starts_with("library/") {
        return Ok(None);
    }

    Ok(Some(normalized))
}

fn normalize_relative_path(path: &Path) -> String {
    let mut normalized = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                normalized.pop();
            }
            Component::Normal(part) => normalized.push(part),
            Component::RootDir | Component::Prefix(_) => {}
        }
    }
    normalized.to_string_lossy().replace('\\', "/")
}

fn route_path_from_source_path(source_path: &str) -> anyhow::Result<String> {
    let trimmed = source_path
        .strip_prefix("library/")
        .ok_or_else(|| anyhow!("library document '{}' must live under library/", source_path))?;
    let route = trimmed
        .strip_suffix(".md")
        .ok_or_else(|| anyhow!("library document '{}' must end with .md", source_path))?;
    Ok(route.to_string())
}

fn lookup_required<'a, T>(
    map: &'a HashMap<&str, &'a T>,
    key: &str,
    label: &str,
    owner_id: &str,
) -> anyhow::Result<&'a T> {
    map.get(key)
        .copied()
        .ok_or_else(|| anyhow!("{} '{}' references missing id '{}'", label, owner_id, key))
}

fn validate_pathways(
    pathways: &[Pathway],
    subjects: &[Subject],
    areas: &[Area],
    stages: &[Stage],
    playlists: &[Playlist],
) -> anyhow::Result<()> {
    ensure_unique_ids(pathways.iter().map(|pathway| pathway.pathway_id.as_str()), "pathway")?;

    let subject_ids: BTreeSet<_> = subjects.iter().map(|subject| subject.subject_id.as_str()).collect();
    let area_ids: BTreeSet<_> = areas.iter().map(|area| area.area_id.as_str()).collect();
    let area_map: HashMap<_, _> = areas.iter().map(|area| (area.area_id.as_str(), area)).collect();
    let stage_map: HashMap<_, _> = stages.iter().map(|stage| (stage.stage_id.as_str(), stage)).collect();
    let playlist_map: HashMap<_, _> = playlists
        .iter()
        .map(|playlist| (playlist.playlist_id.as_str(), playlist))
        .collect();

    for pathway in pathways {
        ensure_contains(
            &subject_ids,
            pathway.subject_id.as_str(),
            "pathway subject",
            &pathway.pathway_id,
        )?;
        ensure_contains(&area_ids, pathway.area_id.as_str(), "pathway area", &pathway.pathway_id)?;
        let pathway_area = lookup_required(&area_map, pathway.area_id.as_str(), "pathway area", &pathway.pathway_id)?;
        if pathway_area.subject_id != pathway.subject_id {
            bail!(
                "pathway '{}' uses area '{}' from a different subject",
                pathway.pathway_id,
                pathway.area_id
            );
        }
        if pathway.stage_ids.is_empty() {
            bail!("pathway '{}' has no stages", pathway.pathway_id);
        }
        if pathway.playlist_ids.is_empty() {
            bail!("pathway '{}' has no playlists", pathway.pathway_id);
        }
        if pathway.recommended_age_min > pathway.recommended_age_max {
            bail!("pathway '{}' has an invalid recommended age range", pathway.pathway_id);
        }

        for stage_id in &pathway.stage_ids {
            let stage = lookup_required(&stage_map, stage_id.as_str(), "pathway stage", &pathway.pathway_id)?;
            if stage.subject_id != pathway.subject_id || stage.area_id != pathway.area_id {
                bail!(
                    "pathway '{}' mixes subject or area boundaries with stage '{}'",
                    pathway.pathway_id,
                    stage_id
                );
            }
        }

        for playlist_id in &pathway.playlist_ids {
            let playlist = lookup_required(
                &playlist_map,
                playlist_id.as_str(),
                "pathway playlist",
                &pathway.pathway_id,
            )?;
            if playlist.subject_id != pathway.subject_id || playlist.area_id != pathway.area_id {
                bail!(
                    "pathway '{}' mixes subject or area boundaries with playlist '{}'",
                    pathway.pathway_id,
                    playlist_id
                );
            }
        }

        for entry_playlist_id in pathway.entry_points.values() {
            if !pathway.playlist_ids.contains(entry_playlist_id) {
                bail!(
                    "pathway '{}' entry point '{}' is not listed in pathway playlists",
                    pathway.pathway_id,
                    entry_playlist_id
                );
            }
        }
    }

    Ok(())
}

fn validate_catalog(
    _content_root: &Path,
    subjects: &[Subject],
    areas: &[Area],
    skills: &[Skill],
    stages: &[Stage],
    playlists: &[Playlist],
    materials: &[MaterialIndexItem],
    material_documents: &[MaterialDocument],
) -> anyhow::Result<()> {
    ensure_unique_ids(subjects.iter().map(|subject| subject.subject_id.as_str()), "subject")?;
    ensure_unique_ids(areas.iter().map(|area| area.area_id.as_str()), "area")?;
    ensure_unique_ids(skills.iter().map(|skill| skill.skill_id.as_str()), "skill")?;
    ensure_unique_ids(stages.iter().map(|stage| stage.stage_id.as_str()), "stage")?;
    ensure_unique_ids(
        playlists.iter().map(|playlist| playlist.playlist_id.as_str()),
        "playlist",
    )?;
    ensure_unique_ids(
        materials.iter().map(|material| material.material_id.as_str()),
        "material",
    )?;
    ensure_unique_ids(materials.iter().map(|material| material.path.as_str()), "material path")?;

    let subject_ids: BTreeSet<_> = subjects.iter().map(|subject| subject.subject_id.as_str()).collect();
    let area_ids: BTreeSet<_> = areas.iter().map(|area| area.area_id.as_str()).collect();
    let skill_ids: BTreeSet<_> = skills.iter().map(|skill| skill.skill_id.as_str()).collect();
    let stage_ids: BTreeSet<_> = stages.iter().map(|stage| stage.stage_id.as_str()).collect();
    let material_ids: BTreeSet<_> = material_documents.iter().map(|item| item.id.as_str()).collect();
    let area_map: HashMap<_, _> = areas.iter().map(|area| (area.area_id.as_str(), area)).collect();
    let skill_map: HashMap<_, _> = skills.iter().map(|skill| (skill.skill_id.as_str(), skill)).collect();
    let stage_map: HashMap<_, _> = stages.iter().map(|stage| (stage.stage_id.as_str(), stage)).collect();
    let material_map: HashMap<_, _> = material_documents
        .iter()
        .map(|material| (material.id.as_str(), material))
        .collect();

    for area in areas {
        ensure_contains(&subject_ids, area.subject_id.as_str(), "area subject", &area.area_id)?;
    }

    for skill in skills {
        ensure_contains(
            &subject_ids,
            skill.subject_id.as_str(),
            "skill subject",
            &skill.skill_id,
        )?;
        ensure_contains(&area_ids, skill.area_id.as_str(), "skill area", &skill.skill_id)?;
        let skill_area = lookup_required(&area_map, skill.area_id.as_str(), "skill area", &skill.skill_id)?;
        if skill_area.subject_id != skill.subject_id {
            bail!(
                "skill '{}' uses area '{}' from a different subject",
                skill.skill_id,
                skill.area_id
            );
        }
    }

    for stage in stages {
        ensure_contains(
            &subject_ids,
            stage.subject_id.as_str(),
            "stage subject",
            &stage.stage_id,
        )?;
        ensure_contains(&area_ids, stage.area_id.as_str(), "stage area", &stage.stage_id)?;
        if stage.skill_ids.is_empty() {
            bail!("stage '{}' has no skills", stage.stage_id);
        }
        for skill_id in &stage.skill_ids {
            ensure_contains(&skill_ids, skill_id.as_str(), "stage skill", &stage.stage_id)?;
            let stage_skill = lookup_required(&skill_map, skill_id.as_str(), "stage skill", &stage.stage_id)?;
            if stage_skill.subject_id != stage.subject_id || stage_skill.area_id != stage.area_id {
                bail!(
                    "stage '{}' mixes subject or area boundaries with skill '{}'",
                    stage.stage_id,
                    skill_id
                );
            }
        }
    }

    for playlist in playlists {
        ensure_contains(
            &subject_ids,
            playlist.subject_id.as_str(),
            "playlist subject",
            &playlist.playlist_id,
        )?;
        ensure_contains(
            &area_ids,
            playlist.area_id.as_str(),
            "playlist area",
            &playlist.playlist_id,
        )?;
        if playlist.stage_ids.is_empty() {
            bail!("playlist '{}' has no stages", playlist.playlist_id);
        }
        if playlist.skill_ids.is_empty() {
            bail!("playlist '{}' has no skills", playlist.playlist_id);
        }
        if playlist.session_pattern.sessions.is_empty() {
            bail!("playlist '{}' has no sessions", playlist.playlist_id);
        }

        let mut allowed_stage_skills = BTreeSet::new();
        for stage_id in &playlist.stage_ids {
            ensure_contains(&stage_ids, stage_id.as_str(), "playlist stage", &playlist.playlist_id)?;
            let playlist_stage =
                lookup_required(&stage_map, stage_id.as_str(), "playlist stage", &playlist.playlist_id)?;
            if playlist_stage.subject_id != playlist.subject_id || playlist_stage.area_id != playlist.area_id {
                bail!(
                    "playlist '{}' mixes subject or area boundaries with stage '{}'",
                    playlist.playlist_id,
                    stage_id
                );
            }
            for skill_id in &playlist_stage.skill_ids {
                allowed_stage_skills.insert(skill_id.as_str());
            }
        }
        for skill_id in &playlist.skill_ids {
            ensure_contains(&skill_ids, skill_id.as_str(), "playlist skill", &playlist.playlist_id)?;
            let playlist_skill =
                lookup_required(&skill_map, skill_id.as_str(), "playlist skill", &playlist.playlist_id)?;
            if playlist_skill.subject_id != playlist.subject_id || playlist_skill.area_id != playlist.area_id {
                bail!(
                    "playlist '{}' mixes subject or area boundaries with skill '{}'",
                    playlist.playlist_id,
                    skill_id
                );
            }
            if !allowed_stage_skills.contains(skill_id.as_str()) {
                bail!(
                    "playlist '{}' includes skill '{}' outside its declared stages",
                    playlist.playlist_id,
                    skill_id
                );
            }
        }

        let playlist_skill_set: BTreeSet<&str> = playlist.skill_ids.iter().map(|skill_id| skill_id.as_str()).collect();
        let playlist_stage_set: BTreeSet<&str> = playlist.stage_ids.iter().map(|stage_id| stage_id.as_str()).collect();
        let mut covered_skills = BTreeSet::new();
        let mut introduced_lesson_skills = BTreeSet::new();
        let mut playlist_material_kinds = BTreeSet::new();
        let mut seen_day_offsets = BTreeSet::new();
        for session in &playlist.session_pattern.sessions {
            if session.day_offset < 0 {
                bail!("playlist {} uses a negative day_offset", playlist.playlist_id);
            }
            if !seen_day_offsets.insert(session.day_offset) {
                bail!(
                    "playlist '{}' repeats day_offset {}",
                    playlist.playlist_id,
                    session.day_offset
                );
            }
            if session.skill_ids.is_empty() {
                bail!(
                    "playlist '{}' has session '{}' with no skills",
                    playlist.playlist_id,
                    session.title
                );
            }
            if session.material_ids.is_empty() {
                bail!(
                    "playlist '{}' has session '{}' with no materials",
                    playlist.playlist_id,
                    session.title
                );
            }

            let mut session_supported_skills = BTreeSet::new();
            let mut session_kinds = BTreeSet::new();
            let mut session_lesson_skills = BTreeSet::new();
            let mut session_practice_skills = BTreeSet::new();
            let mut session_prior_instruction_skills = BTreeSet::new();
            for skill_id in &session.skill_ids {
                ensure_contains(&skill_ids, skill_id.as_str(), "session skill", &playlist.playlist_id)?;
                if !playlist_skill_set.contains(skill_id.as_str()) {
                    bail!(
                        "playlist '{}' session '{}' uses undeclared playlist skill '{}'",
                        playlist.playlist_id,
                        session.title,
                        skill_id
                    );
                }
                let session_skill =
                    lookup_required(&skill_map, skill_id.as_str(), "session skill", &playlist.playlist_id)?;
                if session_skill.subject_id != playlist.subject_id || session_skill.area_id != playlist.area_id {
                    bail!(
                        "playlist '{}' session '{}' mixes subject or area boundaries with skill '{}'",
                        playlist.playlist_id,
                        session.title,
                        skill_id
                    );
                }
                covered_skills.insert(skill_id.as_str());
            }
            for material_id in &session.material_ids {
                ensure_contains(
                    &material_ids,
                    material_id.as_str(),
                    "session material",
                    &playlist.playlist_id,
                )?;
                let session_material = lookup_required(
                    &material_map,
                    material_id.as_str(),
                    "session material",
                    &playlist.playlist_id,
                )?;
                session_kinds.insert(session_material.kind.as_str());
                playlist_material_kinds.insert(session_material.kind.as_str());
                if session_material.subject_id != playlist.subject_id || session_material.area_id != playlist.area_id {
                    bail!(
                        "playlist '{}' session '{}' mixes subject or area boundaries with material '{}'",
                        playlist.playlist_id,
                        session.title,
                        material_id
                    );
                }
                if !session_material
                    .stage_ids
                    .iter()
                    .any(|stage_id| playlist_stage_set.contains(stage_id.as_str()))
                {
                    bail!(
                        "playlist '{}' session '{}' uses material '{}' outside the playlist stages",
                        playlist.playlist_id,
                        session.title,
                        material_id
                    );
                }

                let mut matched_skill = false;
                for material_skill_id in &session_material.skill_ids {
                    if session.skill_ids.contains(material_skill_id) {
                        session_supported_skills.insert(material_skill_id.as_str());
                        match session_material.kind.as_str() {
                            LESSON_NOTE_KIND => {
                                session_lesson_skills.insert(material_skill_id.as_str());
                            }
                            WORKSHEET_KIND => {
                                session_practice_skills.insert(material_skill_id.as_str());
                            }
                            DRILL_KIND => {
                                session_practice_skills.insert(material_skill_id.as_str());
                                session_prior_instruction_skills.insert(material_skill_id.as_str());
                            }
                            QUICK_CHECK_KIND => {
                                session_prior_instruction_skills.insert(material_skill_id.as_str());
                            }
                            _ => {}
                        }
                        matched_skill = true;
                    }
                }
                if !matched_skill {
                    bail!(
                        "playlist '{}' session '{}' uses material '{}' without matching session skills",
                        playlist.playlist_id,
                        session.title,
                        material_id
                    );
                }
            }

            if session_kinds.len() == 1 && session_kinds.contains(TEACHING_NOTE_KIND) {
                bail!(
                    "playlist '{}' session '{}' is adult-only; scheduled learner sessions need at least one learner-facing material",
                    playlist.playlist_id,
                    session.title
                );
            }

            let mut instruction_available_now = introduced_lesson_skills.clone();
            instruction_available_now.extend(session_lesson_skills.iter().copied());
            for skill_id in &session_practice_skills {
                if !instruction_available_now.contains(skill_id) {
                    bail!(
                        "playlist '{}' session '{}' practices skill '{}' before a lesson_note teaches it",
                        playlist.playlist_id,
                        session.title,
                        skill_id
                    );
                }
            }
            for skill_id in &session_prior_instruction_skills {
                if !introduced_lesson_skills.contains(skill_id) {
                    bail!(
                        "playlist '{}' session '{}' uses '{}' before a prior lesson_note introduces skill '{}'",
                        playlist.playlist_id,
                        session.title,
                        session
                            .material_ids
                            .iter()
                            .find_map(|material_id| material_map.get(material_id.as_str()))
                            .filter(|material| {
                                matches!(material.kind.as_str(), DRILL_KIND | QUICK_CHECK_KIND)
                                    && material.skill_ids.iter().any(|item| item == skill_id)
                            })
                            .map(|material| material.kind.as_str())
                            .unwrap_or("material"),
                        skill_id
                    );
                }
            }
            introduced_lesson_skills.extend(session_lesson_skills.iter().copied());

            for skill_id in &session.skill_ids {
                if !session_supported_skills.contains(skill_id.as_str()) {
                    bail!(
                        "playlist '{}' session '{}' has no material covering skill '{}'",
                        playlist.playlist_id,
                        session.title,
                        skill_id
                    );
                }
            }
        }

        for skill_id in &playlist.skill_ids {
            if !covered_skills.contains(skill_id.as_str()) {
                bail!(
                    "playlist '{}' declares skill '{}' but no session covers it",
                    playlist.playlist_id,
                    skill_id
                );
            }
        }

        if !playlist_material_kinds.contains(LESSON_NOTE_KIND) {
            bail!("playlist '{}' is missing a lesson_note material", playlist.playlist_id);
        }
        if !(playlist_material_kinds.contains(WORKSHEET_KIND) || playlist_material_kinds.contains(DRILL_KIND)) {
            bail!(
                "playlist '{}' is missing learner practice material; add a worksheet or drill",
                playlist.playlist_id
            );
        }
        if !playlist_material_kinds.contains(QUICK_CHECK_KIND) {
            bail!("playlist '{}' is missing a quick_check material", playlist.playlist_id);
        }
    }

    for material in materials {
        let expected_prefix = format!("library/{}/{}/", material.subject_id, material.area_id);
        if !material.path.starts_with(&expected_prefix) || !material.path.contains("/materials/") {
            bail!(
                "material '{}' must live under '{}' and a materials directory",
                material.material_id,
                expected_prefix
            );
        }
    }

    for material in material_documents {
        ensure_contains(
            &subject_ids,
            material.subject_id.as_str(),
            "material subject",
            &material.id,
        )?;
        ensure_contains(&area_ids, material.area_id.as_str(), "material area", &material.id)?;
        if !is_supported_material_kind(material.kind.as_str()) {
            bail!(
                "material '{}' uses unsupported kind '{}'; supported kinds are lesson_note, teaching_note, worksheet, drill, and quick_check",
                material.id,
                material.kind
            );
        }
        if material.runtime.is_some() && !runtime_allowed_for_kind(material.kind.as_str()) {
            bail!(
                "material '{}' uses runtime but kind '{}' is not executable",
                material.id,
                material.kind
            );
        }
        if material.skill_ids.is_empty() {
            bail!("material '{}' has no skills", material.id);
        }
        if material.stage_ids.is_empty() {
            bail!("material '{}' has no stages", material.id);
        }

        let mut allowed_stage_skills = BTreeSet::new();
        for skill_id in &material.skill_ids {
            ensure_contains(&skill_ids, skill_id.as_str(), "material skill", &material.id)?;
            let material_skill = lookup_required(&skill_map, skill_id.as_str(), "material skill", &material.id)?;
            if material_skill.subject_id != material.subject_id || material_skill.area_id != material.area_id {
                bail!(
                    "material '{}' mixes subject or area boundaries with skill '{}'",
                    material.id,
                    skill_id
                );
            }
        }
        for stage_id in &material.stage_ids {
            ensure_contains(&stage_ids, stage_id.as_str(), "material stage", &material.id)?;
            let material_stage = lookup_required(&stage_map, stage_id.as_str(), "material stage", &material.id)?;
            if material_stage.subject_id != material.subject_id || material_stage.area_id != material.area_id {
                bail!(
                    "material '{}' mixes subject or area boundaries with stage '{}'",
                    material.id,
                    stage_id
                );
            }
            for skill_id in &material_stage.skill_ids {
                allowed_stage_skills.insert(skill_id.as_str());
            }
        }

        for skill_id in &material.skill_ids {
            if !allowed_stage_skills.contains(skill_id.as_str()) {
                bail!(
                    "material '{}' includes skill '{}' outside its declared stages",
                    material.id,
                    skill_id
                );
            }
        }
    }

    for subject in subjects {
        if !areas.iter().any(|area| area.subject_id == subject.subject_id) {
            bail!("subject '{}' has no areas", subject.subject_id);
        }
        if !skills.iter().any(|skill| skill.subject_id == subject.subject_id) {
            bail!("subject '{}' has no skills", subject.subject_id);
        }
        if !stages.iter().any(|stage| stage.subject_id == subject.subject_id) {
            bail!("subject '{}' has no stages", subject.subject_id);
        }
        if !playlists
            .iter()
            .any(|playlist| playlist.subject_id == subject.subject_id)
        {
            bail!("subject '{}' has no playlists", subject.subject_id);
        }
        if !material_documents
            .iter()
            .any(|material| material.subject_id == subject.subject_id)
        {
            bail!("subject '{}' has no materials", subject.subject_id);
        }
    }

    for area in areas {
        if !skills.iter().any(|skill| skill.area_id == area.area_id) {
            bail!("area '{}' has no skills", area.area_id);
        }
        if !stages.iter().any(|stage| stage.area_id == area.area_id) {
            bail!("area '{}' has no stages", area.area_id);
        }
        if !playlists.iter().any(|playlist| playlist.area_id == area.area_id) {
            bail!("area '{}' has no playlists", area.area_id);
        }
        if !material_documents
            .iter()
            .any(|material| material.area_id == area.area_id)
        {
            bail!("area '{}' has no materials", area.area_id);
        }
    }

    for skill in skills {
        if !stages.iter().any(|stage| stage.skill_ids.contains(&skill.skill_id)) {
            bail!("skill '{}' is not grouped into any stage", skill.skill_id);
        }
        if !material_documents
            .iter()
            .any(|material| material.skill_ids.contains(&skill.skill_id))
        {
            bail!("skill '{}' is not used by any material", skill.skill_id);
        }
        if !playlists
            .iter()
            .any(|playlist| playlist.skill_ids.contains(&skill.skill_id))
        {
            bail!("skill '{}' is not used by any playlist", skill.skill_id);
        }
        if !playlists.iter().any(|playlist| {
            playlist
                .session_pattern
                .sessions
                .iter()
                .any(|session| session.skill_ids.contains(&skill.skill_id))
        }) {
            bail!("skill '{}' is not taught in any playlist session", skill.skill_id);
        }
    }

    for stage in stages {
        if !playlists
            .iter()
            .any(|playlist| playlist.stage_ids.contains(&stage.stage_id))
        {
            bail!("stage '{}' is not used by any playlist", stage.stage_id);
        }
        if !material_documents
            .iter()
            .any(|material| material.stage_ids.contains(&stage.stage_id))
        {
            bail!("stage '{}' is not used by any material", stage.stage_id);
        }
    }

    for material in material_documents {
        if !playlists.iter().any(|playlist| {
            playlist
                .session_pattern
                .sessions
                .iter()
                .any(|session| session.material_ids.contains(&material.id))
        }) {
            bail!("material '{}' is not used by any playlist session", material.id);
        }
    }

    Ok(())
}

fn ensure_unique_ids<'a>(ids: impl Iterator<Item = &'a str>, label: &str) -> anyhow::Result<()> {
    let mut seen = BTreeSet::new();
    for id in ids {
        if !seen.insert(id.to_string()) {
            bail!("duplicate {} id '{}'", label, id);
        }
    }
    Ok(())
}

fn ensure_contains(allowed: &BTreeSet<&str>, value: &str, label: &str, owner_id: &str) -> anyhow::Result<()> {
    if !allowed.contains(value) {
        bail!("{} '{}' references missing id '{}'", label, owner_id, value);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_the_repo_catalog() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../content")
            .canonicalize()
            .expect("content root");
        let result = load_library_bundle(&root);
        assert!(result.is_ok(), "catalog should load: {result:?}");
    }
}
