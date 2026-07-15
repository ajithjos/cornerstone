use std::collections::BTreeMap;

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionStatus {
    Scheduled,
    Active,
    Completed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionMaterialStatus {
    Scheduled,
    Active,
    Completed,
}

impl SessionMaterialStatus {
    pub fn from_db(value: &str) -> Self {
        match value {
            "scheduled" => Self::Scheduled,
            "active" => Self::Active,
            "completed" => Self::Completed,
            _ => panic!("invalid persisted session material status '{value}'"),
        }
    }
}

impl SessionStatus {
    pub fn from_db(value: &str) -> Self {
        match value {
            "scheduled" => Self::Scheduled,
            "active" => Self::Active,
            "completed" => Self::Completed,
            _ => panic!("invalid persisted session status '{value}'"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunStatus {
    InProgress,
    Finished,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunOutcome {
    TargetMet,
    TargetNotMet,
}

impl RunOutcome {
    pub fn as_db(self) -> &'static str {
        match self {
            Self::TargetMet => "target_met",
            Self::TargetNotMet => "target_not_met",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SkillStatus {
    NotStarted,
    NeedsPractice,
    ReadyForCheck,
    Confirmed,
}

impl SkillStatus {
    pub fn from_db(value: &str) -> Self {
        match value {
            "needs_practice" => Self::NeedsPractice,
            "ready_for_check" => Self::ReadyForCheck,
            "confirmed" => Self::Confirmed,
            _ => panic!("invalid persisted skill status '{value}'"),
        }
    }

    pub fn as_db(self) -> &'static str {
        match self {
            Self::NotStarted => "not_started",
            Self::NeedsPractice => "needs_practice",
            Self::ReadyForCheck => "ready_for_check",
            Self::Confirmed => "confirmed",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReviewStatus {
    NotDue,
    Due,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActivityRunMode {
    Practice,
    Check,
    Review,
    Retry,
}

#[derive(Debug, Clone, Serialize)]
pub struct OperationStatusResponse {
    pub status: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LibraryReloadResponse {
    pub status: String,
    pub subject_count: usize,
    pub area_count: usize,
    pub pathway_count: usize,
    pub skill_count: usize,
    pub stage_count: usize,
    pub playlist_count: usize,
    pub material_count: usize,
    pub loaded_at_utc: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LibraryDocumentSummary {
    pub route_path: String,
    pub source_path: String,
    pub kind: String,
    pub document_id: String,
    pub title: String,
    pub subject_id: String,
    pub area_id: String,
    pub pathway_id: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LibraryDocumentsResponse {
    pub status: String,
    pub documents: Vec<LibraryDocumentSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LibraryDocumentPayload {
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

#[derive(Debug, Clone, Serialize)]
pub struct LibraryDocumentResponse {
    pub status: String,
    pub document: LibraryDocumentPayload,
}

#[derive(Debug, Clone, Serialize)]
pub struct LibraryWorkspaceResponse {
    pub status: String,
    pub featured_route_path: Option<String>,
    pub pathways: Vec<PathwayWorkspaceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PathwayWorkspaceSummary {
    pub pathway_id: String,
    pub title: String,
    pub description: String,
    pub area_title: String,
    pub recommended_age_min: u8,
    pub recommended_age_max: u8,
    pub stage_count: usize,
    pub playlist_count: usize,
    pub route_path: Option<String>,
    pub entry_points: Vec<PathwayEntryPointSummary>,
    pub playlists: Vec<PlaylistWorkspaceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PathwayEntryPointSummary {
    pub age: u8,
    pub playlist_id: String,
    pub playlist_title: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct PlaylistWorkspaceSummary {
    pub playlist_id: String,
    pub title: String,
    pub description: String,
    pub recommended_age: u8,
    pub recommended_level: String,
    pub duration_days: i32,
    pub stage_count: usize,
    pub skill_count: usize,
    pub material_count: usize,
    pub live_material_count: usize,
    pub delivery_shape: PlaylistDeliveryShapeSummary,
    pub assignment_targets: Vec<PlaylistAssignmentTargetSummary>,
    pub route_path: Option<String>,
    pub sessions: Vec<PlaylistSessionWorkspaceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PlaylistDeliveryShapeSummary {
    pub estimated_total_minutes: u32,
    pub lesson_note_count: usize,
    pub teaching_note_count: usize,
    pub worksheet_count: usize,
    pub drill_count: usize,
    pub quick_check_count: usize,
    pub requires_adult_support: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct PlaylistAssignmentTargetSummary {
    pub learner_id: String,
    pub display_name: String,
    pub current_age: i32,
    pub current_level: String,
    pub recommended: bool,
    pub status_label: String,
    pub assigned_here: bool,
    pub active_assignment_title: Option<String>,
    pub assigned_assignment_titles: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PlaylistSessionWorkspaceSummary {
    pub session_index: usize,
    pub authored_session_id: String,
    pub day_offset: i32,
    pub title: String,
    pub skill_ids: Vec<String>,
    pub dominant_kind: String,
    pub requires_adult_support: bool,
    pub material_count: usize,
    pub estimated_minutes: u32,
    pub live_material_count: usize,
    pub materials_by_kind: Vec<WorkspaceMaterialKindGroupSummary>,
    pub materials: Vec<MaterialWorkspaceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct MaterialWorkspaceSummary {
    pub material_id: String,
    pub title: String,
    pub kind: String,
    pub audience: String,
    pub estimated_minutes: u16,
    pub skill_ids: Vec<String>,
    pub executable: bool,
    pub route_path: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct WorkspaceMaterialKindGroupSummary {
    pub kind: String,
    pub audience: String,
    pub material_count: usize,
    pub materials: Vec<MaterialWorkspaceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct BootstrapApplyResponse {
    pub status: String,
    pub team_count: usize,
    pub user_count: usize,
    pub membership_count: usize,
    pub learner_count: usize,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AssignmentReconcileRequest {
    pub learner_id: Option<String>,
    pub assignment_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AssignmentReconcileResponse {
    pub status: String,
    pub assignment_count: usize,
    pub sessions_inserted: usize,
    pub sessions_updated: usize,
    pub sessions_deleted: usize,
    pub material_refs_inserted: usize,
    pub material_refs_updated: usize,
    pub material_refs_deleted: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct DashboardResponse {
    pub team: Option<TeamSummary>,
    pub library: Option<LibraryReloadResponse>,
    pub learners: Vec<LearnerDashboard>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ViewerSessionResponse {
    pub status: String,
    pub authenticated: bool,
    pub auth: AuthOptionsSummary,
    pub team: Option<TeamSummary>,
    pub available_teams: Vec<TeamSummary>,
    pub authenticated_user: Option<TeamMemberSummary>,
    pub active_user: Option<TeamMemberSummary>,
    pub available_users: Vec<TeamMemberSummary>,
    pub developer_docs_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AuthOptionsSummary {
    pub google_signin: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TeamSummary {
    pub team_id: String,
    pub display_name: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct TeamMemberSummary {
    pub user_id: String,
    pub username: String,
    pub display_name: String,
    pub role: String,
    pub current_level: Option<String>,
    pub notes: String,
    pub learner_id: Option<String>,
    pub google_signed_in: bool,
    pub google_display_name: Option<String>,
    pub google_picture_url: Option<String>,
    pub google_email: Option<String>,
    pub can_manage_team: bool,
    pub can_read_library: bool,
    pub can_view_all_learners: bool,
    pub can_open_developer_docs: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerDashboard {
    pub learner_id: String,
    pub display_name: String,
    pub current_age: i32,
    pub current_level: String,
    pub notes: String,
    pub attention_state: String,
    pub attention_label: String,
    pub next_action_label: String,
    pub active_assignment: Option<AssignmentSummary>,
    pub today_session: Option<SessionSummary>,
    pub review_due_count: i64,
    pub progress_status_counts: BTreeMap<String, i64>,
    pub stage_progress: Vec<StageProgress>,
    pub latest_evidence: Option<EvidenceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerDetailResponse {
    pub learner: LearnerSummary,
    pub active_assignment: Option<AssignmentSummary>,
    pub journey: Option<LearnerJourneySummary>,
    pub assigned_journeys: Vec<LearnerAssignedJourneySummary>,
    pub assigned_pathways: Vec<LearnerAssignedPathwaySummary>,
    pub sessions: Vec<SessionDetail>,
    pub progress: Vec<SkillProgressSummary>,
    pub review_items: Vec<ReviewItemSummary>,
    pub practice_mastery: Vec<PracticeMasterySummary>,
    pub workspace: LearnerWorkspaceSummary,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerWorkspaceResponse {
    pub status: String,
    pub workspace_view: String,
    pub viewer_role: String,
    pub includes_adult_materials: bool,
    pub learner: LearnerSummary,
    pub active_assignment: Option<AssignmentSummary>,
    pub journey: Option<LearnerJourneySummary>,
    pub assigned_journeys: Vec<LearnerAssignedJourneySummary>,
    pub assigned_pathways: Vec<LearnerAssignedPathwaySummary>,
    pub sessions: Vec<SessionDetail>,
    pub progress: Vec<SkillProgressSummary>,
    pub review_items: Vec<ReviewItemSummary>,
    pub practice_mastery: Vec<PracticeMasterySummary>,
    pub workspace: LearnerWorkspaceSummary,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerAssignedJourneySummary {
    pub assignment: AssignmentSummary,
    pub journey: LearnerJourneySummary,
    pub current_session_id: Option<String>,
    pub continue_block: Option<LearnerContinueBlock>,
    pub sessions: Vec<SessionDetail>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerAssignedPathwaySummary {
    pub pathway_id: Option<String>,
    pub pathway_title: String,
    pub pathway_description: String,
    pub pathway_route_path: Option<String>,
    pub playlist_count: usize,
    pub total_session_count: usize,
    pub completed_session_count: usize,
    pub pending_session_count: usize,
    pub assigned_playlists: Vec<LearnerAssignedJourneySummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerWorkspaceSummary {
    pub attention_label: String,
    pub continue_block: Option<LearnerContinueBlock>,
    pub practice_lane: Vec<SessionDetail>,
    pub progress_snapshot: LearnerProgressSnapshot,
    pub recent_wins: Vec<LearnerRecentWinSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerContinueBlock {
    pub title: String,
    pub description: String,
    pub action_label: String,
    pub session: SessionDetail,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerProgressSnapshot {
    pub confirmed_count: usize,
    pub ready_for_check_count: usize,
    pub needs_practice_count: usize,
    pub not_started_count: usize,
    pub review_due_count: usize,
    pub completed_session_count: usize,
    pub pending_session_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerRecentWinSummary {
    pub session_id: String,
    pub session_title: String,
    pub score_label: String,
    pub notes: String,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerJourneySummary {
    pub pathway_id: Option<String>,
    pub pathway_title: Option<String>,
    pub pathway_description: Option<String>,
    pub pathway_route_path: Option<String>,
    pub playlist_id: String,
    pub playlist_title: String,
    pub playlist_description: String,
    pub playlist_route_path: Option<String>,
    pub recommended_age: u8,
    pub recommended_level: String,
    pub duration_days: i32,
    pub total_session_count: usize,
    pub completed_session_count: usize,
    pub pending_session_count: usize,
    pub total_material_count: usize,
    pub live_material_count: usize,
    pub next_session_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LearnerSummary {
    pub learner_id: String,
    pub display_name: String,
    pub current_age: i32,
    pub current_level: String,
    pub notes: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AssignmentSummary {
    pub assignment_id: String,
    pub playlist_id: String,
    pub title: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub status: String,
    pub total_sessions: i32,
    pub completed_sessions: i32,
    pub completion_percent: i32,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionSummary {
    pub session_id: String,
    pub title: String,
    pub scheduled_date: NaiveDate,
    pub status: SessionStatus,
    pub day_offset: i32,
    pub sequence_number: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionDetail {
    pub session_id: String,
    pub title: String,
    pub scheduled_date: NaiveDate,
    pub status: SessionStatus,
    pub day_offset: i32,
    pub sequence_number: Option<usize>,
    pub dominant_kind: String,
    pub requires_adult_support: bool,
    pub estimated_minutes: u32,
    pub live_material_count: usize,
    pub learner_material_count: usize,
    pub adult_material_count: usize,
    pub notes: String,
    pub materials_by_kind: Vec<SessionMaterialKindGroupSummary>,
    pub materials: Vec<SessionMaterialSummary>,
    pub latest_evidence: Option<EvidenceSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionMaterialSummary {
    pub session_material_id: String,
    pub title: String,
    pub material_id: String,
    pub kind: String,
    pub audience: String,
    pub estimated_minutes: u16,
    pub skill_ids: Vec<String>,
    pub status: SessionMaterialStatus,
    pub document_route_path: Option<String>,
    pub document_body: Option<String>,
    pub printable: bool,
    pub runtime: Option<SessionMaterialRuntimeSummary>,
    pub readiness: Option<SessionMaterialReadinessSummary>,
    pub gate: Option<SessionMaterialGateSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionMaterialKindGroupSummary {
    pub kind: String,
    pub audience: String,
    pub material_count: usize,
    pub materials: Vec<SessionMaterialSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionMaterialRuntimeSummary {
    pub runtime_id: String,
    pub engine_id: String,
    pub template_id: String,
    pub executable: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionMaterialReadinessSummary {
    pub minimum_runs: usize,
    pub recent_run_window: usize,
    pub target_accuracy: f64,
    pub consecutive_target_runs_required: usize,
    pub target_correct_count: Option<usize>,
    pub minimum_distinct_items: usize,
    pub minimum_family_count: usize,
    pub max_duration_seconds: Option<u32>,
    pub override_applied: bool,
    pub override_reason: String,
    pub run_count: usize,
    pub recent_run_count: usize,
    pub recent_average_accuracy: f64,
    pub consecutive_target_run_count: usize,
    pub best_correct_count: usize,
    pub distinct_item_count: usize,
    pub ready_for_check: bool,
    pub skill_status: SkillStatus,
    pub status_label: String,
    pub detail_label: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionMaterialGateSummary {
    pub enabled: bool,
    pub prerequisite_material_id: String,
    pub prerequisite_title: String,
    pub prerequisite_skill_status: SkillStatus,
    pub reason_label: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ReadinessOverrideRequest {
    pub material_id: String,
    pub minimum_runs: i32,
    pub recent_run_window: i32,
    pub target_accuracy: f64,
    pub consecutive_target_runs: i32,
    pub target_correct_count: Option<i32>,
    pub minimum_distinct_items: Option<i32>,
    pub minimum_family_count: Option<i32>,
    pub max_duration_seconds: Option<i32>,
    #[serde(default)]
    pub reason: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReadinessOverrideResponse {
    pub status: String,
    pub learner_id: String,
    pub material_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct EvidenceSummary {
    pub evidence_id: String,
    pub score: f64,
    pub max_score: f64,
    pub duration_minutes: i32,
    pub notes: String,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillProgressSummary {
    pub skill_id: String,
    pub skill_status: SkillStatus,
    pub score_average: f64,
    pub last_score: f64,
    pub total_evidence: i32,
    pub last_evidence_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReviewItemSummary {
    pub review_item_id: String,
    pub skill_ids: Vec<String>,
    pub session_id: Option<String>,
    pub session_material_id: Option<String>,
    pub material_id: String,
    pub evidence_material_id: String,
    pub reason: String,
    pub fact_focus: Vec<String>,
    pub family_focus: Vec<String>,
    pub due_date: NaiveDate,
    pub review_status: ReviewStatus,
    pub action_label: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct PracticeMasterySummary {
    pub material_id: String,
    pub material_title: String,
    pub runtime_id: String,
    pub skill_status: SkillStatus,
    pub review_status: ReviewStatus,
    pub families: Vec<PracticeFamilyMasterySummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PracticeFamilyMasterySummary {
    pub family_key: String,
    pub label: String,
    pub attempted_count: i32,
    pub correct_count: i32,
    pub accuracy: f64,
    pub last_seen_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize)]
pub struct StageProgress {
    pub stage_id: String,
    pub title: String,
    pub completed_skills: usize,
    pub total_skills: usize,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AssignmentRequest {
    pub learner_id: String,
    pub playlist_id: String,
    pub start_date: Option<NaiveDate>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AssignmentResponse {
    pub status: String,
    pub assignment: AssignmentSummary,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RecordSessionRequest {
    pub score: f64,
    pub max_score: f64,
    pub duration_minutes: i32,
    pub notes: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RecordSessionResponse {
    pub status: String,
    pub evidence: EvidenceSummary,
    pub updated_progress: Vec<SkillProgressSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivityStartResponse {
    pub activity: ActivityInstance,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivityInstance {
    pub activity_instance_id: Uuid,
    pub run_status: RunStatus,
    pub run_mode: ActivityRunMode,
    pub session_id: String,
    pub session_material_id: String,
    pub material_id: String,
    pub material_title: String,
    pub runtime_id: String,
    pub engine_id: String,
    pub template_id: String,
    pub instructions: String,
    pub estimated_minutes: u16,
    pub started_at: DateTime<Utc>,
    pub scoring: ActivityScoringSummary,
    pub items: Vec<ActivityItem>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivityScoringSummary {
    pub target_accuracy: f64,
    pub max_duration_seconds: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivityItem {
    pub item_id: String,
    pub content: String,
    pub response_kind: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CompleteActivityRequest {
    pub responses: Vec<ActivityResponseInput>,
    pub duration_seconds: i32,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ActivityResponseInput {
    pub item_id: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CompleteActivityResponse {
    pub run_status: RunStatus,
    pub run_outcome: RunOutcome,
    pub run_outcome_label: String,
    pub retry_available: bool,
    pub evidence: EvidenceSummary,
    pub updated_progress: Vec<SkillProgressSummary>,
    pub activity_summary: ActivitySummary,
    pub readiness: Option<SessionMaterialReadinessSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivitySummary {
    pub attempted_count: usize,
    pub correct_count: usize,
    pub item_count: usize,
    pub accuracy: f64,
    pub completion_reason: String,
    pub started_at: Option<DateTime<Utc>>,
    pub completed_at: DateTime<Utc>,
    pub duration_seconds: i32,
    pub weak_family_keys: Vec<String>,
    pub corrections: Vec<ActivityCorrectionSummary>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ActivityCorrectionSummary {
    pub item_id: String,
    pub content: String,
    pub submitted_response: String,
    pub expected_response: String,
    pub fact_key: String,
    pub family_keys: Vec<String>,
    pub correction_cue: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ReviewRebuildRequest {
    pub learner_id: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SwitchActiveUserRequest {
    pub user_id: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SwitchActiveTeamRequest {
    pub team_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReviewRebuildResponse {
    pub status: String,
    pub learner_ids: Vec<String>,
    pub review_item_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct ActivityInstanceRow {
    pub activity_instance_id: Uuid,
    pub learner_id: String,
    pub session_id: String,
    pub session_material_id: String,
    pub material_id: String,
    pub evidence_material_id: String,
    pub mode: String,
    pub status: String,
    pub run_outcome: Option<String>,
    pub plan: JsonValue,
    pub result: Option<JsonValue>,
    pub review_item_id: Option<String>,
    pub retry_origin_activity_instance_id: Option<Uuid>,
    pub evidence_id: Option<String>,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
    pub duration_seconds: Option<i32>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct TeamRow {
    pub team_id: String,
    pub display_name: String,
    pub description: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct TeamMemberRow {
    pub user_id: String,
    pub username: String,
    pub display_name: String,
    pub role: String,
    pub current_level: Option<String>,
    pub notes: String,
    pub learner_id: Option<String>,
    pub google_subject: Option<String>,
    pub google_display_name: Option<String>,
    pub google_picture_url: Option<String>,
    pub google_email: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct LearnerRow {
    pub learner_id: String,
    pub team_id: String,
    pub user_id: String,
    pub display_name: String,
    pub date_of_birth: NaiveDate,
    pub sex: String,
    pub current_level: String,
    pub notes: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct AssignmentRow {
    pub assignment_id: String,
    pub learner_id: String,
    pub playlist_id: String,
    pub title: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub status: String,
    pub total_sessions: i32,
    pub completed_sessions: i32,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct SessionRow {
    pub session_id: String,
    pub assignment_id: String,
    pub learner_id: String,
    pub authored_session_id: String,
    pub title: String,
    pub scheduled_date: NaiveDate,
    pub status: String,
    pub day_offset: i32,
    pub notes: String,
    pub completed_at: Option<DateTime<Utc>>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct SessionMaterialRow {
    pub session_material_id: String,
    pub session_id: String,
    pub title: String,
    pub skill_id: String,
    pub material_id: String,
    pub status: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct EvidenceRow {
    pub evidence_id: String,
    pub session_id: String,
    pub learner_id: String,
    pub score: f64,
    pub max_score: f64,
    pub duration_minutes: i32,
    pub notes: String,
    pub recorded_at: DateTime<Utc>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct SkillProgressRow {
    pub learner_id: String,
    pub skill_id: String,
    pub status: String,
    pub score_average: f64,
    pub last_score: f64,
    pub total_evidence: i32,
    pub last_evidence_at: Option<DateTime<Utc>>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct ReviewItemRow {
    pub review_item_id: String,
    pub learner_id: String,
    pub skill_ids: JsonValue,
    pub session_id: Option<String>,
    pub session_material_id: Option<String>,
    pub material_id: String,
    pub evidence_material_id: String,
    pub reason: String,
    pub fact_focus: JsonValue,
    pub family_focus: JsonValue,
    pub due_date: NaiveDate,
    pub review_step: i32,
    pub is_actionable: bool,
    pub last_reviewed_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct FactProgressRow {
    pub learner_id: String,
    pub material_id: String,
    pub fact_key: String,
    pub attempted_count: i32,
    pub correct_count: i32,
    pub last_correct: bool,
    pub consecutive_correct_count: i32,
    pub last_seen_at: DateTime<Utc>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, FromRow)]
pub struct FamilyProgressRow {
    pub learner_id: String,
    pub material_id: String,
    pub family_key: String,
    pub attempted_count: i32,
    pub correct_count: i32,
    pub last_correct: bool,
    pub consecutive_correct_count: i32,
    pub last_seen_at: DateTime<Utc>,
}
