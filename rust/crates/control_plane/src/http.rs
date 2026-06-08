use std::sync::Arc;

use anyhow::{Error, anyhow};
use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Redirect, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use axum_extra::extract::CookieJar;
use axum_extra::extract::cookie::{Cookie, SameSite};
use serde::{Deserialize, Serialize};
use tower_http::trace::TraceLayer;
use url::Url;
use uuid::Uuid;

use catalog::LibraryBundle;

use crate::domain::{
    ActivityStartResponse, AssignmentRequest, CompleteActivityRequest, CompleteActivityResponse,
    LibraryDocumentResponse, LibraryDocumentsResponse, LibraryReloadResponse, OperationStatusResponse,
    RecordSessionRequest, ReviewRebuildRequest, SwitchActiveTeamRequest, SwitchActiveUserRequest,
    ViewerSessionResponse,
};
use crate::service::{
    AppState, apply_bootstrap, complete_activity_instance, create_assignment, delete_viewer_session,
    fetch_auth_options, fetch_dashboard, fetch_learner_detail, fetch_learner_workspace, fetch_library,
    fetch_library_document, fetch_library_workspace, fetch_viewer_session, finish_google_oauth_flow, list_learners,
    list_library_documents, rebuild_review_items, record_session, reload_library, resolve_session_context,
    start_google_oauth_flow, start_session_material_activity, switch_active_team, switch_active_user,
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
        .route("/api/v1/bootstrap/apply", post(post_bootstrap_apply))
        .route("/api/v1/dashboard", get(get_dashboard))
        .route("/api/v1/learners", get(get_learners))
        .route("/api/v1/learners/{learner_id}", get(get_learner_detail))
        .route("/api/v1/learners/{learner_id}/workspace", get(get_learner_workspace))
        .route("/api/v1/assignments", post(post_assignment))
        .route("/api/v1/sessions/{session_id}/record", post(post_record_session))
        .route(
            "/api/v1/sessions/{session_id}/materials/{session_material_id}/start",
            post(post_start_session_material_activity),
        )
        .route(
            "/api/v1/activity-instances/{activity_instance_id}/complete",
            post(post_complete_activity_instance),
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

async fn post_assignment(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<AssignmentRequest>,
) -> Result<Json<crate::domain::AssignmentResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(create_assignment(&state, &context, request).await?))
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

async fn post_review_rebuild(
    jar: CookieJar,
    State(state): State<Arc<AppState>>,
    Json(request): Json<ReviewRebuildRequest>,
) -> Result<Json<crate::domain::ReviewRebuildResponse>, ApiError> {
    let context = session_context_from_jar(&jar, &state).await?;
    Ok(Json(rebuild_review_items(&state, &context, request.learner_id).await?))
}
