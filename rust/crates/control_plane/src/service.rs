use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;

use anyhow::{Context, anyhow, bail};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use catalog::{
    BootstrapMembership, BootstrapUser, IdentityBootstrap, LibraryBundle, LibraryDocument, LibraryValidationReport,
    PlaylistSession, load_bootstrap, load_library_content,
};
use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc};
use learning_activity_runtime::{self as runtime, GeneratedActivity, ScoredActivity};
use reqwest::Url;
use serde_json::{Value as JsonValue, json};
use sha2::{Digest, Sha256};
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, query, query_as, query_scalar};
use tokio::fs;
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::config::AppConfig;
use crate::domain::{
    ActivityInstance, ActivityItem, ActivityScoringSummary, ActivityStartResponse, ActivitySummary, AssignmentRequest,
    AssignmentResponse, AssignmentRow, AssignmentSummary, AuthOptionsSummary, BootstrapApplyResponse,
    CompleteActivityRequest, CompleteActivityResponse, DashboardResponse, EvidenceRow, EvidenceSummary,
    LearnerAssignedPathwaySummary, LearnerContinueBlock, LearnerDashboard, LearnerDetailResponse,
    LearnerJourneySummary, LearnerProgressSnapshot, LearnerRecentWinSummary, LearnerRow, LearnerSummary,
    LearnerWorkspaceSummary, LibraryDocumentPayload, LibraryDocumentSummary, LibraryReloadResponse,
    LibraryWorkspaceResponse, MaterialWorkspaceSummary, PathwayEntryPointSummary, PathwayWorkspaceSummary,
    PlaylistAssignmentTargetSummary, PlaylistDeliveryShapeSummary, PlaylistSessionWorkspaceSummary,
    PlaylistWorkspaceSummary, RecordSessionRequest, RecordSessionResponse, ReviewItemRow, ReviewItemSummary,
    ReviewRebuildResponse, SessionDetail, SessionMaterialKindGroupSummary, SessionMaterialRow,
    SessionMaterialRuntimeSummary, SessionMaterialSummary, SessionRow, SessionSummary, SkillProgressRow,
    SkillProgressSummary, StageProgress, TeamMemberRow, TeamMemberSummary, TeamRow, TeamSummary, ViewerSessionResponse,
    WorkspaceMaterialKindGroupSummary,
};

static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("./migrations");

const LESSON_NOTE_KIND: &str = "lesson_note";
const TEACHING_NOTE_KIND: &str = "teaching_note";
const WORKSHEET_KIND: &str = "worksheet";
const DRILL_KIND: &str = "drill";
const QUICK_CHECK_KIND: &str = "quick_check";
const AUDIENCE_ADULT: &str = "adult";
const AUDIENCE_LEARNER: &str = "learner";
const MATERIAL_KIND_ORDER: [&str; 5] = [
    LESSON_NOTE_KIND,
    TEACHING_NOTE_KIND,
    WORKSHEET_KIND,
    DRILL_KIND,
    QUICK_CHECK_KIND,
];
const DOMINANT_KIND_ORDER: [&str; 5] = [
    QUICK_CHECK_KIND,
    DRILL_KIND,
    WORKSHEET_KIND,
    LESSON_NOTE_KIND,
    TEACHING_NOTE_KIND,
];
const GOOGLE_OAUTH_AUTHORIZE_ENDPOINT: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_OAUTH_TOKEN_ENDPOINT: &str = "https://oauth2.googleapis.com/token";
const GOOGLE_USERINFO_ENDPOINT: &str = "https://openidconnect.googleapis.com/v1/userinfo";
const GOOGLE_OAUTH_CALLBACK_PATH: &str = "/api/v1/auth/google/callback";
const GOOGLE_OAUTH_FLOW_TTL_MINUTES: i64 = 15;
const WEB_SESSION_TTL_DAYS: i64 = 30;

#[derive(Clone)]
pub struct AppState {
    pub config: AppConfig,
    pub pool: PgPool,
    pub http_client: reqwest::Client,
    pub library: Arc<RwLock<LibraryBundle>>,
    pub library_documents: Arc<RwLock<Vec<LibraryDocument>>>,
    pub library_report: Arc<RwLock<LibraryValidationReport>>,
}

fn role_can_manage_team(role: &str) -> bool {
    role == "owner"
}

fn role_can_open_developer_docs(role: &str) -> bool {
    role == "owner"
}

fn auth_options(config: &AppConfig) -> AuthOptionsSummary {
    AuthOptionsSummary {
        google_signin: google_signin_configured(config),
    }
}

fn google_signin_configured(config: &AppConfig) -> bool {
    config
        .google_oauth_client_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .is_some()
        && config
            .google_oauth_client_secret
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .is_some()
}

fn sanitize_next_path(next_path: Option<&str>) -> String {
    let value = next_path.unwrap_or("/").trim();
    if value.is_empty() || !value.starts_with('/') || value.starts_with("//") {
        "/".to_string()
    } else {
        value.to_string()
    }
}

fn google_code_challenge(code_verifier: &str) -> String {
    let digest = Sha256::digest(code_verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
}

#[derive(Debug, Clone)]
struct BootstrapTeamRecord {
    team_id: String,
    display_name: String,
    description: String,
}

#[derive(Debug, Clone)]
struct BootstrapMembershipRecord {
    team_id: String,
    user_id: String,
    role: String,
}

#[derive(Debug, Clone)]
struct NormalizedBootstrap {
    teams: Vec<BootstrapTeamRecord>,
    users: Vec<BootstrapUser>,
    memberships: Vec<BootstrapMembershipRecord>,
    learner_count: usize,
}

#[derive(Debug, Clone)]
pub struct SessionContext {
    pub team_id: String,
    pub authenticated_user: TeamMemberSummary,
    pub active_user: TeamMemberSummary,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct WebSessionRow {
    session_id: Uuid,
    team_id: String,
    authenticated_user_id: String,
    active_user_id: String,
    expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct GoogleOAuthFlowRow {
    state: String,
    code_verifier: String,
    next_path: String,
    redirect_uri: String,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, serde::Deserialize)]
struct GoogleOAuthUserInfo {
    sub: String,
    email: String,
    #[serde(default)]
    email_verified: bool,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    picture: Option<String>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct GoogleOwnerCandidateRow {
    user_id: String,
    email: Option<String>,
    google_subject: Option<String>,
}

#[derive(Debug, Clone)]
struct ResolvedGoogleOwner {
    authenticated_user_id: String,
    default_team_id: String,
}

fn normalize_required_string(value: &str, field: &str) -> anyhow::Result<String> {
    let normalized = value.trim();
    if normalized.is_empty() {
        bail!("{field} cannot be empty");
    }
    Ok(normalized.to_string())
}

fn normalize_optional_string(value: Option<&str>) -> Option<String> {
    value
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn normalize_optional_email(value: Option<&str>) -> Option<String> {
    value
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_ascii_lowercase())
}

fn normalized_bootstrap_user(user: &BootstrapUser) -> anyhow::Result<BootstrapUser> {
    Ok(BootstrapUser {
        user_id: normalize_required_string(&user.user_id, "user_id")?,
        username: normalize_required_string(&user.username, "username")?,
        display_name: normalize_required_string(&user.display_name, "display_name")?,
        first_name: normalize_optional_string(user.first_name.as_deref()),
        last_name: normalize_optional_string(user.last_name.as_deref()),
        email: normalize_optional_email(user.email.as_deref()),
        google_subject: normalize_optional_string(user.google_subject.as_deref()),
        google_email: normalize_optional_email(user.google_email.as_deref()),
        date_of_birth: user.date_of_birth,
        sex: normalize_optional_string(user.sex.as_deref()),
        current_level: normalize_optional_string(user.current_level.as_deref()),
        notes: normalize_optional_string(user.notes.as_deref()),
    })
}

fn normalized_bootstrap_membership(membership: &BootstrapMembership) -> anyhow::Result<BootstrapMembership> {
    Ok(BootstrapMembership {
        user_id: normalize_required_string(&membership.user_id, "membership.user_id")?,
        role: normalize_required_string(&membership.role, "membership.role")?,
    })
}

fn record_unique_identity_value(
    seen_values: &mut BTreeMap<String, String>,
    field: &str,
    value: Option<&str>,
    user_id: &str,
) -> anyhow::Result<()> {
    let Some(value) = value else {
        return Ok(());
    };
    if let Some(existing_user_id) = seen_values.get(value) {
        if existing_user_id != user_id {
            bail!(
                "{field} '{value}' is assigned to multiple users in identity bootstrap: '{existing_user_id}' and '{user_id}'"
            );
        }
        return Ok(());
    }
    seen_values.insert(value.to_string(), user_id.to_string());
    Ok(())
}

fn compile_bootstrap(bootstrap: &IdentityBootstrap) -> anyhow::Result<NormalizedBootstrap> {
    if bootstrap.teams.is_empty() {
        bail!("identity bootstrap must include at least one team");
    }

    let mut teams = Vec::new();
    let mut users_by_id = BTreeMap::<String, BootstrapUser>::new();
    let mut memberships = Vec::new();
    let mut learner_count = 0usize;
    let mut seen_team_ids = BTreeSet::new();
    let mut seen_usernames = BTreeMap::<String, String>::new();
    let mut seen_emails = BTreeMap::<String, String>::new();
    let mut seen_google_subjects = BTreeMap::<String, String>::new();
    let mut seen_google_emails = BTreeMap::<String, String>::new();

    for team in &bootstrap.teams {
        let team_id = normalize_required_string(&team.team_id, "team_id")?;
        if !seen_team_ids.insert(team_id.clone()) {
            bail!("team_id '{}' is defined more than once in identity bootstrap", team_id);
        }

        let display_name = normalize_required_string(&team.display_name, "display_name")?;
        let description = normalize_required_string(&team.description, "description")?;
        if team.users.is_empty() {
            bail!("team '{}' must include at least one user", team_id);
        }
        if team.memberships.is_empty() {
            bail!("team '{}' must include at least one membership", team_id);
        }

        let mut team_users = BTreeMap::<String, BootstrapUser>::new();
        for user in &team.users {
            let normalized_user = normalized_bootstrap_user(user)?;
            if team_users
                .insert(normalized_user.user_id.clone(), normalized_user.clone())
                .is_some()
            {
                bail!(
                    "user '{}' is defined more than once inside team '{}'",
                    normalized_user.user_id,
                    team_id
                );
            }

            match users_by_id.get(&normalized_user.user_id) {
                Some(existing) if existing != &normalized_user => {
                    bail!(
                        "user '{}' is defined differently across teams; keep one canonical user definition for shared owners or learners",
                        normalized_user.user_id
                    );
                }
                Some(_) => {}
                None => {
                    record_unique_identity_value(
                        &mut seen_usernames,
                        "username",
                        Some(&normalized_user.username),
                        &normalized_user.user_id,
                    )?;
                    record_unique_identity_value(
                        &mut seen_emails,
                        "email",
                        normalized_user.email.as_deref(),
                        &normalized_user.user_id,
                    )?;
                    record_unique_identity_value(
                        &mut seen_google_subjects,
                        "google_subject",
                        normalized_user.google_subject.as_deref(),
                        &normalized_user.user_id,
                    )?;
                    record_unique_identity_value(
                        &mut seen_google_emails,
                        "google_email",
                        normalized_user.google_email.as_deref(),
                        &normalized_user.user_id,
                    )?;
                    users_by_id.insert(normalized_user.user_id.clone(), normalized_user);
                }
            }
        }

        let mut team_member_ids = BTreeSet::new();
        let mut owner_count = 0usize;
        for membership in &team.memberships {
            let normalized_membership = normalized_bootstrap_membership(membership)?;
            if !team_member_ids.insert(normalized_membership.user_id.clone()) {
                bail!(
                    "user '{}' appears more than once in team '{}' memberships",
                    normalized_membership.user_id,
                    team_id
                );
            }

            let user = team_users.get(&normalized_membership.user_id).ok_or_else(|| {
                anyhow!(
                    "team '{}' membership references unknown user '{}'",
                    team_id,
                    normalized_membership.user_id
                )
            })?;

            if !matches!(normalized_membership.role.as_str(), "owner" | "learner") {
                bail!(
                    "membership role '{}' is not supported in team '{}'; use only 'owner' or 'learner'",
                    normalized_membership.role,
                    team_id
                );
            }

            if normalized_membership.role == "owner" {
                owner_count += 1;
                if user.first_name.is_none() || user.last_name.is_none() || user.email.is_none() {
                    bail!(
                        "owner user '{}' in team '{}' must set first_name, last_name, and email in identity bootstrap",
                        user.user_id,
                        team_id
                    );
                }
            }

            if normalized_membership.role == "learner" {
                learner_count += 1;
                if user.date_of_birth.is_none() || user.sex.is_none() || user.current_level.is_none() {
                    bail!(
                        "learner user '{}' in team '{}' must set date_of_birth, sex, and current_level in identity bootstrap",
                        user.user_id,
                        team_id
                    );
                }
            }

            memberships.push(BootstrapMembershipRecord {
                team_id: team_id.clone(),
                user_id: normalized_membership.user_id,
                role: normalized_membership.role,
            });
        }

        if owner_count == 0 {
            bail!("team '{}' must include at least one owner membership", team_id);
        }

        if team_users.len() != team_member_ids.len() {
            let missing_users = team_users
                .keys()
                .filter(|user_id| !team_member_ids.contains(user_id.as_str()))
                .cloned()
                .collect::<Vec<_>>();
            bail!(
                "team '{}' includes users without memberships: {}",
                team_id,
                missing_users.join(", ")
            );
        }

        teams.push(BootstrapTeamRecord {
            team_id,
            display_name,
            description,
        });
    }

    Ok(NormalizedBootstrap {
        teams,
        users: users_by_id.into_values().collect(),
        memberships,
        learner_count,
    })
}

fn ensure_viewer_can_manage_team(viewer: &TeamMemberSummary) -> anyhow::Result<()> {
    if viewer.can_manage_team {
        return Ok(());
    }
    bail!("viewer '{}' cannot manage the team workspace", viewer.username)
}

fn ensure_viewer_can_read_library(viewer: &TeamMemberSummary) -> anyhow::Result<()> {
    if viewer.can_read_library {
        return Ok(());
    }
    bail!("viewer '{}' cannot read the planning library", viewer.username)
}

fn ensure_viewer_can_access_learner(viewer: &TeamMemberSummary, learner_id: &str) -> anyhow::Result<()> {
    if viewer.can_view_all_learners {
        return Ok(());
    }
    if viewer.learner_id.as_deref() == Some(learner_id) {
        return Ok(());
    }
    bail!("viewer '{}' cannot access learner '{}'", viewer.username, learner_id)
}

fn material_audience(kind: &str) -> &'static str {
    if kind == TEACHING_NOTE_KIND {
        AUDIENCE_ADULT
    } else {
        AUDIENCE_LEARNER
    }
}

fn dominant_kind_for_materials<'a>(kinds: impl IntoIterator<Item = &'a str>) -> String {
    let kind_set: BTreeSet<&str> = kinds.into_iter().collect();
    for kind in DOMINANT_KIND_ORDER {
        if kind_set.contains(kind) {
            return kind.to_string();
        }
    }
    kind_set.iter().next().copied().unwrap_or(LESSON_NOTE_KIND).to_string()
}

fn build_workspace_material_kind_groups(
    materials: &[MaterialWorkspaceSummary],
) -> Vec<WorkspaceMaterialKindGroupSummary> {
    let mut groups = Vec::new();
    for kind in MATERIAL_KIND_ORDER {
        let grouped_materials = materials
            .iter()
            .filter(|material| material.kind == kind)
            .cloned()
            .collect::<Vec<_>>();
        if grouped_materials.is_empty() {
            continue;
        }
        groups.push(WorkspaceMaterialKindGroupSummary {
            kind: kind.to_string(),
            audience: material_audience(kind).to_string(),
            material_count: grouped_materials.len(),
            materials: grouped_materials,
        });
    }
    groups
}

fn build_session_material_kind_groups(materials: &[SessionMaterialSummary]) -> Vec<SessionMaterialKindGroupSummary> {
    let mut groups = Vec::new();
    for kind in MATERIAL_KIND_ORDER {
        let grouped_materials = materials
            .iter()
            .filter(|material| material.kind == kind)
            .cloned()
            .collect::<Vec<_>>();
        if grouped_materials.is_empty() {
            continue;
        }
        groups.push(SessionMaterialKindGroupSummary {
            kind: kind.to_string(),
            audience: material_audience(kind).to_string(),
            material_count: grouped_materials.len(),
            materials: grouped_materials,
        });
    }
    groups
}

fn session_estimated_minutes(materials: &[SessionMaterialSummary]) -> u32 {
    materials
        .iter()
        .map(|material| u32::from(material.estimated_minutes))
        .sum()
}

fn session_live_material_count(materials: &[SessionMaterialSummary]) -> usize {
    materials
        .iter()
        .filter(|material| {
            material
                .runtime
                .as_ref()
                .map(|runtime| runtime.executable)
                .unwrap_or(false)
        })
        .count()
}

fn session_material_count_for_audience(materials: &[SessionMaterialSummary], audience: &str) -> usize {
    materials
        .iter()
        .filter(|material| material.audience == audience)
        .count()
}

fn session_action_label(session: &SessionDetail) -> String {
    match session.dominant_kind.as_str() {
        TEACHING_NOTE_KIND => "Begin with adult guidance".to_string(),
        LESSON_NOTE_KIND => "Open lesson".to_string(),
        WORKSHEET_KIND => "Open practice".to_string(),
        DRILL_KIND => "Start live practice".to_string(),
        QUICK_CHECK_KIND => "Take quick check".to_string(),
        _ => "Open session".to_string(),
    }
}

fn continue_block_title(session: &SessionDetail) -> String {
    match session.dominant_kind.as_str() {
        TEACHING_NOTE_KIND => format!("Begin with {}", session.title),
        DRILL_KIND => format!("Start live practice: {}", session.title),
        QUICK_CHECK_KIND => format!("Take the check: {}", session.title),
        _ => format!("Continue with {}", session.title),
    }
}

fn continue_block_description(session: &SessionDetail) -> String {
    let minute_label = if session.estimated_minutes > 0 {
        format!("about {} min", session.estimated_minutes)
    } else {
        "a short focused block".to_string()
    };
    if session.requires_adult_support {
        format!(
            "Start with the teaching note for this session, then move into the learner work. Plan {}.",
            minute_label
        )
    } else if session.live_material_count > 0 {
        format!(
            "Open the learner materials and launch the live activity when ready. Plan {}.",
            minute_label
        )
    } else {
        format!(
            "Open the learner materials for the next step in the journey. Plan {}.",
            minute_label
        )
    }
}

fn dashboard_attention_summary(
    active_assignment: Option<&AssignmentSummary>,
    today_session: Option<&SessionSummary>,
    review_item_count: i64,
) -> (String, String, String) {
    if let Some(session) = today_session {
        return (
            "ready_now".to_string(),
            "Ready now".to_string(),
            format!("Open {}", session.title),
        );
    }
    if review_item_count > 0 {
        return (
            "review".to_string(),
            "Review waiting".to_string(),
            format!(
                "{} review item{} pending",
                review_item_count,
                if review_item_count == 1 { "" } else { "s" }
            ),
        );
    }
    if let Some(assignment) = active_assignment {
        return (
            "in_journey".to_string(),
            "On current pathway".to_string(),
            format!("{} in progress", assignment.title),
        );
    }
    (
        "needs_assignment".to_string(),
        "Needs assignment".to_string(),
        "Choose a first playlist".to_string(),
    )
}

fn build_playlist_delivery_shape(sessions: &[PlaylistSessionWorkspaceSummary]) -> PlaylistDeliveryShapeSummary {
    let mut lesson_note_count = 0usize;
    let mut teaching_note_count = 0usize;
    let mut worksheet_count = 0usize;
    let mut drill_count = 0usize;
    let mut quick_check_count = 0usize;

    for session in sessions {
        for material in &session.materials {
            match material.kind.as_str() {
                LESSON_NOTE_KIND => lesson_note_count += 1,
                TEACHING_NOTE_KIND => teaching_note_count += 1,
                WORKSHEET_KIND => worksheet_count += 1,
                DRILL_KIND => drill_count += 1,
                QUICK_CHECK_KIND => quick_check_count += 1,
                _ => {}
            }
        }
    }

    PlaylistDeliveryShapeSummary {
        estimated_total_minutes: sessions.iter().map(|session| session.estimated_minutes).sum(),
        lesson_note_count,
        teaching_note_count,
        worksheet_count,
        drill_count,
        quick_check_count,
        requires_adult_support: sessions.iter().any(|session| session.requires_adult_support),
    }
}

fn build_playlist_assignment_targets(
    playlist: &catalog::Playlist,
    learners: &[LearnerRow],
    assignments_by_learner: &BTreeMap<String, Vec<AssignmentSummary>>,
) -> Vec<PlaylistAssignmentTargetSummary> {
    let recommended_age = i32::from(playlist.recommended_age);
    learners
        .iter()
        .map(|learner| {
            let current_age = calculate_age(learner.date_of_birth);
            let assignments = assignments_by_learner
                .get(&learner.learner_id)
                .cloned()
                .unwrap_or_default();
            let assigned_here = assignments
                .iter()
                .any(|assignment| assignment.playlist_id == playlist.playlist_id);
            let assigned_assignment_titles = assignments
                .iter()
                .map(|assignment| assignment.title.clone())
                .collect::<Vec<_>>();
            let other_assignment_count = assignments.len().saturating_sub(usize::from(assigned_here));
            let (recommended, status_label) = if assigned_here {
                if other_assignment_count == 0 {
                    (true, "Assigned here now".to_string())
                } else {
                    (
                        true,
                        format!(
                            "Assigned here and on {other_assignment_count} other playlist{}",
                            if other_assignment_count == 1 { "" } else { "s" }
                        ),
                    )
                }
            } else if !assignments.is_empty() {
                if assignments.len() == 1 {
                    (false, format!("Also assigned to {}", assignments[0].title))
                } else {
                    (false, format!("Already has {} assigned playlists", assignments.len()))
                }
            } else if current_age < recommended_age - 1 {
                (
                    false,
                    format!("Usually later than the target age {}", playlist.recommended_age),
                )
            } else if current_age > recommended_age + 2 {
                (true, "Older than target; use as catch-up or review".to_string())
            } else {
                (true, "Recommended now".to_string())
            };

            PlaylistAssignmentTargetSummary {
                learner_id: learner.learner_id.clone(),
                display_name: learner.display_name.clone(),
                current_age,
                current_level: learner.current_level.clone(),
                recommended,
                status_label,
                assigned_here,
                active_assignment_title: assigned_assignment_titles.first().cloned(),
                assigned_assignment_titles,
            }
        })
        .collect()
}

async fn resolve_team_member_by_id(
    state: &Arc<AppState>,
    team_id: &str,
    user_id: &str,
) -> anyhow::Result<TeamMemberSummary> {
    let member = query_as::<_, TeamMemberRow>(
        "select
            ua.user_id,
            ua.username,
            ua.display_name,
            tm.role,
            ua.current_level,
            coalesce(ua.notes, '') as notes,
            lp.learner_id,
            ua.google_subject,
            ua.google_display_name,
            ua.google_picture_url,
            ua.google_email
         from team_membership tm
         join user_account ua on ua.user_id = tm.user_id
         left join learner_profile lp on lp.user_id = ua.user_id and lp.team_id = tm.team_id
         where tm.team_id = $1 and ua.user_id = $2
         limit 1",
    )
    .bind(team_id)
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| anyhow!("user '{}' is not a member of team '{}'", user_id, team_id))?;
    Ok(member_row_to_summary(member))
}

pub async fn initialize_state(config: AppConfig, run_startup_bootstrap: bool) -> anyhow::Result<Arc<AppState>> {
    fs::create_dir_all(&config.artifacts_root)
        .await
        .with_context(|| format!("failed to create {}", config.artifacts_root.display()))?;
    fs::create_dir_all(&config.exports_root)
        .await
        .with_context(|| format!("failed to create {}", config.exports_root.display()))?;

    let library_content = load_library_content(&config.content_root)?;
    let pool = PgPoolOptions::new()
        .max_connections(8)
        .connect(&config.database_url)
        .await
        .context("failed to connect to Postgres")?;
    MIGRATOR.run(&pool).await.context("failed to run database migrations")?;

    let state = Arc::new(AppState {
        config,
        pool,
        http_client: reqwest::Client::new(),
        library: Arc::new(RwLock::new(library_content.bundle)),
        library_documents: Arc::new(RwLock::new(library_content.documents)),
        library_report: Arc::new(RwLock::new(library_content.report)),
    });

    if run_startup_bootstrap && state.config.auto_bootstrap {
        apply_bootstrap(&state).await?;
    }

    Ok(state)
}

pub async fn migrate_database(database_url: &str) -> anyhow::Result<()> {
    let pool = PgPoolOptions::new()
        .max_connections(4)
        .connect(database_url)
        .await
        .context("failed to connect to Postgres")?;
    MIGRATOR.run(&pool).await.context("failed to run database migrations")
}

async fn create_web_session(
    state: &Arc<AppState>,
    team_id: &str,
    authenticated_user_id: &str,
    active_user_id: &str,
) -> anyhow::Result<Uuid> {
    let session_id = Uuid::new_v4();
    let now = Utc::now();
    let expires_at = now + Duration::days(WEB_SESSION_TTL_DAYS);
    query(
        "insert into web_session (
            session_id,
            team_id,
            authenticated_user_id,
            active_user_id,
            created_at,
            updated_at,
            expires_at
         ) values ($1, $2, $3, $4, $5, $6, $7)",
    )
    .bind(session_id)
    .bind(team_id)
    .bind(authenticated_user_id)
    .bind(active_user_id)
    .bind(now)
    .bind(now)
    .bind(expires_at)
    .execute(&state.pool)
    .await?;
    Ok(session_id)
}

pub async fn resolve_session_context(state: &Arc<AppState>, session_id: Uuid) -> anyhow::Result<SessionContext> {
    let row = query_as::<_, WebSessionRow>(
        "select session_id, team_id, authenticated_user_id, active_user_id, expires_at
         from web_session
         where session_id = $1",
    )
    .bind(session_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| anyhow!("session not found"))?;

    if row.expires_at <= Utc::now() {
        query("delete from web_session where session_id = $1")
            .bind(row.session_id)
            .execute(&state.pool)
            .await?;
        bail!("session expired");
    }

    query("update web_session set updated_at = $2 where session_id = $1")
        .bind(row.session_id)
        .bind(Utc::now())
        .execute(&state.pool)
        .await?;

    let authenticated_user = resolve_team_member_by_id(state, &row.team_id, &row.authenticated_user_id).await?;
    let active_user = resolve_team_member_by_id(state, &row.team_id, &row.active_user_id).await?;

    Ok(SessionContext {
        team_id: row.team_id,
        authenticated_user,
        active_user,
    })
}

async fn build_session_response(
    state: &Arc<AppState>,
    context: Option<&SessionContext>,
) -> anyhow::Result<ViewerSessionResponse> {
    let team = match context {
        Some(context) => fetch_team_summary_by_id(state, &context.team_id).await?,
        None => None,
    };
    let available_teams = match context {
        Some(context) if context.authenticated_user.can_manage_team => {
            list_owner_team_summaries_for_user(state, &context.authenticated_user.user_id).await?
        }
        _ => Vec::new(),
    };
    let available_users = match context {
        Some(context) if context.authenticated_user.can_manage_team => {
            list_team_members_for_team(state, &context.team_id).await?
        }
        Some(context) => vec![context.active_user.clone()],
        None => Vec::new(),
    };

    Ok(ViewerSessionResponse {
        status: "ok".to_string(),
        authenticated: context.is_some(),
        auth: auth_options(&state.config),
        team,
        available_teams,
        authenticated_user: context.map(|context| context.authenticated_user.clone()),
        active_user: context.map(|context| context.active_user.clone()),
        available_users,
        developer_docs_url: state.config.developer_docs_public_url.clone(),
    })
}

async fn take_google_oauth_flow(state: &Arc<AppState>, state_value: &str) -> anyhow::Result<GoogleOAuthFlowRow> {
    let flow = query_as::<_, GoogleOAuthFlowRow>(
        "select state, code_verifier, next_path, redirect_uri, created_at
         from google_oauth_flow
         where state = $1",
    )
    .bind(state_value)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| anyhow!("google sign-in flow was not found"))?;

    query("delete from google_oauth_flow where state = $1")
        .bind(&flow.state)
        .execute(&state.pool)
        .await?;

    if flow.created_at + Duration::minutes(GOOGLE_OAUTH_FLOW_TTL_MINUTES) <= Utc::now() {
        bail!("google sign-in flow expired");
    }

    Ok(flow)
}

async fn exchange_google_authorization_code(
    state: &Arc<AppState>,
    code: &str,
    flow: &GoogleOAuthFlowRow,
) -> anyhow::Result<GoogleOAuthUserInfo> {
    let response = state
        .http_client
        .post(GOOGLE_OAUTH_TOKEN_ENDPOINT)
        .form(&[
            (
                "client_id",
                state.config.google_oauth_client_id.as_deref().unwrap_or_default(),
            ),
            (
                "client_secret",
                state.config.google_oauth_client_secret.as_deref().unwrap_or_default(),
            ),
            ("code", code),
            ("code_verifier", flow.code_verifier.as_str()),
            ("grant_type", "authorization_code"),
            ("redirect_uri", flow.redirect_uri.as_str()),
        ])
        .send()
        .await
        .context("failed to exchange Google authorization code")?;

    let status = response.status();
    let payload: JsonValue = response
        .json()
        .await
        .context("failed to decode Google token response")?;
    if !status.is_success() {
        bail!(
            "{}",
            payload
                .get("error_description")
                .and_then(|value| value.as_str())
                .unwrap_or("Google token exchange failed")
        );
    }

    let access_token = payload
        .get("access_token")
        .and_then(|value| value.as_str())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| anyhow!("Google token exchange did not return an access token"))?;

    let userinfo_response = state
        .http_client
        .get(GOOGLE_USERINFO_ENDPOINT)
        .bearer_auth(access_token)
        .send()
        .await
        .context("failed to fetch Google user profile")?;
    let userinfo_status = userinfo_response.status();
    let userinfo_payload: GoogleOAuthUserInfo = userinfo_response
        .json()
        .await
        .context("failed to decode Google user profile")?;
    if !userinfo_status.is_success() {
        bail!("Google user profile lookup failed");
    }

    if !userinfo_payload.email_verified {
        bail!("Google email must be verified before sign-in is allowed");
    }
    if userinfo_payload.email.trim().is_empty() || userinfo_payload.sub.trim().is_empty() {
        bail!("Google identity is incomplete");
    }

    Ok(userinfo_payload)
}

async fn resolve_owner_for_google_identity(
    state: &Arc<AppState>,
    google_user: &GoogleOAuthUserInfo,
) -> anyhow::Result<ResolvedGoogleOwner> {
    let normalized_email = google_user.email.trim().to_ascii_lowercase();
    let normalized_subject = google_user.sub.trim();

    let owners = query_as::<_, GoogleOwnerCandidateRow>(
        "select
            ua.user_id,
            ua.email,
            ua.google_subject
         from team_membership tm
         join user_account ua on ua.user_id = tm.user_id
         where tm.role = 'owner'
           and (
               ua.google_subject = $1
               or lower(coalesce(ua.email, '')) = lower($2)
           )
         group by ua.user_id, ua.email, ua.google_subject
         order by case when ua.google_subject = $1 then 0 else 1 end, ua.user_id",
    )
    .bind(normalized_subject)
    .bind(&normalized_email)
    .fetch_all(&state.pool)
    .await?
    .into_iter()
    .collect::<Vec<_>>();

    let owner = match owners.as_slice() {
        [] => bail!("Google account is not provisioned as an owner in identity bootstrap"),
        [owner] => owner.clone(),
        _ => {
            bail!(
                "Google account matches multiple owner users. Reuse one shared user_id across teams for the same owner."
            )
        }
    };

    if let Some(existing_subject) = owner.google_subject.as_deref()
        && !existing_subject.trim().is_empty()
        && existing_subject != normalized_subject
    {
        bail!("Google account does not match the configured owner identity");
    }

    if let Some(existing_email) = owner.email.as_deref()
        && !existing_email.trim().is_empty()
        && !existing_email.eq_ignore_ascii_case(&normalized_email)
        && owner.google_subject.is_none()
    {
        bail!("Google account email does not match the configured owner email");
    }

    let google_display_name = normalize_optional_string(google_user.name.as_deref());
    let google_picture_url = normalize_optional_string(google_user.picture.as_deref());

    query(
        "update user_account
         set google_subject = $2,
             google_email = $3,
             google_display_name = $4,
             google_picture_url = $5
         where user_id = $1",
    )
    .bind(&owner.user_id)
    .bind(normalized_subject)
    .bind(&normalized_email)
    .bind(&google_display_name)
    .bind(&google_picture_url)
    .execute(&state.pool)
    .await?;

    let owner_teams = list_owner_team_summaries_for_user(state, &owner.user_id).await?;
    let default_team_id = owner_teams
        .first()
        .map(|team| team.team_id.clone())
        .ok_or_else(|| anyhow!("Google account is not provisioned as an owner in identity bootstrap"))?;

    Ok(ResolvedGoogleOwner {
        authenticated_user_id: owner.user_id,
        default_team_id,
    })
}

pub async fn reload_library(state: &Arc<AppState>, context: &SessionContext) -> anyhow::Result<LibraryReloadResponse> {
    ensure_viewer_can_manage_team(&context.authenticated_user)?;

    let library_content = load_library_content(&state.config.content_root)?;
    {
        let mut library_guard = state.library.write().await;
        *library_guard = library_content.bundle;
    }
    {
        let mut documents_guard = state.library_documents.write().await;
        *documents_guard = library_content.documents;
    }
    {
        let mut report_guard = state.library_report.write().await;
        *report_guard = library_content.report;
    }
    Ok(library_report_response(&*state.library_report.read().await))
}

pub async fn apply_bootstrap(state: &Arc<AppState>) -> anyhow::Result<BootstrapApplyResponse> {
    let bootstrap = load_bootstrap(&state.config.bootstrap_path)?;
    let normalized = compile_bootstrap(&bootstrap)?;
    let team_ids = normalized
        .teams
        .iter()
        .map(|team| team.team_id.clone())
        .collect::<Vec<_>>();

    let mut tx = state.pool.begin().await?;

    for team in &normalized.teams {
        query(
            "insert into team (team_id, display_name, description) values ($1, $2, $3)
             on conflict (team_id) do update
             set display_name = excluded.display_name,
                 description = excluded.description",
        )
        .bind(&team.team_id)
        .bind(&team.display_name)
        .bind(&team.description)
        .execute(&mut *tx)
        .await?;
    }

    for user in &normalized.users {
        query(
            "insert into user_account (
                user_id,
                username,
                display_name,
                first_name,
                last_name,
                email,
                google_subject,
                google_email,
                date_of_birth,
                sex,
                current_level,
                notes
             )
             values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
             on conflict (user_id) do update
             set username = excluded.username,
                 display_name = excluded.display_name,
                 first_name = excluded.first_name,
                 last_name = excluded.last_name,
                 email = excluded.email,
                 google_subject = coalesce(excluded.google_subject, user_account.google_subject),
                 google_email = coalesce(excluded.google_email, user_account.google_email),
                 date_of_birth = excluded.date_of_birth,
                 sex = excluded.sex,
                 current_level = excluded.current_level,
                 notes = excluded.notes",
        )
        .bind(&user.user_id)
        .bind(&user.username)
        .bind(&user.display_name)
        .bind(&user.first_name)
        .bind(&user.last_name)
        .bind(&user.email)
        .bind(&user.google_subject)
        .bind(&user.google_email)
        .bind(user.date_of_birth)
        .bind(&user.sex)
        .bind(&user.current_level)
        .bind(&user.notes)
        .execute(&mut *tx)
        .await?;
    }

    for team_id in &team_ids {
        query("delete from team_membership where team_id = $1")
            .bind(team_id)
            .execute(&mut *tx)
            .await?;
    }

    for membership in &normalized.memberships {
        query("insert into team_membership (team_id, user_id, role) values ($1, $2, $3)")
            .bind(&membership.team_id)
            .bind(&membership.user_id)
            .bind(&membership.role)
            .execute(&mut *tx)
            .await?;
    }

    query("delete from team where not (team_id = any($1))")
        .bind(&team_ids)
        .execute(&mut *tx)
        .await?;

    query(
        "delete from web_session ws
         where not exists (
             select 1
             from team_membership auth_tm
             where auth_tm.team_id = ws.team_id
               and auth_tm.user_id = ws.authenticated_user_id
         )
         or not exists (
             select 1
             from team_membership active_tm
             where active_tm.team_id = ws.team_id
               and active_tm.user_id = ws.active_user_id
         )",
    )
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(BootstrapApplyResponse {
        status: "ok".to_string(),
        team_count: normalized.teams.len(),
        user_count: normalized.users.len(),
        membership_count: normalized.memberships.len(),
        learner_count: normalized.learner_count,
    })
}

pub async fn fetch_library(
    state: &Arc<AppState>,
    context: &SessionContext,
) -> anyhow::Result<(LibraryBundle, LibraryReloadResponse)> {
    ensure_viewer_can_read_library(&context.active_user)?;

    let bundle = state.library.read().await.clone();
    let report = library_report_response(&*state.library_report.read().await);
    Ok((bundle, report))
}

pub async fn fetch_library_workspace(
    state: &Arc<AppState>,
    context: &SessionContext,
) -> anyhow::Result<LibraryWorkspaceResponse> {
    ensure_viewer_can_manage_team(&context.active_user)?;
    let team_id = context.team_id.clone();

    let library = state.library.read().await.clone();
    let documents = state.library_documents.read().await.clone();
    let learners = query_as::<_, LearnerRow>(
        "select learner_id, team_id, user_id, display_name, date_of_birth, sex, current_level, notes
         from learner_profile
         where team_id = $1
         order by display_name",
    )
    .bind(&team_id)
    .fetch_all(&state.pool)
    .await?;
    let assignments_by_learner = fetch_assignments_for_learners_map(&state.pool, &learners).await?;
    let pathways = build_library_workspace_pathways(&library, &documents, &learners, &assignments_by_learner);
    let featured_route_path = pathways.iter().find_map(|pathway| {
        pathway.route_path.clone().or_else(|| {
            pathway
                .playlists
                .iter()
                .find_map(|playlist| playlist.route_path.clone())
        })
    });

    Ok(LibraryWorkspaceResponse {
        status: "ok".to_string(),
        featured_route_path,
        pathways,
    })
}

pub async fn list_library_documents(
    state: &Arc<AppState>,
    context: &SessionContext,
) -> anyhow::Result<Vec<LibraryDocumentSummary>> {
    ensure_viewer_can_read_library(&context.active_user)?;

    Ok(state
        .library_documents
        .read()
        .await
        .iter()
        .map(library_document_summary)
        .collect())
}

pub async fn fetch_library_document(
    state: &Arc<AppState>,
    context: &SessionContext,
    route_path: &str,
) -> anyhow::Result<LibraryDocumentPayload> {
    ensure_viewer_can_read_library(&context.active_user)?;

    let normalized = route_path.trim().trim_matches('/');
    if normalized.is_empty() {
        bail!("route_path is required");
    }

    let documents = state.library_documents.read().await;
    let document = documents
        .iter()
        .find(|document| document.route_path == normalized)
        .ok_or_else(|| anyhow!("library document '{}' not found", normalized))?;
    Ok(library_document_payload(document))
}

pub async fn fetch_auth_options(state: &Arc<AppState>) -> anyhow::Result<AuthOptionsSummary> {
    Ok(auth_options(&state.config))
}

pub async fn fetch_viewer_session(
    state: &Arc<AppState>,
    session_id: Option<Uuid>,
) -> anyhow::Result<ViewerSessionResponse> {
    let context = match session_id {
        Some(session_id) => resolve_session_context(state, session_id).await.ok(),
        None => None,
    };
    build_session_response(state, context.as_ref()).await
}

pub async fn switch_active_user(
    state: &Arc<AppState>,
    session_id: Uuid,
    user_id: &str,
) -> anyhow::Result<ViewerSessionResponse> {
    let context = resolve_session_context(state, session_id).await?;
    let requested_user = resolve_team_member_by_id(state, &context.team_id, user_id).await?;
    if !context.authenticated_user.can_manage_team && requested_user.user_id != context.authenticated_user.user_id {
        bail!("current session cannot switch into that user");
    }

    query(
        "update web_session
         set active_user_id = $2, updated_at = $3
         where session_id = $1",
    )
    .bind(session_id)
    .bind(&requested_user.user_id)
    .bind(Utc::now())
    .execute(&state.pool)
    .await?;

    let updated = resolve_session_context(state, session_id).await?;
    build_session_response(state, Some(&updated)).await
}

pub async fn switch_active_team(
    state: &Arc<AppState>,
    session_id: Uuid,
    team_id: &str,
) -> anyhow::Result<ViewerSessionResponse> {
    let context = resolve_session_context(state, session_id).await?;
    let requested_team_id = team_id.trim();
    if requested_team_id.is_empty() {
        bail!("team_id is required");
    }

    let requested_owner = resolve_team_member_by_id(state, requested_team_id, &context.authenticated_user.user_id)
        .await
        .with_context(|| format!("team '{}' is not available for this owner session", requested_team_id))?;
    ensure_viewer_can_manage_team(&requested_owner)?;

    query(
        "update web_session
         set team_id = $2,
             active_user_id = $3,
             updated_at = $4
         where session_id = $1",
    )
    .bind(session_id)
    .bind(requested_team_id)
    .bind(&requested_owner.user_id)
    .bind(Utc::now())
    .execute(&state.pool)
    .await?;

    let updated = resolve_session_context(state, session_id).await?;
    build_session_response(state, Some(&updated)).await
}

pub async fn delete_viewer_session(state: &Arc<AppState>, session_id: Uuid) -> anyhow::Result<()> {
    query("delete from web_session where session_id = $1")
        .bind(session_id)
        .execute(&state.pool)
        .await?;
    Ok(())
}

pub async fn start_google_oauth_flow(state: &Arc<AppState>, next_path: Option<&str>) -> anyhow::Result<Url> {
    if !google_signin_configured(&state.config) {
        bail!("Google sign-in is not configured");
    }

    let state_value = Uuid::new_v4().simple().to_string();
    let code_verifier = format!("{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple());
    let next_path = sanitize_next_path(next_path);
    let redirect_uri = Url::parse(&state.config.frontend_public_url)?
        .join(GOOGLE_OAUTH_CALLBACK_PATH)?
        .to_string();

    query(
        "insert into google_oauth_flow (state, code_verifier, next_path, redirect_uri, created_at)
         values ($1, $2, $3, $4, $5)
         on conflict (state) do update
         set code_verifier = excluded.code_verifier,
             next_path = excluded.next_path,
             redirect_uri = excluded.redirect_uri,
             created_at = excluded.created_at",
    )
    .bind(&state_value)
    .bind(&code_verifier)
    .bind(&next_path)
    .bind(&redirect_uri)
    .bind(Utc::now())
    .execute(&state.pool)
    .await?;

    let mut url = Url::parse(GOOGLE_OAUTH_AUTHORIZE_ENDPOINT)?;
    url.query_pairs_mut()
        .append_pair(
            "client_id",
            state.config.google_oauth_client_id.as_deref().unwrap_or_default(),
        )
        .append_pair("redirect_uri", &redirect_uri)
        .append_pair("response_type", "code")
        .append_pair("scope", "openid email")
        .append_pair("state", &state_value)
        .append_pair("code_challenge", &google_code_challenge(&code_verifier))
        .append_pair("code_challenge_method", "S256")
        .append_pair("include_granted_scopes", "true")
        .append_pair("access_type", "online");
    Ok(url)
}

pub async fn finish_google_oauth_flow(
    state: &Arc<AppState>,
    returned_state: Option<&str>,
    code: Option<&str>,
    provider_error: Option<&str>,
) -> anyhow::Result<(Option<Uuid>, Url)> {
    let default_redirect = Url::parse(&state.config.frontend_public_url)?.join("/")?;

    let Some(state_value) = returned_state.map(str::trim).filter(|value| !value.is_empty()) else {
        let mut redirect = default_redirect;
        redirect.query_pairs_mut().append_pair("auth_error", "missing_state");
        return Ok((None, redirect));
    };

    let flow = take_google_oauth_flow(state, state_value).await?;
    let mut redirect = Url::parse(&state.config.frontend_public_url)?.join(&flow.next_path)?;

    if let Some(error_code) = provider_error.map(str::trim).filter(|value| !value.is_empty()) {
        redirect.query_pairs_mut().append_pair("auth_error", error_code);
        return Ok((None, redirect));
    }

    let Some(code) = code.map(str::trim).filter(|value| !value.is_empty()) else {
        redirect.query_pairs_mut().append_pair("auth_error", "missing_code");
        return Ok((None, redirect));
    };

    let google_user = exchange_google_authorization_code(state, code, &flow).await?;
    let session_owner = resolve_owner_for_google_identity(state, &google_user).await?;
    let session_id = create_web_session(
        state,
        &session_owner.default_team_id,
        &session_owner.authenticated_user_id,
        &session_owner.authenticated_user_id,
    )
    .await?;
    Ok((Some(session_id), redirect))
}

pub async fn fetch_dashboard(state: &Arc<AppState>, context: &SessionContext) -> anyhow::Result<DashboardResponse> {
    let team = fetch_team_summary_by_id(state, &context.team_id).await?;
    let team_id = context.team_id.clone();
    let learners = query_as::<_, LearnerRow>(
        "select learner_id, team_id, user_id, display_name, date_of_birth, sex, current_level, notes
         from learner_profile
         where team_id = $1
         order by display_name",
    )
    .bind(&team_id)
    .fetch_all(&state.pool)
    .await?;

    let library = state.library.read().await.clone();
    let visible_learners = if context.active_user.can_view_all_learners {
        learners
    } else if let Some(learner_id) = context.active_user.learner_id.as_deref() {
        learners
            .into_iter()
            .filter(|learner| learner.learner_id == learner_id)
            .collect()
    } else {
        Vec::new()
    };
    let learner_dashboards = build_dashboard_cards(state, &library, &visible_learners).await?;
    let library_report = if context.active_user.can_read_library {
        Some(library_report_response(&*state.library_report.read().await))
    } else {
        None
    };

    Ok(DashboardResponse {
        team,
        library: library_report,
        learners: learner_dashboards,
    })
}

pub async fn list_learners(state: &Arc<AppState>, context: &SessionContext) -> anyhow::Result<Vec<LearnerSummary>> {
    let team_id = context.team_id.clone();
    let learners = query_as::<_, LearnerRow>(
        "select learner_id, team_id, user_id, display_name, date_of_birth, sex, current_level, notes
         from learner_profile
         where team_id = $1
         order by display_name",
    )
    .bind(&team_id)
    .fetch_all(&state.pool)
    .await?;

    Ok(learners
        .into_iter()
        .filter(|learner| {
            context.active_user.can_view_all_learners
                || context.active_user.learner_id.as_deref() == Some(learner.learner_id.as_str())
        })
        .map(|learner| LearnerSummary {
            learner_id: learner.learner_id,
            display_name: learner.display_name,
            current_age: calculate_age(learner.date_of_birth),
            current_level: learner.current_level,
            notes: learner.notes,
        })
        .collect())
}

async fn load_learner_detail_payload(
    state: &Arc<AppState>,
    context: &SessionContext,
    learner_id: &str,
) -> anyhow::Result<LearnerDetailResponse> {
    ensure_viewer_can_access_learner(&context.active_user, learner_id)?;
    let team_id = context.team_id.clone();

    let learner = query_as::<_, LearnerRow>(
        "select learner_id, team_id, user_id, display_name, date_of_birth, sex, current_level, notes
         from learner_profile
         where team_id = $1 and learner_id = $2",
    )
    .bind(&team_id)
    .bind(learner_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| anyhow!("learner '{learner_id}' not found"))?;

    let assignments = fetch_assignments_for_learner(&state.pool, learner_id).await?;
    let active_assignment = assignments.first().cloned();
    let assignment_filter = active_assignment
        .as_ref()
        .map(|assignment| assignment.assignment_id.clone());
    let library = state.library.read().await.clone();
    let documents = state.library_documents.read().await.clone();
    let sessions = fetch_sessions(
        &state.pool,
        &library,
        &documents,
        learner_id,
        assignment_filter.as_deref(),
    )
    .await?;
    let progress = fetch_progress(&state.pool, learner_id).await?;
    let review_items = fetch_review_items(&state.pool, learner_id).await?;
    let journey = (assignments.len() == 1)
        .then(|| {
            active_assignment
                .as_ref()
                .map(|assignment| build_learner_journey(&library, &documents, assignment, &sessions))
        })
        .flatten();
    let assigned_journeys =
        build_assigned_journeys(&state.pool, &library, &documents, learner_id, &assignments).await?;
    let assigned_pathways = build_assigned_pathways(&library, &assigned_journeys);
    let workspace = build_learner_workspace(
        &library,
        active_assignment.as_ref(),
        journey.as_ref(),
        &sessions,
        &progress,
        &review_items,
        &assigned_journeys,
    );
    let response_sessions = response_sessions_for_assigned_journeys(&assigned_journeys, &sessions);

    Ok(LearnerDetailResponse {
        learner: LearnerSummary {
            learner_id: learner.learner_id,
            display_name: learner.display_name,
            current_age: calculate_age(learner.date_of_birth),
            current_level: learner.current_level,
            notes: learner.notes,
        },
        active_assignment,
        journey,
        assigned_journeys,
        assigned_pathways,
        sessions: response_sessions,
        progress,
        review_items,
        workspace,
    })
}

pub async fn fetch_learner_detail(
    state: &Arc<AppState>,
    context: &SessionContext,
    learner_id: &str,
) -> anyhow::Result<LearnerDetailResponse> {
    ensure_viewer_can_manage_team(&context.active_user)?;
    load_learner_detail_payload(state, context, learner_id).await
}

pub async fn fetch_learner_workspace(
    state: &Arc<AppState>,
    context: &SessionContext,
    learner_id: &str,
) -> anyhow::Result<crate::domain::LearnerWorkspaceResponse> {
    ensure_viewer_can_access_learner(&context.active_user, learner_id)?;
    let detail = load_learner_detail_payload(state, context, learner_id).await?;
    let support_workspace = context.active_user.can_manage_team;
    let sessions = if support_workspace {
        detail.sessions.clone()
    } else {
        detail
            .sessions
            .iter()
            .map(learner_safe_session_detail)
            .collect::<Vec<_>>()
    };
    let workspace = if support_workspace {
        detail.workspace.clone()
    } else {
        learner_safe_workspace_summary(&detail.workspace)
    };
    let assigned_journeys = if support_workspace {
        detail.assigned_journeys
    } else {
        detail
            .assigned_journeys
            .iter()
            .map(learner_safe_assigned_journey)
            .collect()
    };
    let assigned_pathways = if support_workspace {
        detail.assigned_pathways
    } else {
        detail
            .assigned_pathways
            .iter()
            .map(learner_safe_assigned_pathway)
            .collect()
    };
    Ok(crate::domain::LearnerWorkspaceResponse {
        status: "ok".to_string(),
        workspace_view: if support_workspace {
            "owner_support".to_string()
        } else {
            "learner".to_string()
        },
        viewer_role: context.active_user.role.clone(),
        includes_adult_materials: support_workspace,
        learner: detail.learner,
        active_assignment: detail.active_assignment,
        journey: detail.journey,
        assigned_journeys,
        assigned_pathways,
        sessions,
        progress: detail.progress,
        review_items: detail.review_items,
        workspace,
    })
}

pub async fn create_assignment(
    state: &Arc<AppState>,
    context: &SessionContext,
    request: AssignmentRequest,
) -> anyhow::Result<AssignmentResponse> {
    ensure_viewer_can_manage_team(&context.authenticated_user)?;

    let library = state.library.read().await.clone();
    let assignment = create_assignment_internal(
        state,
        &library,
        &request.learner_id,
        &request.playlist_id,
        request.start_date.unwrap_or_else(|| Utc::now().date_naive()),
    )
    .await?;
    Ok(AssignmentResponse {
        status: "ok".to_string(),
        assignment,
    })
}

pub async fn record_session(
    state: &Arc<AppState>,
    context: &SessionContext,
    session_id: &str,
    request: RecordSessionRequest,
) -> anyhow::Result<RecordSessionResponse> {
    ensure_viewer_can_manage_team(&context.authenticated_user)?;

    if request.max_score <= 0.0 {
        bail!("max_score must be greater than zero");
    }
    let (session, materials) = load_session_and_material_rows(&state.pool, session_id).await?;
    let notes = request.notes.trim().to_string();
    let artifact_summary = if notes.is_empty() {
        session.title.clone()
    } else {
        format!("{}: {}", session.title, notes)
    };
    let artifact_payload = json!({
        "session_id": session.session_id,
        "learner_id": session.learner_id,
        "score": request.score,
        "max_score": request.max_score,
        "duration_minutes": request.duration_minutes,
        "notes": notes,
        "recording_mode": "manual",
    });

    persist_session_result(
        state,
        &session,
        &materials,
        SessionResultRecord {
            score: request.score,
            max_score: request.max_score,
            duration_minutes: request.duration_minutes,
            notes,
            artifact_kind: "session_notes",
            artifact_summary,
            artifact_payload,
        },
    )
    .await
}

pub async fn start_session_material_activity(
    state: &Arc<AppState>,
    context: &SessionContext,
    session_id: &str,
    session_material_id: &str,
) -> anyhow::Result<ActivityStartResponse> {
    let (session, materials) = load_session_and_material_rows(&state.pool, session_id).await?;
    ensure_viewer_can_access_learner(&context.active_user, &session.learner_id)?;

    let session_material = materials
        .iter()
        .find(|material| material.session_material_id == session_material_id)
        .ok_or_else(|| anyhow!("session material '{session_material_id}' not found"))?;

    let library = state.library.read().await.clone();
    let material = library
        .material(&session_material.material_id)
        .ok_or_else(|| anyhow!("material '{}' not found in library", session_material.material_id))?;
    let generated =
        runtime::generate_activity(material, runtime::activity_seed()).context("failed to generate activity")?;

    query("update session set status = 'active' where session_id = $1 and status = 'scheduled'")
        .bind(&session.session_id)
        .execute(&state.pool)
        .await?;
    query(
        "update session_material set status = 'active' where session_id = $1 and material_id = $2 and status = 'scheduled'",
    )
    .bind(&session.session_id)
    .bind(&session_material.material_id)
    .execute(&state.pool)
    .await?;

    Ok(ActivityStartResponse {
        status: "ok".to_string(),
        activity: ActivityInstance {
            activity_instance_id: runtime::build_activity_instance_id(
                &session_material.session_material_id,
                generated.seed,
            ),
            session_id: session.session_id,
            session_material_id: session_material.session_material_id.clone(),
            material_id: material.id.clone(),
            material_title: material.title.clone(),
            runtime_id: generated.runtime_id.clone(),
            engine_id: generated.engine_id,
            template_id: generated.template_id,
            instructions: generated.instructions,
            estimated_minutes: material.estimated_minutes,
            scoring: ActivityScoringSummary {
                pass_accuracy: generated.pass_accuracy,
                soft_time_limit_seconds: generated.soft_time_limit_seconds,
            },
            items: generated
                .items
                .into_iter()
                .map(|item| ActivityItem {
                    item_id: item.item_id,
                    content: item.content,
                    response_kind: item.response_kind,
                })
                .collect(),
        },
    })
}

pub async fn complete_activity_instance(
    state: &Arc<AppState>,
    context: &SessionContext,
    activity_instance_id: &str,
    request: CompleteActivityRequest,
) -> anyhow::Result<CompleteActivityResponse> {
    let (session_material_id, seed) = runtime::parse_activity_instance_id(activity_instance_id)?;
    let session_material = load_session_material_row(&state.pool, &session_material_id).await?;
    let session = load_session_row(&state.pool, &session_material.session_id).await?;
    ensure_viewer_can_access_learner(&context.active_user, &session.learner_id)?;

    let library = state.library.read().await.clone();
    let material = library
        .material(&session_material.material_id)
        .ok_or_else(|| anyhow!("material '{}' not found in library", session_material.material_id))?;
    let generated = runtime::generate_activity(material, seed).context("failed to regenerate activity for scoring")?;
    let runtime_responses = request
        .responses
        .iter()
        .map(|response| runtime::ActivityResponseInput {
            item_id: response.item_id.clone(),
            value: response.value.clone(),
        })
        .collect::<Vec<_>>();
    let scored =
        runtime::score_activity(material, &generated, &runtime_responses).context("failed to score activity")?;
    let (_, materials) = load_session_and_material_rows(&state.pool, &session.session_id).await?;

    let notes = build_activity_notes(&material.title, &scored, &request.notes);
    let artifact_summary = format!(
        "{}: {}/{} correct",
        material.title, scored.correct_count, scored.item_count
    );
    let artifact_payload = build_activity_artifact_payload(
        &session,
        &session_material,
        material,
        &generated,
        &scored,
        request.duration_seconds,
    );
    let persisted = persist_session_result(
        state,
        &session,
        &materials,
        SessionResultRecord {
            score: scored.correct_count as f64,
            max_score: scored.item_count as f64,
            duration_minutes: duration_minutes_from_seconds(request.duration_seconds),
            notes,
            artifact_kind: "activity_summary",
            artifact_summary,
            artifact_payload,
        },
    )
    .await?;

    Ok(CompleteActivityResponse {
        status: "ok".to_string(),
        evidence: persisted.evidence,
        updated_progress: persisted.updated_progress,
        activity_summary: ActivitySummary {
            attempted_count: scored.attempted_count,
            correct_count: scored.correct_count,
            item_count: scored.item_count,
            accuracy: scored.accuracy,
            passed: scored.passed,
            completion_reason: scored.completion_reason,
            weak_groups: scored.weak_groups,
        },
    })
}

struct SessionResultRecord<'a> {
    score: f64,
    max_score: f64,
    duration_minutes: i32,
    notes: String,
    artifact_kind: &'a str,
    artifact_summary: String,
    artifact_payload: JsonValue,
}

async fn persist_session_result(
    state: &Arc<AppState>,
    session: &SessionRow,
    materials: &[SessionMaterialRow],
    record: SessionResultRecord<'_>,
) -> anyhow::Result<RecordSessionResponse> {
    let SessionResultRecord {
        score,
        max_score,
        duration_minutes,
        notes,
        artifact_kind,
        artifact_summary,
        artifact_payload,
    } = record;

    if max_score <= 0.0 {
        bail!("max_score must be greater than zero");
    }

    let now = Utc::now();
    let evidence_id = Uuid::new_v4().to_string();
    let ratio = (score / max_score).clamp(0.0, 1.0);
    let progress_status = status_from_ratio(ratio);

    query(
        "insert into evidence (evidence_id, session_id, learner_id, score, max_score, duration_minutes, notes, recorded_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8)",
    )
    .bind(&evidence_id)
    .bind(&session.session_id)
    .bind(&session.learner_id)
    .bind(score)
    .bind(max_score)
    .bind(duration_minutes)
    .bind(&notes)
    .bind(now)
    .execute(&state.pool)
    .await?;

    let evidence_relative_path = format!("evidence/{}/{}.json", session.learner_id, evidence_id);
    let evidence_full_path = state.config.artifacts_root.join(&evidence_relative_path);
    if let Some(parent) = evidence_full_path.parent() {
        fs::create_dir_all(parent).await?;
    }
    fs::write(&evidence_full_path, serde_json::to_vec_pretty(&artifact_payload)?).await?;

    query(
        "insert into evidence_artifact (evidence_artifact_id, evidence_id, learner_id, kind, storage_path, summary)
         values ($1, $2, $3, $4, $5, $6)",
    )
    .bind(Uuid::new_v4().to_string())
    .bind(&evidence_id)
    .bind(&session.learner_id)
    .bind(artifact_kind)
    .bind(&evidence_relative_path)
    .bind(&artifact_summary)
    .execute(&state.pool)
    .await?;

    query("update session set status = $2, notes = $3, completed_at = $4 where session_id = $1")
        .bind(&session.session_id)
        .bind("completed")
        .bind(&notes)
        .bind(now)
        .execute(&state.pool)
        .await?;

    query("update session_material set status = 'completed' where session_id = $1")
        .bind(&session.session_id)
        .execute(&state.pool)
        .await?;

    let skill_ids: BTreeSet<_> = materials.iter().map(|material| material.skill_id.as_str()).collect();
    let mut updated_progress = Vec::new();
    for skill_id in skill_ids {
        let progress_row =
            upsert_skill_progress(&state.pool, &session.learner_id, skill_id, progress_status, ratio, now).await?;
        updated_progress.push(progress_row_to_summary(progress_row));
    }

    rebuild_review_items_for_learner(&state.pool, &session.learner_id).await?;
    refresh_assignment_progress(&state.pool, &session.learner_id).await?;

    Ok(RecordSessionResponse {
        status: "ok".to_string(),
        evidence: EvidenceSummary {
            evidence_id,
            score,
            max_score,
            duration_minutes,
            notes,
            recorded_at: now,
        },
        updated_progress,
    })
}

pub async fn rebuild_review_items(
    state: &Arc<AppState>,
    context: &SessionContext,
    learner_id: Option<String>,
) -> anyhow::Result<ReviewRebuildResponse> {
    ensure_viewer_can_manage_team(&context.authenticated_user)?;

    let learner_ids = if let Some(learner_id) = learner_id {
        vec![learner_id]
    } else {
        query_scalar::<_, String>("select learner_id from learner_profile order by learner_id")
            .fetch_all(&state.pool)
            .await?
    };

    let mut review_item_count = 0usize;
    for learner_id in &learner_ids {
        rebuild_review_items_for_learner(&state.pool, learner_id).await?;
        refresh_assignment_progress(&state.pool, learner_id).await?;
        let count =
            query_scalar::<_, i64>("select count(*) from review_item where learner_id = $1 and status = 'pending'")
                .bind(learner_id)
                .fetch_one(&state.pool)
                .await?;
        review_item_count += count as usize;
    }

    Ok(ReviewRebuildResponse {
        status: "ok".to_string(),
        learner_ids,
        review_item_count,
    })
}

fn library_report_response(report: &LibraryValidationReport) -> LibraryReloadResponse {
    LibraryReloadResponse {
        status: "ok".to_string(),
        subject_count: report.subject_count,
        area_count: report.area_count,
        pathway_count: report.pathway_count,
        skill_count: report.skill_count,
        stage_count: report.stage_count,
        playlist_count: report.playlist_count,
        material_count: report.material_count,
        loaded_at_utc: report.loaded_at_utc.clone(),
    }
}

fn library_document_summary(document: &LibraryDocument) -> LibraryDocumentSummary {
    LibraryDocumentSummary {
        route_path: document.route_path.clone(),
        source_path: document.source_path.clone(),
        kind: document.kind.clone(),
        document_id: document.document_id.clone(),
        title: document.title.clone(),
        subject_id: document.subject_id.clone(),
        area_id: document.area_id.clone(),
        pathway_id: document.pathway_id.clone(),
        description: document.description.clone(),
    }
}

fn library_document_payload(document: &LibraryDocument) -> LibraryDocumentPayload {
    LibraryDocumentPayload {
        route_path: document.route_path.clone(),
        source_path: document.source_path.clone(),
        kind: document.kind.clone(),
        document_id: document.document_id.clone(),
        title: document.title.clone(),
        subject_id: document.subject_id.clone(),
        area_id: document.area_id.clone(),
        pathway_id: document.pathway_id.clone(),
        description: document.description.clone(),
        body: document.body.clone(),
    }
}

fn build_library_workspace_pathways(
    library: &LibraryBundle,
    documents: &[LibraryDocument],
    learners: &[LearnerRow],
    assignments_by_learner: &BTreeMap<String, Vec<AssignmentSummary>>,
) -> Vec<PathwayWorkspaceSummary> {
    let mut pathways = Vec::new();

    for pathway in &library.pathways {
        let mut playlists = Vec::new();
        for playlist_id in &pathway.playlist_ids {
            let Some(playlist) = library.playlist(playlist_id) else {
                continue;
            };

            let mut sessions = Vec::new();
            let mut material_count = 0usize;
            let mut live_material_count = 0usize;

            for (index, session) in playlist.session_pattern.sessions.iter().enumerate() {
                let mut materials = Vec::new();
                let mut session_live_material_count = 0usize;
                let mut estimated_minutes = 0u32;

                for material_id in &session.material_ids {
                    let Some(material) = library.material(material_id) else {
                        continue;
                    };
                    let executable = material.runtime.is_some();
                    if executable {
                        session_live_material_count += 1;
                        live_material_count += 1;
                    }
                    material_count += 1;
                    estimated_minutes += u32::from(material.estimated_minutes);
                    materials.push(MaterialWorkspaceSummary {
                        material_id: material.id.clone(),
                        title: material.title.clone(),
                        kind: material.kind.clone(),
                        audience: material_audience(&material.kind).to_string(),
                        estimated_minutes: material.estimated_minutes,
                        skill_ids: material.skill_ids.clone(),
                        executable,
                        route_path: document_route_path_for_kind(documents, "material", &material.id),
                    });
                }

                let dominant_kind =
                    dominant_kind_for_materials(materials.iter().map(|material| material.kind.as_str()));
                let requires_adult_support = materials.iter().any(|material| material.audience == AUDIENCE_ADULT);
                let materials_by_kind = build_workspace_material_kind_groups(&materials);

                sessions.push(PlaylistSessionWorkspaceSummary {
                    session_index: index + 1,
                    day_offset: session.day_offset,
                    title: session.title.clone(),
                    skill_ids: session.skill_ids.clone(),
                    dominant_kind,
                    requires_adult_support,
                    material_count: materials.len(),
                    estimated_minutes,
                    live_material_count: session_live_material_count,
                    materials_by_kind,
                    materials,
                });
            }

            let delivery_shape = build_playlist_delivery_shape(&sessions);
            let assignment_targets = build_playlist_assignment_targets(playlist, learners, assignments_by_learner);

            playlists.push(PlaylistWorkspaceSummary {
                playlist_id: playlist.playlist_id.clone(),
                title: playlist.title.clone(),
                description: document_description_for_kind(documents, "playlist", &playlist.playlist_id)
                    .unwrap_or_else(|| {
                        format!(
                            "{} sessions across {} days.",
                            playlist.session_pattern.sessions.len(),
                            playlist.duration_days
                        )
                    }),
                recommended_age: playlist.recommended_age,
                recommended_level: playlist.recommended_level.clone(),
                duration_days: playlist.duration_days,
                stage_count: playlist.stage_ids.len(),
                skill_count: playlist.skill_ids.len(),
                material_count,
                live_material_count,
                delivery_shape,
                assignment_targets,
                route_path: document_route_path_for_kind(documents, "playlist", &playlist.playlist_id),
                sessions,
            });
        }

        let mut entry_points = pathway
            .entry_points
            .iter()
            .filter_map(|(key, playlist_id)| {
                key.strip_prefix("age_")
                    .and_then(|value| value.parse::<u8>().ok())
                    .map(|age| PathwayEntryPointSummary {
                        age,
                        playlist_id: playlist_id.clone(),
                        playlist_title: library
                            .playlist(playlist_id)
                            .map(|playlist| playlist.title.clone())
                            .unwrap_or_else(|| playlist_id.clone()),
                    })
            })
            .collect::<Vec<_>>();
        entry_points.sort_by_key(|entry| entry.age);

        pathways.push(PathwayWorkspaceSummary {
            pathway_id: pathway.pathway_id.clone(),
            title: pathway.title.clone(),
            description: pathway.description.clone(),
            area_title: library
                .areas
                .iter()
                .find(|area| area.area_id == pathway.area_id)
                .map(|area| area.title.clone())
                .unwrap_or_else(|| pathway.area_id.clone()),
            recommended_age_min: pathway.recommended_age_min,
            recommended_age_max: pathway.recommended_age_max,
            stage_count: pathway.stage_ids.len(),
            playlist_count: playlists.len(),
            route_path: document_route_path_for_source(documents, &pathway.source_path),
            entry_points,
            playlists,
        });
    }

    pathways
}

fn build_learner_journey(
    library: &LibraryBundle,
    documents: &[LibraryDocument],
    assignment: &AssignmentSummary,
    sessions: &[SessionDetail],
) -> LearnerJourneySummary {
    let playlist = library.playlist(&assignment.playlist_id);
    let pathway = find_pathway_for_playlist(library, &assignment.playlist_id);
    let completed_session_count = sessions.iter().filter(|session| session.status == "completed").count();
    let pending_session_count = sessions.len().saturating_sub(completed_session_count);
    let total_material_count = sessions.iter().map(|session| session.materials.len()).sum();
    let live_material_count = sessions
        .iter()
        .flat_map(|session| session.materials.iter())
        .filter(|material| {
            material
                .runtime
                .as_ref()
                .map(|runtime| runtime.executable)
                .unwrap_or(false)
        })
        .count();
    let next_session_id = sessions
        .iter()
        .find(|session| session.status != "completed")
        .map(|session| session.session_id.clone());

    LearnerJourneySummary {
        pathway_id: pathway.map(|item| item.pathway_id.clone()),
        pathway_title: pathway.map(|item| item.title.clone()),
        pathway_description: pathway.map(|item| item.description.clone()),
        pathway_route_path: pathway.and_then(|item| document_route_path_for_source(documents, &item.source_path)),
        playlist_id: assignment.playlist_id.clone(),
        playlist_title: playlist
            .map(|item| item.title.clone())
            .unwrap_or_else(|| assignment.title.clone()),
        playlist_description: document_description_for_kind(documents, "playlist", &assignment.playlist_id)
            .unwrap_or_else(|| format!("{} sessions are queued in this learning path.", sessions.len())),
        playlist_route_path: document_route_path_for_kind(documents, "playlist", &assignment.playlist_id),
        recommended_age: playlist.map(|item| item.recommended_age).unwrap_or(0),
        recommended_level: playlist.map(|item| item.recommended_level.clone()).unwrap_or_default(),
        duration_days: playlist
            .map(|item| item.duration_days)
            .unwrap_or(assignment.total_sessions),
        total_session_count: sessions.len(),
        completed_session_count,
        pending_session_count,
        total_material_count,
        live_material_count,
        next_session_id,
    }
}

fn find_pathway_for_playlist<'a>(library: &'a LibraryBundle, playlist_id: &str) -> Option<&'a catalog::Pathway> {
    library
        .pathways
        .iter()
        .find(|pathway| pathway.playlist_ids.iter().any(|item| item == playlist_id))
}

fn document_route_path_for_source(documents: &[LibraryDocument], source_path: &str) -> Option<String> {
    documents
        .iter()
        .find(|document| document.source_path == source_path)
        .map(|document| document.route_path.clone())
}

fn document_route_path_for_kind(documents: &[LibraryDocument], kind: &str, document_id: &str) -> Option<String> {
    documents
        .iter()
        .find(|document| document.kind == kind && document.document_id == document_id)
        .map(|document| document.route_path.clone())
}

fn document_description_for_kind(documents: &[LibraryDocument], kind: &str, document_id: &str) -> Option<String> {
    documents
        .iter()
        .find(|document| document.kind == kind && document.document_id == document_id)
        .map(|document| document.description.trim().to_string())
        .filter(|description| !description.is_empty())
}

async fn fetch_team_summary_by_id(state: &Arc<AppState>, team_id: &str) -> anyhow::Result<Option<TeamSummary>> {
    let team = query_as::<_, TeamRow>(
        "select team_id, display_name, description
         from team
         where team_id = $1
         limit 1",
    )
    .bind(team_id)
    .fetch_optional(&state.pool)
    .await?;

    Ok(team.map(|row| TeamSummary {
        team_id: row.team_id,
        display_name: row.display_name,
        description: row.description,
    }))
}

async fn list_owner_team_summaries_for_user(state: &Arc<AppState>, user_id: &str) -> anyhow::Result<Vec<TeamSummary>> {
    let teams = query_as::<_, TeamRow>(
        "select
            t.team_id,
            t.display_name,
            t.description
         from team_membership tm
         join team t on t.team_id = tm.team_id
         where tm.user_id = $1 and tm.role = 'owner'
         order by t.display_name, t.team_id",
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await?;

    Ok(teams
        .into_iter()
        .map(|row| TeamSummary {
            team_id: row.team_id,
            display_name: row.display_name,
            description: row.description,
        })
        .collect())
}

async fn list_team_members_for_team(state: &Arc<AppState>, team_id: &str) -> anyhow::Result<Vec<TeamMemberSummary>> {
    let members = query_as::<_, TeamMemberRow>(
        "select
            ua.user_id,
            ua.username,
            ua.display_name,
            tm.role,
            ua.current_level,
            coalesce(ua.notes, '') as notes,
            lp.learner_id,
            ua.google_subject,
            ua.google_display_name,
            ua.google_picture_url,
            ua.google_email
         from team_membership tm
         join user_account ua on ua.user_id = tm.user_id
         left join learner_profile lp on lp.user_id = ua.user_id and lp.team_id = tm.team_id
         where tm.team_id = $1
         order by case when tm.role = 'owner' then 0 else 1 end, ua.display_name",
    )
    .bind(team_id)
    .fetch_all(&state.pool)
    .await?;

    Ok(members.into_iter().map(member_row_to_summary).collect())
}

fn member_row_to_summary(row: TeamMemberRow) -> TeamMemberSummary {
    let role = row.role.clone();
    let can_manage_team = role_can_manage_team(&role);
    let google_signed_in = row
        .google_subject
        .as_deref()
        .map(str::trim)
        .is_some_and(|value| !value.is_empty());
    TeamMemberSummary {
        user_id: row.user_id,
        username: row.username,
        display_name: row.display_name,
        role,
        current_level: row.current_level,
        notes: row.notes,
        learner_id: row.learner_id,
        google_signed_in,
        google_display_name: row.google_display_name,
        google_picture_url: row.google_picture_url,
        google_email: row.google_email,
        can_manage_team,
        can_read_library: can_manage_team,
        can_view_all_learners: can_manage_team,
        can_open_developer_docs: role_can_open_developer_docs(&row.role),
    }
}

async fn build_dashboard_cards(
    state: &Arc<AppState>,
    library: &LibraryBundle,
    learners: &[LearnerRow],
) -> anyhow::Result<Vec<LearnerDashboard>> {
    let mut dashboards = Vec::new();
    for learner in learners {
        let active_assignment = fetch_active_assignment_for_learner(&state.pool, &learner.learner_id).await?;
        let today_session = if let Some(assignment) = &active_assignment {
            fetch_next_session_for_assignment(&state.pool, &assignment.assignment_id).await?
        } else {
            None
        };
        let review_item_count =
            query_scalar::<_, i64>("select count(*) from review_item where learner_id = $1 and status = 'pending'")
                .bind(&learner.learner_id)
                .fetch_one(&state.pool)
                .await?;
        let progress = fetch_progress(&state.pool, &learner.learner_id).await?;
        let latest_evidence = fetch_latest_evidence_for_learner(&state.pool, &learner.learner_id).await?;
        let (progress_status_counts, stage_progress) =
            summarize_progress(library, active_assignment.as_ref(), &progress);
        let (attention_state, attention_label, next_action_label) =
            dashboard_attention_summary(active_assignment.as_ref(), today_session.as_ref(), review_item_count);

        dashboards.push(LearnerDashboard {
            learner_id: learner.learner_id.clone(),
            display_name: learner.display_name.clone(),
            current_age: calculate_age(learner.date_of_birth),
            current_level: learner.current_level.clone(),
            notes: learner.notes.clone(),
            attention_state,
            attention_label,
            next_action_label,
            active_assignment,
            today_session,
            review_item_count,
            progress_status_counts,
            stage_progress,
            latest_evidence,
        });
    }
    Ok(dashboards)
}

fn summarize_progress(
    library: &LibraryBundle,
    active_assignment: Option<&AssignmentSummary>,
    progress: &[SkillProgressSummary],
) -> (BTreeMap<String, i64>, Vec<StageProgress>) {
    let mut counts: BTreeMap<String, i64> = BTreeMap::new();
    for state in progress {
        *counts.entry(state.status.clone()).or_insert(0) += 1;
    }

    let Some(active_assignment) = active_assignment else {
        return (counts, Vec::new());
    };
    let Some(playlist) = library.playlist(&active_assignment.playlist_id) else {
        return (counts, Vec::new());
    };

    let known_skills: BTreeSet<_> = progress.iter().map(|state| state.skill_id.as_str()).collect();
    let not_started = playlist
        .skill_ids
        .iter()
        .filter(|skill_id| !known_skills.contains(skill_id.as_str()))
        .count() as i64;
    if not_started > 0 {
        counts.insert("not_started".to_string(), not_started);
    }

    let secure_skills: BTreeSet<_> = progress
        .iter()
        .filter(|state| state.status == "secure")
        .map(|state| state.skill_id.as_str())
        .collect();

    let stage_progress = playlist
        .stage_ids
        .iter()
        .filter_map(|stage_id| {
            let stage = library.stages.iter().find(|stage| stage.stage_id == *stage_id)?;
            let completed_skills = stage
                .skill_ids
                .iter()
                .filter(|skill_id| secure_skills.contains(skill_id.as_str()))
                .count();
            Some(StageProgress {
                stage_id: stage.stage_id.clone(),
                title: stage.title.clone(),
                completed_skills,
                total_skills: stage.skill_ids.len(),
            })
        })
        .collect();

    (counts, stage_progress)
}

fn build_learner_workspace(
    library: &LibraryBundle,
    active_assignment: Option<&AssignmentSummary>,
    _journey: Option<&LearnerJourneySummary>,
    sessions: &[SessionDetail],
    progress: &[SkillProgressSummary],
    review_items: &[ReviewItemSummary],
    assigned_journeys: &[crate::domain::LearnerAssignedJourneySummary],
) -> LearnerWorkspaceSummary {
    let workspace_sessions = if assigned_journeys.is_empty() {
        sessions.to_vec()
    } else {
        assigned_journeys
            .iter()
            .flat_map(|journey| journey.sessions.iter().cloned())
            .collect::<Vec<_>>()
    };

    let continue_block =
        continue_block_for_assigned_journeys(assigned_journeys).or_else(|| continue_block_for_sessions(sessions));
    let continue_session = continue_block.as_ref().map(|block| &block.session);

    let mut practice_lane = workspace_sessions
        .iter()
        .filter(|session| {
            session.materials_by_kind.iter().any(|group| {
                (group.kind == WORKSHEET_KIND && session.status != "completed")
                    || (matches!(group.kind.as_str(), DRILL_KIND | QUICK_CHECK_KIND)
                        && (session.status != "completed"
                            || group.materials.iter().any(|material| material.runtime.is_some())))
            })
        })
        .cloned()
        .collect::<Vec<_>>();
    practice_lane.sort_by(|left, right| {
        left.scheduled_date
            .cmp(&right.scheduled_date)
            .then_with(|| left.day_offset.cmp(&right.day_offset))
            .then_with(|| left.title.cmp(&right.title))
    });

    let (progress_counts, _) = summarize_progress(library, active_assignment, progress);
    let (completed_session_count, pending_session_count) = if assigned_journeys.is_empty() {
        let completed = workspace_sessions
            .iter()
            .filter(|session| session.status == "completed")
            .count();
        (completed, workspace_sessions.len().saturating_sub(completed))
    } else {
        (
            assigned_journeys
                .iter()
                .map(|journey| journey.journey.completed_session_count)
                .sum(),
            assigned_journeys
                .iter()
                .map(|journey| journey.journey.pending_session_count)
                .sum(),
        )
    };
    let progress_snapshot = LearnerProgressSnapshot {
        secure_count: progress_counts.get("secure").copied().unwrap_or(0) as usize,
        developing_count: progress_counts.get("developing").copied().unwrap_or(0) as usize,
        not_started_count: progress_counts.get("not_started").copied().unwrap_or(0) as usize,
        review_item_count: review_items.len(),
        completed_session_count,
        pending_session_count,
    };

    let mut recent_wins = workspace_sessions
        .iter()
        .filter_map(|session| {
            session.latest_evidence.as_ref().map(|evidence| {
                let accuracy = if evidence.max_score <= 0.0 {
                    0.0
                } else {
                    (evidence.score / evidence.max_score) * 100.0
                };
                LearnerRecentWinSummary {
                    session_id: session.session_id.clone(),
                    session_title: session.title.clone(),
                    score_label: format!("{:.0}/{:.0} ({:.0}%)", evidence.score, evidence.max_score, accuracy),
                    notes: evidence.notes.clone(),
                    recorded_at: evidence.recorded_at,
                }
            })
        })
        .collect::<Vec<_>>();
    recent_wins.sort_by(|left, right| right.recorded_at.cmp(&left.recorded_at));
    recent_wins.truncate(3);

    let attention_label = if let Some(session) = continue_session {
        if session.requires_adult_support {
            "Adult-guided step ready now".to_string()
        } else if session.live_material_count > 0 {
            "Live practice is ready now".to_string()
        } else {
            "Continue the current journey".to_string()
        }
    } else if !review_items.is_empty() {
        "Review items are waiting".to_string()
    } else if !assigned_journeys.is_empty() || active_assignment.is_some() {
        "Assigned playlists are complete".to_string()
    } else {
        "Choose the first pathway to begin".to_string()
    };

    LearnerWorkspaceSummary {
        attention_label,
        continue_block,
        practice_lane,
        progress_snapshot,
        recent_wins,
    }
}

async fn create_assignment_internal(
    state: &Arc<AppState>,
    library: &LibraryBundle,
    learner_id: &str,
    playlist_id: &str,
    start_date: NaiveDate,
) -> anyhow::Result<AssignmentSummary> {
    let playlist = library
        .playlist(playlist_id)
        .cloned()
        .ok_or_else(|| anyhow!("unknown playlist '{playlist_id}'"))?;

    let end_date = start_date + Duration::days((playlist.duration_days.saturating_sub(1)) as i64);

    let assignment_id = Uuid::new_v4().to_string();
    query(
        "insert into assignment (assignment_id, learner_id, playlist_id, title, start_date, end_date, status, total_sessions, completed_sessions, created_at)
         values ($1, $2, $3, $4, $5, $6, 'active', $7, 0, $8)",
    )
    .bind(&assignment_id)
    .bind(learner_id)
    .bind(&playlist.playlist_id)
    .bind(&playlist.title)
    .bind(start_date)
    .bind(end_date)
    .bind(playlist.session_pattern.sessions.len() as i32)
    .bind(Utc::now())
    .execute(&state.pool)
    .await?;

    for session in &playlist.session_pattern.sessions {
        let scheduled_date = start_date + Duration::days(session.day_offset as i64);
        let session_id = Uuid::new_v4().to_string();
        query(
            "insert into session (session_id, assignment_id, learner_id, title, scheduled_date, status, day_offset, notes, completed_at)
             values ($1, $2, $3, $4, $5, 'scheduled', $6, '', null)",
        )
        .bind(&session_id)
        .bind(&assignment_id)
        .bind(learner_id)
        .bind(&session.title)
        .bind(scheduled_date)
        .bind(session.day_offset)
        .execute(&state.pool)
        .await?;

        let material_skill_pairs = material_skill_pairs_for_session(library, session);
        if material_skill_pairs.is_empty() {
            bail!(
                "playlist '{}' session '{}' has no material-to-skill links",
                playlist_id,
                session.title
            );
        }
        for (material_id, skill_id) in material_skill_pairs {
            query(
                "insert into session_material (session_material_id, session_id, title, skill_id, material_id, status)
                 values ($1, $2, $3, $4, $5, 'scheduled')",
            )
            .bind(Uuid::new_v4().to_string())
            .bind(&session_id)
            .bind(format!("{}: {}", session.title, skill_id))
            .bind(&skill_id)
            .bind(&material_id)
            .execute(&state.pool)
            .await?;
        }
    }

    Ok(AssignmentSummary {
        assignment_id,
        playlist_id: playlist.playlist_id,
        title: playlist.title,
        start_date,
        end_date,
        status: "active".to_string(),
        total_sessions: playlist.session_pattern.sessions.len() as i32,
        completed_sessions: 0,
        completion_percent: 0,
    })
}

fn material_skill_pairs_for_session(library: &LibraryBundle, session: &PlaylistSession) -> Vec<(String, String)> {
    let mut pairs = BTreeSet::new();
    for material_id in &session.material_ids {
        let Some(material) = library.material(material_id) else {
            continue;
        };
        let linked_skills = session
            .skill_ids
            .iter()
            .filter(|skill_id| material.skill_ids.iter().any(|item| item == *skill_id))
            .cloned()
            .collect::<Vec<_>>();
        if linked_skills.is_empty() {
            if let Some(first_skill) = session.skill_ids.first() {
                pairs.insert((material_id.clone(), first_skill.clone()));
            }
            continue;
        }
        for skill_id in linked_skills {
            pairs.insert((material_id.clone(), skill_id));
        }
    }
    pairs.into_iter().collect()
}

async fn build_assigned_journeys(
    pool: &PgPool,
    library: &LibraryBundle,
    documents: &[LibraryDocument],
    learner_id: &str,
    assignments: &[AssignmentSummary],
) -> anyhow::Result<Vec<crate::domain::LearnerAssignedJourneySummary>> {
    let mut journeys = Vec::new();
    for assignment in assignments {
        let sessions = fetch_sessions(pool, library, documents, learner_id, Some(&assignment.assignment_id)).await?;
        let journey = build_learner_journey(library, documents, assignment, &sessions);
        let continue_block = continue_block_for_sessions(&sessions);
        let current_session_id = continue_block
            .as_ref()
            .map(|block| block.session.session_id.clone())
            .or_else(|| {
                sessions
                    .iter()
                    .find(|session| session.status != "completed")
                    .map(|session| session.session_id.clone())
            });
        journeys.push(crate::domain::LearnerAssignedJourneySummary {
            assignment: assignment.clone(),
            journey,
            current_session_id,
            continue_block,
            sessions,
        });
    }
    Ok(journeys)
}

fn build_assigned_pathways(
    library: &LibraryBundle,
    assigned_journeys: &[crate::domain::LearnerAssignedJourneySummary],
) -> Vec<LearnerAssignedPathwaySummary> {
    let mut pathways: Vec<LearnerAssignedPathwaySummary> = Vec::new();

    for assigned_journey in assigned_journeys {
        let journey = &assigned_journey.journey;
        let pathway_id = journey.pathway_id.clone();
        let pathway_title = journey
            .pathway_title
            .clone()
            .unwrap_or_else(|| journey.playlist_title.clone());
        let pathway_description = journey.pathway_description.clone().unwrap_or_default();
        let pathway_route_path = journey.pathway_route_path.clone();

        if let Some(existing) = pathways
            .iter_mut()
            .find(|pathway| pathway.pathway_id == pathway_id && pathway.pathway_title == pathway_title)
        {
            existing.playlist_count += 1;
            existing.total_session_count += journey.total_session_count;
            existing.completed_session_count += journey.completed_session_count;
            existing.pending_session_count += journey.pending_session_count;
            existing.assigned_playlists.push(assigned_journey.clone());
            continue;
        }

        pathways.push(LearnerAssignedPathwaySummary {
            pathway_id,
            pathway_title,
            pathway_description,
            pathway_route_path,
            playlist_count: 1,
            total_session_count: journey.total_session_count,
            completed_session_count: journey.completed_session_count,
            pending_session_count: journey.pending_session_count,
            assigned_playlists: vec![assigned_journey.clone()],
        });
    }

    for pathway in &mut pathways {
        pathway.assigned_playlists.sort_by(|left, right| {
            playlist_pathway_order(library, pathway.pathway_id.as_deref(), &left.journey.playlist_id)
                .cmp(&playlist_pathway_order(
                    library,
                    pathway.pathway_id.as_deref(),
                    &right.journey.playlist_id,
                ))
                .then_with(|| left.assignment.start_date.cmp(&right.assignment.start_date))
                .then_with(|| left.journey.playlist_title.cmp(&right.journey.playlist_title))
                .then_with(|| left.assignment.assignment_id.cmp(&right.assignment.assignment_id))
        });
    }
    pathways.sort_by(|left, right| {
        pathway_library_order(library, left.pathway_id.as_deref())
            .cmp(&pathway_library_order(library, right.pathway_id.as_deref()))
            .then_with(|| left.pathway_title.cmp(&right.pathway_title))
    });

    pathways
}

fn pathway_library_order(library: &LibraryBundle, pathway_id: Option<&str>) -> usize {
    pathway_id
        .and_then(|id| library.pathways.iter().position(|pathway| pathway.pathway_id == id))
        .unwrap_or(usize::MAX)
}

fn playlist_pathway_order(library: &LibraryBundle, pathway_id: Option<&str>, playlist_id: &str) -> usize {
    pathway_id
        .and_then(|id| library.pathways.iter().find(|pathway| pathway.pathway_id == id))
        .and_then(|pathway| {
            pathway
                .playlist_ids
                .iter()
                .position(|candidate| candidate == playlist_id)
        })
        .unwrap_or(usize::MAX)
}

async fn fetch_assignments_for_learner(pool: &PgPool, learner_id: &str) -> anyhow::Result<Vec<AssignmentSummary>> {
    let rows = query_as::<_, AssignmentRow>(
        "select assignment_id, learner_id, playlist_id, title, start_date, end_date, status, total_sessions, completed_sessions
         from assignment
         where learner_id = $1 and status in ('active', 'scheduled', 'completed')
         order by case status when 'active' then 0 when 'scheduled' then 1 else 2 end, start_date asc, title asc",
    )
    .bind(learner_id)
    .fetch_all(pool)
    .await?;
    Ok(rows.into_iter().map(assignment_row_to_summary).collect())
}

async fn fetch_active_assignment_for_learner(
    pool: &PgPool,
    learner_id: &str,
) -> anyhow::Result<Option<AssignmentSummary>> {
    Ok(fetch_assignments_for_learner(pool, learner_id)
        .await?
        .into_iter()
        .next())
}

async fn fetch_assignments_for_learners_map(
    pool: &PgPool,
    learners: &[LearnerRow],
) -> anyhow::Result<BTreeMap<String, Vec<AssignmentSummary>>> {
    if learners.is_empty() {
        return Ok(BTreeMap::new());
    }

    let learner_ids = learners
        .iter()
        .map(|learner| learner.learner_id.clone())
        .collect::<Vec<_>>();
    let rows = query_as::<_, AssignmentRow>(
        "select assignment_id, learner_id, playlist_id, title, start_date, end_date, status, total_sessions, completed_sessions
         from assignment
         where learner_id = any($1) and status in ('active', 'scheduled', 'completed')
         order by learner_id, case status when 'active' then 0 when 'scheduled' then 1 else 2 end, start_date asc, title asc",
    )
    .bind(&learner_ids)
    .fetch_all(pool)
    .await?;

    let mut assignments = BTreeMap::new();
    for row in rows {
        let learner_id = row.learner_id.clone();
        assignments
            .entry(learner_id)
            .or_insert_with(Vec::new)
            .push(assignment_row_to_summary(row));
    }
    Ok(assignments)
}

async fn fetch_next_session_for_assignment(
    pool: &PgPool,
    assignment_id: &str,
) -> anyhow::Result<Option<SessionSummary>> {
    let row = query_as::<_, SessionRow>(
        "select session_id, assignment_id, learner_id, title, scheduled_date, status, day_offset, notes, completed_at
         from session
         where assignment_id = $1 and status <> 'completed'
         order by scheduled_date asc, day_offset asc
         limit 1",
    )
    .bind(assignment_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(session_row_to_summary))
}

async fn fetch_sessions(
    pool: &PgPool,
    library: &LibraryBundle,
    documents: &[LibraryDocument],
    learner_id: &str,
    assignment_id: Option<&str>,
) -> anyhow::Result<Vec<SessionDetail>> {
    let ordered_sessions = assignment_id.is_some();
    let rows = if let Some(assignment_id) = assignment_id {
        query_as::<_, SessionRow>(
            "select session_id, assignment_id, learner_id, title, scheduled_date, status, day_offset, notes, completed_at
             from session
             where learner_id = $1 and assignment_id = $2
             order by scheduled_date asc, day_offset asc",
        )
        .bind(learner_id)
        .bind(assignment_id)
        .fetch_all(pool)
        .await?
    } else {
        query_as::<_, SessionRow>(
            "select session_id, assignment_id, learner_id, title, scheduled_date, status, day_offset, notes, completed_at
             from session
             where learner_id = $1
             order by scheduled_date desc, day_offset desc
             limit 10",
        )
        .bind(learner_id)
        .fetch_all(pool)
        .await?
    };

    let mut sessions = Vec::new();
    for (index, row) in rows.into_iter().enumerate() {
        let mut material_rows = query_as::<_, SessionMaterialRow>(
            "select session_material_id, session_id, title, skill_id, material_id, status
             from session_material
             where session_id = $1
             order by title, skill_id",
        )
        .bind(&row.session_id)
        .fetch_all(pool)
        .await?;
        material_rows = ensure_session_material_rows(pool, library, &row, material_rows).await?;
        order_session_material_rows(pool, library, &row, &mut material_rows).await?;
        let latest_evidence = fetch_latest_evidence_for_session(pool, &row.session_id).await?;
        let materials = build_session_material_summaries(library, documents, material_rows);
        let dominant_kind = dominant_kind_for_materials(materials.iter().map(|material| material.kind.as_str()));
        let requires_adult_support = materials.iter().any(|material| material.audience == AUDIENCE_ADULT);
        let materials_by_kind = build_session_material_kind_groups(&materials);
        let estimated_minutes = session_estimated_minutes(&materials);
        let live_material_count = session_live_material_count(&materials);
        let learner_material_count = session_material_count_for_audience(&materials, AUDIENCE_LEARNER);
        let adult_material_count = session_material_count_for_audience(&materials, AUDIENCE_ADULT);
        sessions.push(SessionDetail {
            session_id: row.session_id,
            title: row.title,
            scheduled_date: row.scheduled_date,
            status: row.status,
            day_offset: row.day_offset,
            sequence_number: ordered_sessions.then_some(index + 1),
            dominant_kind,
            requires_adult_support,
            estimated_minutes,
            live_material_count,
            learner_material_count,
            adult_material_count,
            notes: row.notes,
            materials_by_kind,
            materials,
            latest_evidence,
        });
    }
    Ok(sessions)
}

async fn order_session_material_rows(
    pool: &PgPool,
    library: &LibraryBundle,
    session_row: &SessionRow,
    rows: &mut [SessionMaterialRow],
) -> anyhow::Result<()> {
    let material_order = authored_material_order_for_session(pool, library, session_row).await?;
    rows.sort_by(|left, right| {
        material_order
            .get(&left.material_id)
            .copied()
            .unwrap_or(usize::MAX)
            .cmp(&material_order.get(&right.material_id).copied().unwrap_or(usize::MAX))
            .then_with(|| left.material_id.cmp(&right.material_id))
            .then_with(|| left.skill_id.cmp(&right.skill_id))
            .then_with(|| left.session_material_id.cmp(&right.session_material_id))
    });
    Ok(())
}

async fn authored_material_order_for_session(
    pool: &PgPool,
    library: &LibraryBundle,
    session_row: &SessionRow,
) -> anyhow::Result<BTreeMap<String, usize>> {
    if session_row.assignment_id.is_empty() {
        return Ok(BTreeMap::new());
    }

    let playlist_id = query_scalar::<_, String>("select playlist_id from assignment where assignment_id = $1")
        .bind(&session_row.assignment_id)
        .fetch_optional(pool)
        .await?;
    let Some(playlist_id) = playlist_id else {
        return Ok(BTreeMap::new());
    };
    let Some(playlist) = library.playlist(&playlist_id) else {
        return Ok(BTreeMap::new());
    };

    let authored_session = playlist
        .session_pattern
        .sessions
        .iter()
        .find(|session| session.day_offset == session_row.day_offset && session.title == session_row.title)
        .or_else(|| {
            playlist
                .session_pattern
                .sessions
                .iter()
                .find(|session| session.day_offset == session_row.day_offset)
        });
    let Some(authored_session) = authored_session else {
        return Ok(BTreeMap::new());
    };

    Ok(authored_session
        .material_ids
        .iter()
        .enumerate()
        .map(|(index, material_id)| (material_id.clone(), index))
        .collect())
}

async fn ensure_session_material_rows(
    pool: &PgPool,
    library: &LibraryBundle,
    session_row: &SessionRow,
    existing_rows: Vec<SessionMaterialRow>,
) -> anyhow::Result<Vec<SessionMaterialRow>> {
    if session_row.status == "completed" || session_row.assignment_id.is_empty() {
        return Ok(existing_rows);
    }

    let playlist_id = query_scalar::<_, String>("select playlist_id from assignment where assignment_id = $1")
        .bind(&session_row.assignment_id)
        .fetch_optional(pool)
        .await?;
    let Some(playlist_id) = playlist_id else {
        return Ok(existing_rows);
    };
    let Some(playlist) = library.playlist(&playlist_id) else {
        return Ok(existing_rows);
    };

    let authored_session = playlist
        .session_pattern
        .sessions
        .iter()
        .find(|session| session.day_offset == session_row.day_offset && session.title == session_row.title)
        .or_else(|| {
            playlist
                .session_pattern
                .sessions
                .iter()
                .find(|session| session.day_offset == session_row.day_offset)
        });
    let Some(authored_session) = authored_session else {
        return Ok(existing_rows);
    };

    let expected_pairs = material_skill_pairs_for_session(library, authored_session)
        .into_iter()
        .collect::<BTreeSet<_>>();
    if expected_pairs.is_empty() {
        return Ok(existing_rows);
    }
    let existing_pairs = existing_rows
        .iter()
        .map(|row| (row.material_id.clone(), row.skill_id.clone()))
        .collect::<BTreeSet<_>>();
    let missing_pairs = expected_pairs.difference(&existing_pairs).cloned().collect::<Vec<_>>();
    if missing_pairs.is_empty() {
        return Ok(existing_rows);
    }

    let material_status = if session_row.status == "active" {
        "active"
    } else {
        "scheduled"
    };
    for (material_id, skill_id) in missing_pairs {
        query(
            "insert into session_material (session_material_id, session_id, title, skill_id, material_id, status)
             values ($1, $2, $3, $4, $5, $6)",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(&session_row.session_id)
        .bind(format!("{}: {}", session_row.title, skill_id))
        .bind(skill_id)
        .bind(material_id)
        .bind(material_status)
        .execute(pool)
        .await?;
    }

    query_as::<_, SessionMaterialRow>(
        "select session_material_id, session_id, title, skill_id, material_id, status
         from session_material
         where session_id = $1
         order by title, skill_id",
    )
    .bind(&session_row.session_id)
    .fetch_all(pool)
    .await
    .map_err(Into::into)
}

fn build_session_material_summaries(
    library: &LibraryBundle,
    documents: &[LibraryDocument],
    rows: Vec<SessionMaterialRow>,
) -> Vec<SessionMaterialSummary> {
    let mut grouped: BTreeMap<String, Vec<SessionMaterialRow>> = BTreeMap::new();
    let mut material_order = Vec::new();
    for row in rows {
        if !grouped.contains_key(&row.material_id) {
            material_order.push(row.material_id.clone());
        }
        grouped.entry(row.material_id.clone()).or_default().push(row);
    }

    let mut summaries = Vec::new();
    for material_id in material_order {
        let Some(group) = grouped.remove(&material_id) else {
            continue;
        };
        let first = &group[0];
        let material = library.material(&material_id);
        let skill_ids = group
            .iter()
            .map(|row| row.skill_id.clone())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
        let status = if group.iter().all(|row| row.status == "completed") {
            "completed".to_string()
        } else if group.iter().any(|row| row.status == "active") {
            "active".to_string()
        } else {
            first.status.clone()
        };
        summaries.push(SessionMaterialSummary {
            session_material_id: first.session_material_id.clone(),
            title: material
                .map(|item| item.title.clone())
                .unwrap_or_else(|| first.title.clone()),
            material_id: material_id.clone(),
            kind: material
                .map(|item| item.kind.clone())
                .unwrap_or_else(|| "material".to_string()),
            audience: material
                .map(|item| material_audience(&item.kind).to_string())
                .unwrap_or_else(|| AUDIENCE_LEARNER.to_string()),
            estimated_minutes: material.map(|item| item.estimated_minutes).unwrap_or(0),
            skill_ids,
            status,
            document_route_path: document_route_path_for_kind(documents, "material", &material_id),
            document_body: material.map(|item| item.body.clone()),
            runtime: material.and_then(|item| {
                item.runtime.as_ref().map(|runtime| SessionMaterialRuntimeSummary {
                    runtime_id: runtime::build_runtime_id(&runtime.engine_id, &runtime.template_id),
                    engine_id: runtime.engine_id.clone(),
                    template_id: runtime.template_id.clone(),
                    executable: true,
                })
            }),
        });
    }

    summaries
}

async fn load_session_row(pool: &PgPool, session_id: &str) -> anyhow::Result<SessionRow> {
    query_as::<_, SessionRow>(
        "select session_id, assignment_id, learner_id, title, scheduled_date, status, day_offset, notes, completed_at
         from session
         where session_id = $1",
    )
    .bind(session_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| anyhow!("session '{session_id}' not found"))
}

async fn load_session_material_row(pool: &PgPool, session_material_id: &str) -> anyhow::Result<SessionMaterialRow> {
    query_as::<_, SessionMaterialRow>(
        "select session_material_id, session_id, title, skill_id, material_id, status
         from session_material
         where session_material_id = $1",
    )
    .bind(session_material_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| anyhow!("session material '{session_material_id}' not found"))
}

async fn load_session_and_material_rows(
    pool: &PgPool,
    session_id: &str,
) -> anyhow::Result<(SessionRow, Vec<SessionMaterialRow>)> {
    let session = load_session_row(pool, session_id).await?;
    let materials = query_as::<_, SessionMaterialRow>(
        "select session_material_id, session_id, title, skill_id, material_id, status
         from session_material
         where session_id = $1
         order by title, skill_id",
    )
    .bind(session_id)
    .fetch_all(pool)
    .await?;
    Ok((session, materials))
}

fn build_activity_notes(material_title: &str, scored: &ScoredActivity, notes: &str) -> String {
    let automatic = if scored.weak_groups.is_empty() {
        format!(
            "{}: {}/{} correct ({:.0}% accuracy)",
            material_title,
            scored.correct_count,
            scored.item_count,
            scored.accuracy * 100.0,
        )
    } else {
        format!(
            "{}: {}/{} correct ({:.0}% accuracy). Weak groups: {}",
            material_title,
            scored.correct_count,
            scored.item_count,
            scored.accuracy * 100.0,
            scored.weak_groups.join(", "),
        )
    };
    let trimmed = notes.trim();
    if trimmed.is_empty() {
        automatic
    } else {
        format!("{} | {}", trimmed, automatic)
    }
}

fn build_activity_artifact_payload(
    session: &SessionRow,
    session_material: &SessionMaterialRow,
    material: &catalog::MaterialDocument,
    generated: &GeneratedActivity,
    scored: &ScoredActivity,
    duration_seconds: i32,
) -> JsonValue {
    let mut payload = json!({
        "session_id": session.session_id,
        "learner_id": session.learner_id,
        "session_material_id": session_material.session_material_id,
        "material_id": material.id,
        "material_title": material.title,
        "runtime_id": generated.runtime_id,
        "engine_id": generated.engine_id,
        "template_id": generated.template_id,
        "attempted_count": scored.attempted_count,
        "correct_count": scored.correct_count,
        "item_count": scored.item_count,
        "accuracy": scored.accuracy,
        "passed": scored.passed,
        "completion_reason": scored.completion_reason,
        "weak_groups": scored.weak_groups,
        "duration_seconds": duration_seconds.max(0),
        "recording_mode": "activity",
    });
    if generated.store_response_log {
        payload["response_log"] = JsonValue::Array(scored.response_log.clone());
    }
    payload
}

fn duration_minutes_from_seconds(duration_seconds: i32) -> i32 {
    if duration_seconds <= 0 {
        return 0;
    }
    (duration_seconds + 59) / 60
}

async fn fetch_progress(pool: &PgPool, learner_id: &str) -> anyhow::Result<Vec<SkillProgressSummary>> {
    let rows = query_as::<_, SkillProgressRow>(
        "select learner_id, skill_id, status, score_average, last_score, total_evidence, last_evidence_at
         from learner_skill_progress
         where learner_id = $1
         order by skill_id",
    )
    .bind(learner_id)
    .fetch_all(pool)
    .await?;
    Ok(rows.into_iter().map(progress_row_to_summary).collect())
}

async fn fetch_review_items(pool: &PgPool, learner_id: &str) -> anyhow::Result<Vec<ReviewItemSummary>> {
    let rows = query_as::<_, ReviewItemRow>(
        "select review_item_id, learner_id, skill_id, reason, due_date, status
         from review_item
         where learner_id = $1
         order by due_date asc, skill_id asc",
    )
    .bind(learner_id)
    .fetch_all(pool)
    .await?;
    Ok(rows
        .into_iter()
        .map(|row| ReviewItemSummary {
            review_item_id: row.review_item_id,
            skill_id: row.skill_id,
            reason: row.reason,
            due_date: row.due_date,
            status: row.status,
        })
        .collect())
}

async fn fetch_latest_evidence_for_learner(pool: &PgPool, learner_id: &str) -> anyhow::Result<Option<EvidenceSummary>> {
    let row = query_as::<_, EvidenceRow>(
        "select evidence_id, session_id, learner_id, score, max_score, duration_minutes, notes, recorded_at
         from evidence
         where learner_id = $1
         order by recorded_at desc
         limit 1",
    )
    .bind(learner_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(evidence_row_to_summary))
}

async fn fetch_latest_evidence_for_session(pool: &PgPool, session_id: &str) -> anyhow::Result<Option<EvidenceSummary>> {
    let row = query_as::<_, EvidenceRow>(
        "select evidence_id, session_id, learner_id, score, max_score, duration_minutes, notes, recorded_at
         from evidence
         where session_id = $1
         order by recorded_at desc
         limit 1",
    )
    .bind(session_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(evidence_row_to_summary))
}

async fn upsert_skill_progress(
    pool: &PgPool,
    learner_id: &str,
    skill_id: &str,
    status: &str,
    ratio: f64,
    recorded_at: chrono::DateTime<Utc>,
) -> anyhow::Result<SkillProgressRow> {
    query_as::<_, SkillProgressRow>(
        "insert into learner_skill_progress
            (learner_id, skill_id, status, score_average, last_score, total_evidence, last_evidence_at)
         values ($1, $2, $3, $4, $4, 1, $5)
         on conflict (learner_id, skill_id) do update
         set status = excluded.status,
             score_average = ((learner_skill_progress.score_average * learner_skill_progress.total_evidence) + excluded.last_score)
                / (learner_skill_progress.total_evidence + 1),
             last_score = excluded.last_score,
             total_evidence = learner_skill_progress.total_evidence + 1,
             last_evidence_at = excluded.last_evidence_at
         returning learner_id, skill_id, status, score_average, last_score, total_evidence, last_evidence_at",
    )
    .bind(learner_id)
    .bind(skill_id)
    .bind(status)
    .bind(ratio)
    .bind(recorded_at)
    .fetch_one(pool)
    .await
    .context("failed to update skill progress")
}

async fn rebuild_review_items_for_learner(pool: &PgPool, learner_id: &str) -> anyhow::Result<()> {
    query("delete from review_item where learner_id = $1")
        .bind(learner_id)
        .execute(pool)
        .await?;

    let states = query_as::<_, SkillProgressRow>(
        "select learner_id, skill_id, status, score_average, last_score, total_evidence, last_evidence_at
         from learner_skill_progress
         where learner_id = $1",
    )
    .bind(learner_id)
    .fetch_all(pool)
    .await?;
    let today = Utc::now().date_naive();

    for state in states {
        let Some(reason) = review_reason(&state.status) else {
            continue;
        };
        let due_date = match state.status.as_str() {
            "needs_review" => today + Duration::days(1),
            "introduced" => today + Duration::days(3),
            "practising" => today + Duration::days(2),
            _ => continue,
        };
        query(
            "insert into review_item (review_item_id, learner_id, skill_id, reason, due_date, status, created_at)
             values ($1, $2, $3, $4, $5, 'pending', $6)",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(learner_id)
        .bind(&state.skill_id)
        .bind(reason)
        .bind(due_date)
        .bind(Utc::now())
        .execute(pool)
        .await?;
    }
    Ok(())
}

async fn refresh_assignment_progress(pool: &PgPool, learner_id: &str) -> anyhow::Result<()> {
    let assignments = query_as::<_, AssignmentRow>(
        "select assignment_id, learner_id, playlist_id, title, start_date, end_date, status, total_sessions, completed_sessions
         from assignment
         where learner_id = $1",
    )
    .bind(learner_id)
    .fetch_all(pool)
    .await?;
    for assignment in assignments {
        let completed_sessions =
            query_scalar::<_, i64>("select count(*) from session where assignment_id = $1 and status = 'completed'")
                .bind(&assignment.assignment_id)
                .fetch_one(pool)
                .await? as i32;
        let next_status = if assignment.status == "replaced" {
            "replaced"
        } else if assignment.total_sessions > 0 && completed_sessions >= assignment.total_sessions {
            "completed"
        } else {
            "active"
        };

        query("update assignment set completed_sessions = $2, status = $3 where assignment_id = $1")
            .bind(&assignment.assignment_id)
            .bind(completed_sessions)
            .bind(next_status)
            .execute(pool)
            .await?;
    }
    Ok(())
}

fn review_reason(status: &str) -> Option<&'static str> {
    match status {
        "introduced" => Some("New skill needs a short revisit"),
        "practising" => Some("Keep this skill in the active review loop"),
        "needs_review" => Some("Recent performance was weak and should be repeated soon"),
        _ => None,
    }
}

fn calculate_age(date_of_birth: NaiveDate) -> i32 {
    let today = Utc::now().date_naive();
    let mut age = today.year() - date_of_birth.year();
    if (today.month(), today.day()) < (date_of_birth.month(), date_of_birth.day()) {
        age -= 1;
    }
    age
}

fn status_from_ratio(ratio: f64) -> &'static str {
    if ratio >= 0.9 {
        "secure"
    } else if ratio >= 0.75 {
        "practising"
    } else if ratio >= 0.5 {
        "introduced"
    } else {
        "needs_review"
    }
}

fn assignment_row_to_summary(row: AssignmentRow) -> AssignmentSummary {
    let completion_percent = if row.total_sessions > 0 {
        (row.completed_sessions * 100) / row.total_sessions
    } else {
        0
    };
    AssignmentSummary {
        assignment_id: row.assignment_id,
        playlist_id: row.playlist_id,
        title: row.title,
        start_date: row.start_date,
        end_date: row.end_date,
        status: row.status,
        total_sessions: row.total_sessions,
        completed_sessions: row.completed_sessions,
        completion_percent,
    }
}

fn session_row_to_summary(row: SessionRow) -> SessionSummary {
    SessionSummary {
        session_id: row.session_id,
        title: row.title,
        scheduled_date: row.scheduled_date,
        status: row.status,
        day_offset: row.day_offset,
        sequence_number: None,
    }
}

fn evidence_row_to_summary(row: EvidenceRow) -> EvidenceSummary {
    EvidenceSummary {
        evidence_id: row.evidence_id,
        score: row.score,
        max_score: row.max_score,
        duration_minutes: row.duration_minutes,
        notes: row.notes,
        recorded_at: row.recorded_at,
    }
}

fn progress_row_to_summary(row: SkillProgressRow) -> SkillProgressSummary {
    SkillProgressSummary {
        skill_id: row.skill_id,
        status: row.status,
        score_average: row.score_average,
        last_score: row.last_score,
        total_evidence: row.total_evidence,
        last_evidence_at: row.last_evidence_at,
    }
}

fn learner_safe_workspace_summary(workspace: &LearnerWorkspaceSummary) -> LearnerWorkspaceSummary {
    LearnerWorkspaceSummary {
        attention_label: workspace.attention_label.clone(),
        continue_block: workspace.continue_block.as_ref().map(learner_safe_continue_block),
        practice_lane: workspace
            .practice_lane
            .iter()
            .map(learner_safe_session_detail)
            .collect(),
        progress_snapshot: workspace.progress_snapshot.clone(),
        recent_wins: workspace.recent_wins.clone(),
    }
}

fn learner_safe_continue_block(block: &LearnerContinueBlock) -> LearnerContinueBlock {
    LearnerContinueBlock {
        title: block.title.clone(),
        description: block.description.clone(),
        action_label: block.action_label.clone(),
        session: learner_safe_session_detail(&block.session),
    }
}

fn learner_safe_assigned_journey(
    assigned_journey: &crate::domain::LearnerAssignedJourneySummary,
) -> crate::domain::LearnerAssignedJourneySummary {
    crate::domain::LearnerAssignedJourneySummary {
        assignment: assigned_journey.assignment.clone(),
        journey: assigned_journey.journey.clone(),
        current_session_id: assigned_journey.current_session_id.clone(),
        continue_block: assigned_journey
            .continue_block
            .as_ref()
            .map(learner_safe_continue_block),
        sessions: assigned_journey
            .sessions
            .iter()
            .map(learner_safe_session_detail)
            .collect(),
    }
}

fn learner_safe_assigned_pathway(
    assigned_pathway: &crate::domain::LearnerAssignedPathwaySummary,
) -> crate::domain::LearnerAssignedPathwaySummary {
    crate::domain::LearnerAssignedPathwaySummary {
        pathway_id: assigned_pathway.pathway_id.clone(),
        pathway_title: assigned_pathway.pathway_title.clone(),
        pathway_description: assigned_pathway.pathway_description.clone(),
        pathway_route_path: assigned_pathway.pathway_route_path.clone(),
        playlist_count: assigned_pathway.playlist_count,
        total_session_count: assigned_pathway.total_session_count,
        completed_session_count: assigned_pathway.completed_session_count,
        pending_session_count: assigned_pathway.pending_session_count,
        assigned_playlists: assigned_pathway
            .assigned_playlists
            .iter()
            .map(learner_safe_assigned_journey)
            .collect(),
    }
}

fn learner_safe_session_detail(session: &SessionDetail) -> SessionDetail {
    let materials = session
        .materials
        .iter()
        .filter(|material| material.audience == AUDIENCE_LEARNER)
        .cloned()
        .collect::<Vec<_>>();
    let materials_by_kind = session
        .materials_by_kind
        .iter()
        .filter(|group| group.audience == AUDIENCE_LEARNER)
        .map(|group| SessionMaterialKindGroupSummary {
            kind: group.kind.clone(),
            audience: group.audience.clone(),
            material_count: group
                .materials
                .iter()
                .filter(|material| material.audience == AUDIENCE_LEARNER)
                .count(),
            materials: group
                .materials
                .iter()
                .filter(|material| material.audience == AUDIENCE_LEARNER)
                .cloned()
                .collect(),
        })
        .filter(|group| group.material_count > 0)
        .collect::<Vec<_>>();

    SessionDetail {
        live_material_count: materials
            .iter()
            .filter(|material| {
                material
                    .runtime
                    .as_ref()
                    .map(|runtime| runtime.executable)
                    .unwrap_or(false)
            })
            .count(),
        learner_material_count: materials.len(),
        adult_material_count: 0,
        materials,
        materials_by_kind,
        ..session.clone()
    }
}

fn continue_block_for_sessions(sessions: &[SessionDetail]) -> Option<LearnerContinueBlock> {
    sessions
        .iter()
        .find(|session| session.status != "completed")
        .cloned()
        .map(|session| LearnerContinueBlock {
            title: continue_block_title(&session),
            description: continue_block_description(&session),
            action_label: session_action_label(&session),
            session,
        })
}

fn continue_block_for_assigned_journeys(
    assigned_journeys: &[crate::domain::LearnerAssignedJourneySummary],
) -> Option<LearnerContinueBlock> {
    assigned_journeys
        .iter()
        .filter_map(|journey| journey.continue_block.clone())
        .min_by(|left, right| session_workspace_order(&left.session, &right.session))
}

fn response_sessions_for_assigned_journeys(
    assigned_journeys: &[crate::domain::LearnerAssignedJourneySummary],
    fallback_sessions: &[SessionDetail],
) -> Vec<SessionDetail> {
    if assigned_journeys.is_empty() {
        return fallback_sessions.to_vec();
    }

    let mut sessions = assigned_journeys
        .iter()
        .flat_map(|journey| journey.sessions.iter().cloned())
        .collect::<Vec<_>>();
    sessions.sort_by(session_workspace_order);
    sessions
}

fn session_workspace_order(left: &SessionDetail, right: &SessionDetail) -> Ordering {
    left.scheduled_date
        .cmp(&right.scheduled_date)
        .then_with(|| left.day_offset.cmp(&right.day_offset))
        .then_with(|| left.title.cmp(&right.title))
        .then_with(|| left.session_id.cmp(&right.session_id))
}

#[cfg(test)]
mod tests {
    use catalog::{BootstrapMembership, BootstrapTeam, BootstrapUser, IdentityBootstrap, LibraryBundle, Pathway};
    use chrono::NaiveDate;

    use crate::domain::{
        AssignmentSummary, EvidenceSummary, LearnerAssignedJourneySummary, LearnerContinueBlock, LearnerJourneySummary,
        LearnerProgressSnapshot, LearnerRecentWinSummary, LearnerWorkspaceSummary, SessionDetail,
        SessionMaterialKindGroupSummary, SessionMaterialRuntimeSummary, SessionMaterialSummary,
    };

    use super::{
        build_assigned_pathways, compile_bootstrap, continue_block_for_assigned_journeys,
        learner_safe_workspace_summary, response_sessions_for_assigned_journeys,
    };

    fn sample_session() -> SessionDetail {
        sample_session_on(2026, 1, 1, "session-1", "Session 1")
    }

    fn sample_session_on(year: i32, month: u32, day: u32, session_id: &str, title: &str) -> SessionDetail {
        let learner_material = SessionMaterialSummary {
            session_material_id: "sm-1".to_string(),
            title: "Learner note".to_string(),
            material_id: "m-1".to_string(),
            kind: "lesson_note".to_string(),
            audience: "learner".to_string(),
            estimated_minutes: 10,
            skill_ids: vec!["skill-1".to_string()],
            status: "scheduled".to_string(),
            document_route_path: Some("library/documents/learner".to_string()),
            document_body: Some("Learner body".to_string()),
            runtime: None,
        };
        let teaching_material = SessionMaterialSummary {
            session_material_id: "sm-2".to_string(),
            title: "Adult note".to_string(),
            material_id: "m-2".to_string(),
            kind: "teaching_note".to_string(),
            audience: "adult".to_string(),
            estimated_minutes: 5,
            skill_ids: vec!["skill-1".to_string()],
            status: "scheduled".to_string(),
            document_route_path: Some("library/documents/adult".to_string()),
            document_body: Some("Adult body".to_string()),
            runtime: Some(SessionMaterialRuntimeSummary {
                runtime_id: "runtime-1".to_string(),
                engine_id: "engine-1".to_string(),
                template_id: "template-1".to_string(),
                executable: true,
            }),
        };
        SessionDetail {
            session_id: session_id.to_string(),
            title: title.to_string(),
            scheduled_date: NaiveDate::from_ymd_opt(year, month, day).expect("valid date"),
            status: "scheduled".to_string(),
            day_offset: 0,
            sequence_number: Some(1),
            dominant_kind: "lesson_note".to_string(),
            requires_adult_support: true,
            estimated_minutes: 15,
            live_material_count: 1,
            learner_material_count: 1,
            adult_material_count: 1,
            notes: String::new(),
            materials_by_kind: vec![
                SessionMaterialKindGroupSummary {
                    kind: "lesson_note".to_string(),
                    audience: "learner".to_string(),
                    material_count: 1,
                    materials: vec![learner_material.clone()],
                },
                SessionMaterialKindGroupSummary {
                    kind: "teaching_note".to_string(),
                    audience: "adult".to_string(),
                    material_count: 1,
                    materials: vec![teaching_material.clone()],
                },
            ],
            materials: vec![learner_material, teaching_material],
            latest_evidence: Some(EvidenceSummary {
                evidence_id: "evidence-1".to_string(),
                score: 8.0,
                max_score: 10.0,
                duration_minutes: 12,
                notes: "Great work".to_string(),
                recorded_at: chrono::Utc::now(),
            }),
        }
    }

    #[test]
    fn learner_workspace_sanitizes_adult_materials() {
        let workspace = LearnerWorkspaceSummary {
            attention_label: "Adult-guided step ready now".to_string(),
            continue_block: Some(LearnerContinueBlock {
                title: "Continue".to_string(),
                description: "desc".to_string(),
                action_label: "Open practice".to_string(),
                session: sample_session(),
            }),
            practice_lane: vec![sample_session()],
            progress_snapshot: LearnerProgressSnapshot {
                secure_count: 1,
                developing_count: 2,
                not_started_count: 3,
                review_item_count: 4,
                completed_session_count: 0,
                pending_session_count: 1,
            },
            recent_wins: vec![LearnerRecentWinSummary {
                session_id: "session-1".to_string(),
                session_title: "Session 1".to_string(),
                score_label: "8/10 (80%)".to_string(),
                notes: "Great work".to_string(),
                recorded_at: chrono::Utc::now(),
            }],
        };

        let safe = learner_safe_workspace_summary(&workspace);
        let session = safe.continue_block.expect("continue block").session;

        assert!(session.materials.iter().all(|material| material.audience == "learner"));
        assert!(
            session
                .materials_by_kind
                .iter()
                .all(|group| group.audience == "learner")
        );
        assert_eq!(session.adult_material_count, 0);
        assert_eq!(safe.practice_lane[0].materials.len(), 1);
        assert!(
            safe.practice_lane[0]
                .materials
                .iter()
                .all(|material| material.audience == "learner")
        );
        assert_eq!(safe.recent_wins.len(), 1);
    }

    #[test]
    fn assigned_journey_continue_block_uses_earliest_session_across_playlists() {
        let later_session = sample_session_on(2026, 1, 3, "session-later", "Later");
        let earlier_session = sample_session_on(2026, 1, 2, "session-earlier", "Earlier");
        let journeys = vec![
            sample_assigned_journey("assignment-later", later_session),
            sample_assigned_journey("assignment-earlier", earlier_session.clone()),
        ];

        let continue_block = continue_block_for_assigned_journeys(&journeys).expect("continue block should exist");

        assert_eq!(continue_block.session.session_id, earlier_session.session_id);
    }

    #[test]
    fn response_sessions_flattens_all_assigned_sessions_in_schedule_order() {
        let later_session = sample_session_on(2026, 1, 4, "session-later", "Later");
        let earlier_session = sample_session_on(2026, 1, 2, "session-earlier", "Earlier");
        let sessions = response_sessions_for_assigned_journeys(
            &[
                sample_assigned_journey("assignment-later", later_session),
                sample_assigned_journey("assignment-earlier", earlier_session),
            ],
            &[],
        );

        assert_eq!(sessions.len(), 2);
        assert_eq!(sessions[0].session_id, "session-earlier");
        assert_eq!(sessions[1].session_id, "session-later");
    }

    #[test]
    fn assigned_pathways_group_playlists_under_their_pathway() {
        let library = sample_library_with_pathways(vec![]);
        let grouped = build_assigned_pathways(
            &library,
            &[
                sample_assigned_journey_in_pathway(
                    "assignment-1",
                    "pathway-addition",
                    "Addition Foundations",
                    sample_session_on(2026, 1, 2, "session-1", "Session 1"),
                ),
                sample_assigned_journey_in_pathway(
                    "assignment-2",
                    "pathway-addition",
                    "Addition Foundations",
                    sample_session_on(2026, 1, 3, "session-2", "Session 2"),
                ),
                sample_assigned_journey_in_pathway(
                    "assignment-3",
                    "pathway-subtraction",
                    "Subtraction Foundations",
                    sample_session_on(2026, 1, 4, "session-3", "Session 3"),
                ),
            ],
        );

        assert_eq!(grouped.len(), 2);
        assert_eq!(grouped[0].pathway_title, "Addition Foundations");
        assert_eq!(grouped[0].playlist_count, 2);
        assert_eq!(grouped[0].assigned_playlists.len(), 2);
        assert_eq!(grouped[1].pathway_title, "Subtraction Foundations");
        assert_eq!(grouped[1].playlist_count, 1);
    }

    #[test]
    fn assigned_pathways_preserve_authored_playlist_order() {
        let library = sample_library_with_pathways(vec![Pathway {
            pathway_id: "pathway-addition".to_string(),
            title: "Addition Foundations".to_string(),
            subject_id: "maths".to_string(),
            area_id: "arithmetic".to_string(),
            recommended_age_min: 7,
            recommended_age_max: 10,
            stage_ids: vec![],
            playlist_ids: vec![
                "playlist-earliest".to_string(),
                "playlist-middle".to_string(),
                "playlist-latest".to_string(),
            ],
            entry_points: Default::default(),
            description: String::new(),
            source_path: String::new(),
        }]);
        let grouped = build_assigned_pathways(
            &library,
            &[
                sample_assigned_journey_for_playlist(
                    "assignment-latest",
                    "playlist-latest",
                    "pathway-addition",
                    "Addition Foundations",
                    sample_session_on(2026, 1, 4, "session-3", "Session 3"),
                ),
                sample_assigned_journey_for_playlist(
                    "assignment-earliest",
                    "playlist-earliest",
                    "pathway-addition",
                    "Addition Foundations",
                    sample_session_on(2026, 1, 2, "session-1", "Session 1"),
                ),
                sample_assigned_journey_for_playlist(
                    "assignment-middle",
                    "playlist-middle",
                    "pathway-addition",
                    "Addition Foundations",
                    sample_session_on(2026, 1, 3, "session-2", "Session 2"),
                ),
            ],
        );

        let playlist_ids = grouped[0]
            .assigned_playlists
            .iter()
            .map(|journey| journey.journey.playlist_id.as_str())
            .collect::<Vec<_>>();

        assert_eq!(
            playlist_ids,
            vec!["playlist-earliest", "playlist-middle", "playlist-latest"]
        );
    }

    #[test]
    fn compile_bootstrap_flattens_shared_users_across_multiple_teams() {
        let bootstrap = IdentityBootstrap {
            teams: vec![
                BootstrapTeam {
                    team_id: "team-alpha".to_string(),
                    display_name: "Team Alpha".to_string(),
                    description: "Alpha".to_string(),
                    users: vec![
                        BootstrapUser {
                            user_id: "user-owner".to_string(),
                            username: "owner".to_string(),
                            display_name: "Owner One".to_string(),
                            first_name: Some("Owner".to_string()),
                            last_name: Some("One".to_string()),
                            email: Some("owner@example.com".to_string()),
                            google_subject: None,
                            google_email: None,
                            date_of_birth: None,
                            sex: None,
                            current_level: None,
                            notes: Some("Owner".to_string()),
                        },
                        BootstrapUser {
                            user_id: "user-learner-a".to_string(),
                            username: "learner-a".to_string(),
                            display_name: "Learner A".to_string(),
                            first_name: None,
                            last_name: None,
                            email: None,
                            google_subject: None,
                            google_email: None,
                            date_of_birth: NaiveDate::from_ymd_opt(2017, 1, 1),
                            sex: Some("Male".to_string()),
                            current_level: Some("Year 2".to_string()),
                            notes: None,
                        },
                    ],
                    memberships: vec![
                        BootstrapMembership {
                            user_id: "user-owner".to_string(),
                            role: "owner".to_string(),
                        },
                        BootstrapMembership {
                            user_id: "user-learner-a".to_string(),
                            role: "learner".to_string(),
                        },
                    ],
                },
                BootstrapTeam {
                    team_id: "team-beta".to_string(),
                    display_name: "Team Beta".to_string(),
                    description: "Beta".to_string(),
                    users: vec![
                        BootstrapUser {
                            user_id: "user-owner".to_string(),
                            username: "owner".to_string(),
                            display_name: "Owner One".to_string(),
                            first_name: Some("Owner".to_string()),
                            last_name: Some("One".to_string()),
                            email: Some("owner@example.com".to_string()),
                            google_subject: None,
                            google_email: None,
                            date_of_birth: None,
                            sex: None,
                            current_level: None,
                            notes: Some("Owner".to_string()),
                        },
                        BootstrapUser {
                            user_id: "user-learner-b".to_string(),
                            username: "learner-b".to_string(),
                            display_name: "Learner B".to_string(),
                            first_name: None,
                            last_name: None,
                            email: None,
                            google_subject: None,
                            google_email: None,
                            date_of_birth: NaiveDate::from_ymd_opt(2018, 2, 2),
                            sex: Some("Female".to_string()),
                            current_level: Some("Year 1".to_string()),
                            notes: None,
                        },
                    ],
                    memberships: vec![
                        BootstrapMembership {
                            user_id: "user-owner".to_string(),
                            role: "owner".to_string(),
                        },
                        BootstrapMembership {
                            user_id: "user-learner-b".to_string(),
                            role: "learner".to_string(),
                        },
                    ],
                },
            ],
        };

        let compiled = compile_bootstrap(&bootstrap).expect("bootstrap should compile");

        assert_eq!(compiled.teams.len(), 2);
        assert_eq!(compiled.users.len(), 3);
        assert_eq!(compiled.memberships.len(), 4);
        assert_eq!(compiled.learner_count, 2);
    }

    #[test]
    fn compile_bootstrap_rejects_conflicting_shared_user_definitions() {
        let bootstrap = IdentityBootstrap {
            teams: vec![
                BootstrapTeam {
                    team_id: "team-alpha".to_string(),
                    display_name: "Team Alpha".to_string(),
                    description: "Alpha".to_string(),
                    users: vec![BootstrapUser {
                        user_id: "user-owner".to_string(),
                        username: "owner".to_string(),
                        display_name: "Owner One".to_string(),
                        first_name: Some("Owner".to_string()),
                        last_name: Some("One".to_string()),
                        email: Some("owner@example.com".to_string()),
                        google_subject: None,
                        google_email: None,
                        date_of_birth: None,
                        sex: None,
                        current_level: None,
                        notes: Some("Owner".to_string()),
                    }],
                    memberships: vec![BootstrapMembership {
                        user_id: "user-owner".to_string(),
                        role: "owner".to_string(),
                    }],
                },
                BootstrapTeam {
                    team_id: "team-beta".to_string(),
                    display_name: "Team Beta".to_string(),
                    description: "Beta".to_string(),
                    users: vec![BootstrapUser {
                        user_id: "user-owner".to_string(),
                        username: "owner".to_string(),
                        display_name: "Owner With Different Name".to_string(),
                        first_name: Some("Owner".to_string()),
                        last_name: Some("One".to_string()),
                        email: Some("owner@example.com".to_string()),
                        google_subject: None,
                        google_email: None,
                        date_of_birth: None,
                        sex: None,
                        current_level: None,
                        notes: Some("Owner".to_string()),
                    }],
                    memberships: vec![BootstrapMembership {
                        user_id: "user-owner".to_string(),
                        role: "owner".to_string(),
                    }],
                },
            ],
        };

        let error = compile_bootstrap(&bootstrap).expect_err("bootstrap should be rejected");

        assert!(
            error.to_string().contains("defined differently across teams"),
            "unexpected error: {error}"
        );
    }

    fn sample_assigned_journey(assignment_id: &str, session: SessionDetail) -> LearnerAssignedJourneySummary {
        sample_assigned_journey_in_pathway(assignment_id, "pathway-1", "Pathway 1", session)
    }

    fn sample_assigned_journey_in_pathway(
        assignment_id: &str,
        pathway_id: &str,
        pathway_title: &str,
        session: SessionDetail,
    ) -> LearnerAssignedJourneySummary {
        sample_assigned_journey_for_playlist(
            assignment_id,
            &format!("playlist-{assignment_id}"),
            pathway_id,
            pathway_title,
            session,
        )
    }

    fn sample_assigned_journey_for_playlist(
        assignment_id: &str,
        playlist_id: &str,
        pathway_id: &str,
        pathway_title: &str,
        session: SessionDetail,
    ) -> LearnerAssignedJourneySummary {
        LearnerAssignedJourneySummary {
            assignment: AssignmentSummary {
                assignment_id: assignment_id.to_string(),
                playlist_id: playlist_id.to_string(),
                title: format!("Playlist {assignment_id}"),
                start_date: NaiveDate::from_ymd_opt(2026, 1, 1).expect("valid date"),
                end_date: NaiveDate::from_ymd_opt(2026, 1, 4).expect("valid date"),
                status: "active".to_string(),
                total_sessions: 1,
                completed_sessions: 0,
                completion_percent: 0,
            },
            journey: LearnerJourneySummary {
                pathway_id: Some(pathway_id.to_string()),
                pathway_title: Some(pathway_title.to_string()),
                pathway_description: Some("Description".to_string()),
                pathway_route_path: None,
                playlist_id: playlist_id.to_string(),
                playlist_title: format!("Playlist {assignment_id}"),
                playlist_description: "Description".to_string(),
                playlist_route_path: None,
                recommended_age: 7,
                recommended_level: "Level 1".to_string(),
                duration_days: 4,
                total_session_count: 1,
                completed_session_count: 0,
                pending_session_count: 1,
                total_material_count: 1,
                live_material_count: 0,
                next_session_id: Some(session.session_id.clone()),
            },
            current_session_id: Some(session.session_id.clone()),
            continue_block: Some(LearnerContinueBlock {
                title: "Continue".to_string(),
                description: "desc".to_string(),
                action_label: "Open practice".to_string(),
                session: session.clone(),
            }),
            sessions: vec![session],
        }
    }

    fn sample_library_with_pathways(pathways: Vec<Pathway>) -> LibraryBundle {
        LibraryBundle {
            subjects: vec![],
            areas: vec![],
            pathways,
            skills: vec![],
            stages: vec![],
            playlists: vec![],
            materials: vec![],
        }
    }
}
