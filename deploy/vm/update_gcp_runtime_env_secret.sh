#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../common.sh"

REPO_ROOT="$(deploy_repo_root)"
CONFIG_FILE="${DEPLOY_VM_GCP_ENV_FILE:-$REPO_ROOT/deploy/config/environments/prod.gcp.env}"
LOCAL_CONFIG_FILE="${DEPLOY_VM_LOCAL_SETUP_ENV_FILE:-$REPO_ROOT/deploy/vm/local/control/prod.gcp.env}"
SOURCE_FILE="${DEPLOY_VM_RUNTIME_ENV_FILE:-$REPO_ROOT/deploy/vm/local/secrets/runtime-env.json}"
GCLOUD_BIN="$(deploy_resolve_cmd "deploy/vm" GCLOUD_BIN gcloud)"

load_contract() {
	[[ -f "$CONFIG_FILE" ]] || deploy_fail "deploy/vm" "tracked setup env file not found: $CONFIG_FILE"
	deploy_load_env_file "$CONFIG_FILE"
	deploy_load_env_file "$LOCAL_CONFIG_FILE"
	: "${GCP_CONFIG_NAME:?GCP_CONFIG_NAME is required}"
	: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
	: "${GCP_RUNTIME_ENV_SECRET_NAME:?GCP_RUNTIME_ENV_SECRET_NAME is required}"
}

check_preflight() {
	local active_config
	local current_project

	deploy_require_cmd "deploy/vm" python3
	[[ -f "$SOURCE_FILE" ]] || deploy_fail "deploy/vm" "runtime env source file not found: $SOURCE_FILE"

	active_config="$("$GCLOUD_BIN" config configurations list --filter=is_active:true --format='value(name)')"
	current_project="$("$GCLOUD_BIN" config get-value project 2>/dev/null | tr -d '\n')"
	[[ "$active_config" == "$GCP_CONFIG_NAME" ]] || deploy_fail "deploy/vm" "active gcloud config is '$active_config', expected '$GCP_CONFIG_NAME'"
	[[ "$current_project" == "$GCP_PROJECT_ID" ]] || deploy_fail "deploy/vm" "active gcloud project is '$current_project', expected '$GCP_PROJECT_ID'"
}

validate_runtime_env_json() {
	python3 - "$SOURCE_FILE" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
payload = json.loads(source.read_text(encoding="utf-8"))
if not isinstance(payload, dict):
    raise SystemExit("runtime env secret must be a top-level JSON object")

allowed = {
    "postgres_admin_password",
    "postgres_app_password",
    "google_oauth_client_id",
    "google_oauth_client_secret",
}
unknown = sorted(set(payload) - allowed)
if unknown:
    raise SystemExit("unsupported runtime env keys: " + ", ".join(unknown))

for key in ("postgres_admin_password", "postgres_app_password"):
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"runtime env secret is missing required non-empty key '{key}'")

for key, value in payload.items():
    if not isinstance(value, str):
        raise SystemExit(f"runtime env key '{key}' must be a string")

client_id = payload.get("google_oauth_client_id", "").strip()
client_secret = payload.get("google_oauth_client_secret", "").strip()
if client_id and not client_secret:
    raise SystemExit("google_oauth_client_secret is required when google_oauth_client_id is set")
PY
}

ensure_secret() {
	if ! "$GCLOUD_BIN" secrets describe "$GCP_RUNTIME_ENV_SECRET_NAME" --project "$GCP_PROJECT_ID" >/dev/null 2>&1; then
		"$GCLOUD_BIN" secrets create "$GCP_RUNTIME_ENV_SECRET_NAME" --replication-policy=automatic --project "$GCP_PROJECT_ID" >/dev/null
		deploy_log "deploy/vm" "Created secret $GCP_RUNTIME_ENV_SECRET_NAME in project $GCP_PROJECT_ID"
	fi
}

load_contract
check_preflight
validate_runtime_env_json
ensure_secret
"$GCLOUD_BIN" secrets versions add "$GCP_RUNTIME_ENV_SECRET_NAME" --project "$GCP_PROJECT_ID" --data-file "$SOURCE_FILE" >/dev/null
deploy_log "deploy/vm" "Updated secret $GCP_RUNTIME_ENV_SECRET_NAME from $SOURCE_FILE"
