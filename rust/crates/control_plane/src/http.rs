use std::sync::Arc;

use anyhow::{Error, anyhow};
use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Redirect, Response};
use axum::routing::{delete, get, post};
use axum::{Json, Router};
use axum_extra::extract::CookieJar;
use axum_extra::extract::cookie::{Cookie, SameSite};
use serde::{Deserialize, Serialize};
use tower_http::trace::TraceLayer;
use url::Url;
use uuid::Uuid;

use catalog::LibraryBundle;
use learning_activity_runtime::written_arithmetic::{self, CheckRequest, CheckResult, WorksheetRequest, WrittenLevel};

use crate::domain::{
    ActivityStartResponse, AssignmentReconcileRequest, AssignmentRequest, CheckActivityRequest,
    CompleteActivityRequest, CompleteActivityResponse, LibraryDocumentResponse, LibraryDocumentsResponse,
    LibraryReloadResponse, OperationStatusResponse, RecordSessionRequest, ReviewRebuildRequest,
    SwitchActiveTeamRequest, SwitchActiveUserRequest, ViewerSessionResponse,
};
use crate::service::{
    AppState, apply_bootstrap, check_activity_instance, clear_readiness_override, complete_activity_instance,
    create_assignment, delete_viewer_session, fetch_auth_options, fetch_dashboard, fetch_learner_detail,
    fetch_learner_workspace, fetch_library, fetch_library_document, fetch_library_workspace, fetch_viewer_session,
    finish_google_oauth_flow, list_learners, list_library_documents, rebuild_review_items,
    reconcile_assignments_from_library, record_session, reload_library, resolve_session_context,
    retry_missed_activity_facts, set_readiness_override, start_google_oauth_flow, start_review_item_activity,
    start_session_material_activity, switch_active_team, switch_active_user,
};

const SESSION_COOKIE_NAME: &str = "cornerstone_session";

#[derive(Debug)]
pub struct ApiError(pub Error);

#[derive(Debug, Clone, Serialize)]
struct ErrorPayload {
    status: String,
    message: String,
}

#[derive(Debug, Clone, Serialize)]
struct LibraryPayload {
    report: LibraryReloadResponse,
    bundle: LibraryBundle,
}

#[derive(Debug, Clone, Serialize)]
struct ServiceIndexResponse {
    status: String,
    service: String,
    message: String,
    health_url: String,
    api_base_url: String,
    frontend_url: String,
    frontend_preview_mode: String,
    docs_dev_command: String,
}

#[derive(Debug, Default, Deserialize)]
struct LibraryDocumentQuery {
    route_path: String,
}

#[derive(Debug, Serialize)]
struct WrittenLevelsResponse {
    levels: Vec<WrittenLevel>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WrittenPrintRequest {
    worksheet: WorksheetRequest,
    #[serde(default)]
    include_answers: bool,
    #[serde(default)]
    layout: crate::worksheet_print::PrintLayout,
}

#[derive(Debug, Default, Deserialize)]
struct PackageAssetQuery {
    integrity: Option<String>,
}

#[derive(Debug, Serialize)]
struct WrittenPrintResponse {
    html: String,
}

#[derive(Debug, Default, Deserialize)]
struct GoogleStartQuery {
    next: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
struct GoogleCallbackQuery {
    state: Option<String>,
    code: Option<String>,
    error: Option<String>,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let payload = Json(ErrorPayload {
            status: "error".to_string(),
            message: self.0.to_string(),
        });
        (StatusCode::BAD_REQUEST, payload).into_response()
    }
}

impl From<Error> for ApiError {
    fn from(value: Error) -> Self {
        Self(value)
    }
}

fn session_cookie_secure(frontend_public_url: &str) -> bool {
    Url::parse(frontend_public_url)
        .map(|url| url.scheme() == "https")
        .unwrap_or(false)
}

fn build_session_cookie(frontend_public_url: &str, session_id: Uuid) -> Cookie<'static> {
    Cookie::build((SESSION_COOKIE_NAME, session_id.to_string()))
        .path("/")
        .http_only(true)
        .same_site(SameSite::Lax)
        .secure(session_cookie_secure(frontend_public_url))
        .build()
}

fn clear_session_cookie(frontend_public_url: &str) -> Cookie<'static> {
    Cookie::build((SESSION_COOKIE_NAME, ""))
        .path("/")
        .http_only(true)
        .same_site(SameSite::Lax)
        .secure(session_cookie_secure(frontend_public_url))
        .build()
}

fn session_id_from_jar(jar: &CookieJar) -> Option<Uuid> {
    jar.get(SESSION_COOKIE_NAME)
        .and_then(|cookie| Uuid::parse_str(cookie.value()).ok())
}

async fn session_context_from_jar(
    jar: &CookieJar,
    state: &Arc<AppState>,
) -> Result<crate::service::SessionContext, ApiError> {
    let session_id =
        session_id_from_jar(jar).ok_or_else(|| ApiError(anyhow!("an authenticated session is required")))?;
    Ok(resolve_session_context(state, session_id).await?)
}

pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/health", get(health))
        .route("/api/v1/auth/options", get(get_auth_options))
        .route("/api/v1/auth/google/start", get(get_google_start))
        .route("/api/v1/auth/google/callback", get(get_google_callback))
        .route("/api/v1/auth/signout", post(post_signout))
        .route("/api/v1/session", get(get_viewer_session))
        .route("/api/v1/session/active-team", post(post_active_team))
        .route("/api/v1/session/active-user", post(post_active_user))
        .route("/api/v1/library", get(get_library))
        .route("/api/v1/library/workspace", get(get_library_workspace))
        .route("/api/v1/library/reload", post(post_library_reload))
        .route("/api/v1/library/documents", get(get_library_documents))
        .route("/api/v1/library/document", get(get_library_document))
        .route("/api/v1/written-arithmetic/levels", get(get_written_levels))
        .route("/api/v1/written-arithmetic/generate", post(post_written_generate))
        .route("/api/v1/written-arithmetic/check", post(post_written_check))
        .route(
            "/api/v1/library/materials/{material_id}/preview",
            post(post_material_preview),
        )
        .route(
            "/api/v1/library/materials/{material_id}/preview/check",
            post(post_material_preview_check),
        )
        .route(
            "/api/v1/library/materials/{material_id}/preview/complete",
            post(post_material_preview_complete),
        )
        .route("/api/v1/written-arithmetic/print", post(post_written_print))
        .route(
            "/api/v1/activity-packages/{package_id}/{version}/{*asset_path}",
            get(get_activity_package_asset),
        )
        .route("/api/v1/bootstrap/apply", post(post_bootstrap_apply))
        .route("/api/v1/dashboard", get(get_dashboard))
        .route("/api/v1/learners", get(get_learners))
        .route("/api/v1/learners/{learner_id}", get(get_learner_detail))
        .route("/api/v1/learners/{learner_id}/workspace", get(get_learner_workspace))
        .route("/api/v1/learners/{learner_id}/pathways", get(get_learner_pathways))
        .route(
            "/api/v1/learners/{learner_id}/pathways/{pathway_id}",
            get(get_learner_pathway),
        )
        .route(
            "/api/v1/learners/{learner_id}/readiness-overrides",
            post(post_readiness_override),
        )
        .route(
            "/api/v1/learners/{learner_id}/readiness-overrides/{material_id}",
            delete(delete_readiness_override),
        )
        .route("/api/v1/assignments", post(post_assignment))
        .route("/api/v1/assignments/reconcile", post(post_assignments_reconcile))
        .route("/api/v1/sessions/{session_id}/record", post(post_record_session))
        .route(
            "/api/v1/sessions/{session_id}/materials/{session_material_id}/start",
            post(post_start_session_material_activity),
        )
        .route(
            "/api/v1/activity-instances/{activity_instance_id}/check",
            post(post_check_activity_instance),
        )
        .route(
            "/api/v1/activity-instances/{activity_instance_id}/complete",
            post(post_complete_activity_instance),
        )
        .route(
            "/api/v1/activity-instances/{activity_instance_id}/retry",
            post(post_retry_activity_instance),
        )
        .route(
            "/api/v1/review-items/{review_item_id}/start",
            post(post_start_review_item),
        )
        .route("/api/v1/review-items/rebuild", post(post_review_rebuild))
        .with_state(state)
        .layer(TraceLayer::new_for_http())
}

async fn index(State(state): State<Arc<AppState>>) -> Json<ServiceIndexResponse> {
    Json(ServiceIndexResponse {
        status: "ok".to_string(),
        service: "cornerstone control plane".to_string(),
        message: "This port serves the control-plane API and service index for the Flutter app. Developer docs remain available through the standalone docs-site workflow.".to_string(),
        health_url: "/health".to_string(),
        api_base_url: "/api/v1".to_string(),
        frontend_url: state.config.frontend_public_url.clone(),
        frontend_preview_mode: "static-build".to_string(),
        docs_dev_command: "make docs-site-dev".to_string(),
    })
}

async fn health() -> Json<OperationStatusResponse> {
    Json(OperationStatusResponse {
        status: "ok".to_string(),
        message: "cornerstone control plane is healthy".to_string(),
    })
}

async fn post_material_preview(
    Path(material_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        crate::service::preview_material_activity(&state, &context, &material_id, None, false).await?,
    ))
}

async fn post_material_preview_check(
    Path(material_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<crate::domain::PreviewActivityRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        crate::service::preview_material_activity(&state, &context, &material_id, Some(request), false).await?,
    ))
}

async fn post_material_preview_complete(
    Path(material_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<crate::domain::PreviewActivityRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        crate::service::preview_material_activity(&state, &context, &material_id, Some(request), true).await?,
    ))
}

async fn get_written_levels(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<WrittenLevelsResponse>, ApiError> {
    session_context_from_jar(&jar, &state).await?;
    Ok(Json(WrittenLevelsResponse {
        levels: written_arithmetic::levels(),
    }))
}

async fn post_written_generate(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<WorksheetRequest>,
) -> Result<Json<serde_json::Value>, ApiError> {
    session_context_from_jar(&jar, &state).await?;
    let worksheet = written_arithmetic::generate(request)?;
    let descriptor =
        crate::activity_packages::resolve_package(&state.config.content_root, "written-arithmetic", "1.0.0")?;
    let mut presentation = serde_json::to_value(descriptor).map_err(Error::from)?;
    presentation["payload"] = serde_json::json!({"worksheet": worksheet, "mode": worksheet.request.mode});
    let mut response = serde_json::to_value(&worksheet).map_err(Error::from)?;
    response["presentation"] = presentation;
    Ok(Json(response))
}

async fn get_activity_package_asset(
    Path((package_id, version, asset_path)): Path<(String, String, String)>,
    Query(query): Query<PackageAssetQuery>,
    State(state): State<Arc<AppState>>,
) -> Result<Response, ApiError> {
    let content_root = state.config.content_root.clone();
    let asset = tokio::task::spawn_blocking(move || {
        crate::activity_packages::load_asset(
            &content_root,
            &package_id,
            &version,
            &asset_path,
            query.integrity.as_deref(),
        )
    })
    .await
    .map_err(Error::from)??;
    let frontend_origin = Url::parse(&state.config.frontend_public_url)
        .map_err(Error::from)?
        .origin()
        .ascii_serialization();
    let policy = format!(
        "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'self' {frontend_origin}; sandbox allow-scripts"
    );
    Ok((
        [
            ("Content-Type", asset.content_type.to_owned()),
            ("Content-Security-Policy", policy),
            ("Cache-Control", "no-cache".to_owned()),
            ("X-Content-Type-Options", "nosniff".to_owned()),
            ("Referrer-Policy", "no-referrer".to_owned()),
        ],
        asset.bytes,
    )
        .into_response())
}

async fn post_written_check(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<CheckRequest>,
) -> Result<Json<CheckResult>, ApiError> {
    session_context_from_jar(&jar, &state).await?;
    Ok(Json(written_arithmetic::check(request)?))
}

async fn post_written_print(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<WrittenPrintRequest>,
) -> Result<Json<WrittenPrintResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    if request.include_answers && !context.active_user.can_manage_team {
        return Err(ApiError(anyhow!(
            "only a parent or team manager can print the answer key"
        )));
    }
    Ok(Json(WrittenPrintResponse {
        html: crate::worksheet_print::render_with_layout(request.worksheet, request.include_answers, request.layout)?,
    }))
}

async fn get_auth_options(
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::AuthOptionsSummary>, ApiError> {
    Ok(Json(fetch_auth_options(&state).await?))
}

async fn get_viewer_session(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<ViewerSessionResponse>, ApiError> {
    Ok(Json(fetch_viewer_session(&state, session_id_from_jar(&jar)).await?))
}

async fn get_google_start(
    Query(query): Query<GoogleStartQuery>,
    State(state): State<Arc<AppState>>,
) -> Result<Redirect, ApiError> {
    let redirect = start_google_oauth_flow(&state, query.next.as_deref()).await?;
    Ok(Redirect::to(redirect.as_str()))
}

async fn get_google_callback(
    jar: CookieJar,
    Query(query): Query<GoogleCallbackQuery>,
    State(state): State<Arc<AppState>>,
) -> Result<(CookieJar, Redirect), ApiError> {
    let (session_id, redirect_url) = finish_google_oauth_flow(
        &state,
        query.state.as_deref(),
        query.code.as_deref(),
        query.error.as_deref(),
    )
    .await?;
    let jar = match session_id {
        Some(session_id) => jar.add(build_session_cookie(&state.config.frontend_public_url, session_id)),
        None => jar.remove(clear_session_cookie(&state.config.frontend_public_url)),
    };
    Ok((jar, Redirect::to(redirect_url.as_str())))
}

async fn post_signout(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<(CookieJar, Json<ViewerSessionResponse>), ApiError> {
    if let Some(session_id) = session_id_from_jar(&jar) {
        let _ = delete_viewer_session(&state, session_id).await;
    }
    let response = fetch_viewer_session(&state, None).await?;
    Ok((
        jar.remove(clear_session_cookie(&state.config.frontend_public_url)),
        Json(response),
    ))
}

async fn post_active_user(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<SwitchActiveUserRequest>,
) -> Result<Json<ViewerSessionResponse>, ApiError> {
    let session_id =
        session_id_from_jar(&jar).ok_or_else(|| ApiError(anyhow!("an authenticated session is required")))?;
    Ok(Json(switch_active_user(&state, session_id, &request.user_id).await?))
}

async fn post_active_team(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<SwitchActiveTeamRequest>,
) -> Result<Json<ViewerSessionResponse>, ApiError> {
    let session_id =
        session_id_from_jar(&jar).ok_or_else(|| ApiError(anyhow!("an authenticated session is required")))?;
    Ok(Json(switch_active_team(&state, session_id, &request.team_id).await?))
}

async fn get_library(jar: CookieJar, State(state): State<Arc<AppState>>) -> Result<Json<LibraryPayload>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    let (bundle, report) = fetch_library(&state, &context).await?;
    Ok(Json(LibraryPayload { report, bundle }))
}

async fn get_library_workspace(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::LibraryWorkspaceResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(fetch_library_workspace(&state, &context).await?))
}

async fn post_library_reload(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<LibraryReloadResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(reload_library(&state, &context).await?))
}

async fn get_library_documents(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<LibraryDocumentsResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(LibraryDocumentsResponse {
        status: "ok".to_string(),
        documents: list_library_documents(&state, &context).await?,
    }))
}

async fn get_library_document(
    Query(query): Query<LibraryDocumentQuery>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<LibraryDocumentResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(LibraryDocumentResponse {
        status: "ok".to_string(),
        document: fetch_library_document(&state, &context, &query.route_path).await?,
    }))
}

async fn post_bootstrap_apply(
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::BootstrapApplyResponse>, ApiError> {
    Ok(Json(apply_bootstrap(&state).await?))
}

async fn get_dashboard(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::DashboardResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(fetch_dashboard(&state, &context).await?))
}

async fn get_learners(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<crate::domain::LearnerSummary>>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(list_learners(&state, &context).await?))
}

async fn get_learner_detail(
    Path(learner_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::LearnerDetailResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(fetch_learner_detail(&state, &context, &learner_id).await?))
}

async fn get_learner_workspace(
    Path(learner_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::LearnerWorkspaceResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(fetch_learner_workspace(&state, &context, &learner_id).await?))
}

async fn get_learner_pathways(
    Path(learner_id): Path<String>,
    Query(query): Query<crate::domain::LearnerPathwayQuery>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::LearnerPathwayCatalog>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        crate::service::fetch_learner_pathways(&state, &context, &learner_id, &query).await?,
    ))
}

async fn get_learner_pathway(
    Path((learner_id, pathway_id)): Path<(String, String)>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::LearnerPathwayMap>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        crate::service::fetch_learner_pathway(&state, &context, &learner_id, &pathway_id).await?,
    ))
}

async fn post_assignment(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<AssignmentRequest>,
) -> Result<Json<crate::domain::AssignmentResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(create_assignment(&state, &context, request).await?))
}

async fn post_assignments_reconcile(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<AssignmentReconcileRequest>,
) -> Result<Json<crate::domain::AssignmentReconcileResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        reconcile_assignments_from_library(&state, &context, request).await?,
    ))
}

async fn post_readiness_override(
    Path(learner_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<crate::domain::ReadinessOverrideRequest>,
) -> Result<Json<crate::domain::ReadinessOverrideResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        set_readiness_override(&state, &context, &learner_id, request).await?,
    ))
}

async fn delete_readiness_override(
    Path((learner_id, material_id)): Path<(String, String)>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<crate::domain::ReadinessOverrideResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        clear_readiness_override(&state, &context, &learner_id, &material_id).await?,
    ))
}

async fn post_record_session(
    Path(session_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<RecordSessionRequest>,
) -> Result<Json<crate::domain::RecordSessionResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(record_session(&state, &context, &session_id, request).await?))
}

async fn post_start_session_material_activity(
    Path((session_id, session_material_id)): Path<(String, String)>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<ActivityStartResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        start_session_material_activity(&state, &context, &session_id, &session_material_id).await?,
    ))
}

async fn post_check_activity_instance(
    Path(activity_instance_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<CheckActivityRequest>,
) -> Result<Json<CheckResult>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        check_activity_instance(&state, &context, &activity_instance_id, request).await?,
    ))
}

async fn post_complete_activity_instance(
    Path(activity_instance_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<CompleteActivityRequest>,
) -> Result<Json<CompleteActivityResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        complete_activity_instance(&state, &context, &activity_instance_id, request).await?,
    ))
}

async fn post_retry_activity_instance(
    Path(activity_instance_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<ActivityStartResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        retry_missed_activity_facts(&state, &context, &activity_instance_id).await?,
    ))
}

async fn post_start_review_item(
    Path(review_item_id): Path<String>,
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
) -> Result<Json<ActivityStartResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(
        start_review_item_activity(&state, &context, &review_item_id).await?,
    ))
}

async fn post_review_rebuild(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<ReviewRebuildRequest>,
) -> Result<Json<crate::domain::ReviewRebuildResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(rebuild_review_items(&state, &context, request.learner_id).await?))
}
