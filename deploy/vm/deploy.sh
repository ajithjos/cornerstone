#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../common.sh"

REPO_ROOT="$(deploy_repo_root)"
CONFIG_FILE="${DEPLOY_VM_GCP_ENV_FILE:-$REPO_ROOT/deploy/config/environments/prod.gcp.env}"
LOCAL_CONFIG_FILE="${DEPLOY_VM_LOCAL_SETUP_ENV_FILE:-$REPO_ROOT/deploy/vm/local/control/prod.gcp.env}"
GCLOUD_BIN="$(deploy_resolve_cmd "deploy/vm" GCLOUD_BIN gcloud)"
PLAN_ONLY=0
DOCTOR_ONLY=0
TEMP_FILES=()

# shellcheck source=../../dev/lib/gcloud.sh
source "$REPO_ROOT/dev/lib/gcloud.sh"

usage() {
	cat <<'EOF'
Usage: deploy/vm/deploy.sh [--plan]

--plan    print the resolved deployment plan without uploading anything
--doctor  validate the tracked gcloud configuration, project, and account only
EOF
}

cleanup_temp_files() {
	local path
	for path in "${TEMP_FILES[@]:-}"; do
		rm -f "$path"
	done
}

trap cleanup_temp_files EXIT

while [[ $# -gt 0 ]]; do
	case "$1" in
	--plan)
		PLAN_ONLY=1
		shift
		;;
	--doctor)
		DOCTOR_ONLY=1
		shift
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
done

create_temp_file() {
	local prefix="$1"
	local tmp_root="${TMPDIR:-/tmp}"
	mkdir -p "$tmp_root"
	mktemp "$tmp_root/${prefix}.XXXXXX"
}

fetch_runtime_env_secret() {
	"$GCLOUD_BIN" secrets versions access latest --secret "$GCP_RUNTIME_ENV_SECRET_NAME" --project "$GCP_PROJECT_ID"
}

runtime_secret_value() {
	local key="$1"
	local required="${2:-1}"
	RUNTIME_ENV_SECRET_JSON="$RUNTIME_ENV_SECRET_JSON" python3 - "$key" "$required" <<'PY'
import json
import os
import sys

key = sys.argv[1]
required = sys.argv[2] == "1"

try:
    payload = json.loads(os.environ["RUNTIME_ENV_SECRET_JSON"])
except json.JSONDecodeError as exc:
    raise SystemExit(f"[deploy/vm] runtime env secret is not valid JSON: {exc}") from exc

if not isinstance(payload, dict):
    raise SystemExit("[deploy/vm] runtime env secret must be a top-level JSON object")

value = payload.get(key)
if value is None:
    if required:
        raise SystemExit(f"[deploy/vm] runtime env secret is missing required key '{key}'")
    raise SystemExit(0)

if not isinstance(value, str):
    raise SystemExit(f"[deploy/vm] runtime env secret key '{key}' must be a string")

sys.stdout.write(value)
PY
}

load_contract() {
	[[ -f "$CONFIG_FILE" ]] || deploy_fail "deploy/vm" "tracked setup env file not found: $CONFIG_FILE"
	deploy_load_env_file "$CONFIG_FILE"
	deploy_load_env_file "$LOCAL_CONFIG_FILE"
	deploy_load_image_catalog "$REPO_ROOT"

	: "${GCP_CONFIG_NAME:?GCP_CONFIG_NAME is required}"
	: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
	: "${GCP_ZONE:?GCP_ZONE is required}"
	: "${GCP_INSTANCE_NAME:?GCP_INSTANCE_NAME is required}"
	: "${VM_APP_ROOT:?VM_APP_ROOT is required}"
	: "${VM_KEEP_RELEASES:?VM_KEEP_RELEASES is required}"
	: "${VM_DOMAIN:?VM_DOMAIN is required}"
	: "${CORNERSTONE_VM_COMPOSE_PROJECT_NAME:?CORNERSTONE_VM_COMPOSE_PROJECT_NAME is required}"
	: "${CORNERSTONE_HTTP_PORT:?CORNERSTONE_HTTP_PORT is required}"
	: "${CORNERSTONE_CONTROL_PLANE_PORT:?CORNERSTONE_CONTROL_PLANE_PORT is required}"
	: "${CORNERSTONE_FRONTEND_PORT:?CORNERSTONE_FRONTEND_PORT is required}"
	: "${CORNERSTONE_POSTGRES_PORT:?CORNERSTONE_POSTGRES_PORT is required}"
	: "${CORNERSTONE_POSTGRES_DB:?CORNERSTONE_POSTGRES_DB is required}"
	: "${CORNERSTONE_POSTGRES_ADMIN_USER:?CORNERSTONE_POSTGRES_ADMIN_USER is required}"
	: "${CORNERSTONE_POSTGRES_APP_USER:?CORNERSTONE_POSTGRES_APP_USER is required}"
	: "${CORNERSTONE_RUNTIME_DATA_ROOT:?CORNERSTONE_RUNTIME_DATA_ROOT is required}"
	: "${CORNERSTONE_POSTGRES_DATA_DIR:?CORNERSTONE_POSTGRES_DATA_DIR is required}"
	: "${CORNERSTONE_ARTIFACTS_DIR:?CORNERSTONE_ARTIFACTS_DIR is required}"
	: "${CORNERSTONE_EXPORTS_DIR:?CORNERSTONE_EXPORTS_DIR is required}"
	: "${CORNERSTONE_FRONTEND_PUBLIC_URL:?CORNERSTONE_FRONTEND_PUBLIC_URL is required}"
	: "${GCP_RUNTIME_ENV_SECRET_NAME:?GCP_RUNTIME_ENV_SECRET_NAME is required}"

	GCP_BACKEND_SERVICE_NAME="${GCP_BACKEND_SERVICE_NAME:-}"
	GCP_BACKEND_TIMEOUT_SEC="${GCP_BACKEND_TIMEOUT_SEC:-}"
	GCP_ACCOUNT="${GCP_ACCOUNT:-}"

	if [[ -n "${VM_SSH_USER:-}" ]]; then
		TARGET_INSTANCE="${VM_SSH_USER}@${GCP_INSTANCE_NAME}"
	else
		TARGET_INSTANCE="$GCP_INSTANCE_NAME"
	fi
}

check_backend_timeout_contract() {
	local configured_timeout
	local current_timeout

	if [[ -z "$GCP_BACKEND_SERVICE_NAME" || -z "$GCP_BACKEND_TIMEOUT_SEC" ]]; then
		return 0
	fi

	configured_timeout="$GCP_BACKEND_TIMEOUT_SEC"
	if [[ ! "$configured_timeout" =~ ^[0-9]+$ ]]; then
		deploy_fail "deploy/vm" "GCP_BACKEND_TIMEOUT_SEC must be an integer number of seconds"
	fi

	if ! current_timeout="$("$GCLOUD_BIN" compute backend-services describe "$GCP_BACKEND_SERVICE_NAME" --global --project "$GCP_PROJECT_ID" --format='value(timeoutSec)' 2>/dev/null | tr -d '\n')"; then
		deploy_log "deploy/vm" "WARNING: could not describe backend service '$GCP_BACKEND_SERVICE_NAME'; skipping load balancer timeout verification."
		return 0
	fi

	if [[ -z "$current_timeout" ]]; then
		deploy_log "deploy/vm" "WARNING: backend service '$GCP_BACKEND_SERVICE_NAME' returned no timeoutSec; skipping load balancer timeout verification."
		return 0
	fi

	if [[ ! "$current_timeout" =~ ^[0-9]+$ ]]; then
		deploy_log "deploy/vm" "WARNING: backend service '$GCP_BACKEND_SERVICE_NAME' returned non-numeric timeoutSec '$current_timeout'; skipping load balancer timeout verification."
		return 0
	fi

	if (( current_timeout < configured_timeout )); then
		deploy_fail "deploy/vm" "backend service '$GCP_BACKEND_SERVICE_NAME' timeoutSec is '$current_timeout', expected at least '$configured_timeout'. Fix with: gcloud compute backend-services update $GCP_BACKEND_SERVICE_NAME --global --project $GCP_PROJECT_ID --timeout=$configured_timeout"
	fi
}

check_preflight() {
	local git_status

	deploy_require_cmd "deploy/vm" git
	deploy_require_cmd "deploy/vm" tar
	deploy_require_cmd "deploy/vm" python3
	deploy_require_cmd "deploy/vm" flutter

	dev_gcloud_check_context "deploy/vm"
	git_status="$(git -C "$REPO_ROOT" status --porcelain)"

	if [[ -n "$git_status" && "${DEPLOY_VM_ALLOW_DIRTY:-0}" != "1" ]]; then
		deploy_fail "deploy/vm" "working tree is dirty. Commit or stash changes before deploying, or rerun with DEPLOY_VM_ALLOW_DIRTY=1"
	fi

	if ! "$GCLOUD_BIN" compute instances describe "$GCP_INSTANCE_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" >/dev/null; then
		echo "[deploy/vm] ERROR: cannot read VM '$GCP_INSTANCE_NAME' in project '$GCP_PROJECT_ID'." >&2
		echo "[deploy/vm] If authentication expired, run: gcloud auth login ${GCP_ACCOUNT:-<account>}" >&2
		dev_gcloud_print_setup_hint "deploy/vm"
		exit 6
	fi
	check_backend_timeout_contract
	if ! "$GCLOUD_BIN" secrets describe "$GCP_RUNTIME_ENV_SECRET_NAME" --project "$GCP_PROJECT_ID" >/dev/null; then
		echo "[deploy/vm] ERROR: cannot read runtime secret '$GCP_RUNTIME_ENV_SECRET_NAME'." >&2
		echo "[deploy/vm] Create or refresh it with deploy/vm/update_gcp_runtime_env_secret.sh after fixing gcloud auth." >&2
		exit 6
	fi
}

build_frontend() {
	deploy_log "deploy/vm" "Building Flutter web app..."
	(
		cd "$REPO_ROOT/fe/flutter/apps/cornerstone" || exit 1
		flutter pub get
		flutter build web --release --pwa-strategy=none
	)
}

prepare_release_metadata() {
	local git_sha
	git_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' local)"
	RELEASE_NAME="release-$(deploy_timestamp_utc)-${git_sha}"
	RELEASE_DIR="$VM_APP_ROOT/releases/$RELEASE_NAME"
}

render_runtime_env_file() {
	local destination="$1"
	local postgres_admin_password
	local postgres_app_password
	local google_client_id
	local google_client_secret

	postgres_admin_password="$(deploy_trim "$(runtime_secret_value postgres_admin_password 1)")"
	postgres_app_password="$(deploy_trim "$(runtime_secret_value postgres_app_password 1)")"
	google_client_id="$(deploy_trim "$(runtime_secret_value google_oauth_client_id 0)")"
	google_client_secret="$(deploy_trim "$(runtime_secret_value google_oauth_client_secret 0)")"

	: > "$destination"
	deploy_write_env_line "$destination" CORNERSTONE_VM_COMPOSE_PROJECT_NAME "$CORNERSTONE_VM_COMPOSE_PROJECT_NAME"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_IMAGE "$CORNERSTONE_POSTGRES_IMAGE"
	deploy_write_env_line "$destination" CORNERSTONE_RUST_IMAGE "$CORNERSTONE_RUST_IMAGE"
	deploy_write_env_line "$destination" CORNERSTONE_RUNTIME_IMAGE "$CORNERSTONE_RUNTIME_IMAGE"
	deploy_write_env_line "$destination" CORNERSTONE_NGINX_IMAGE "$CORNERSTONE_NGINX_IMAGE"
	deploy_write_env_line "$destination" CORNERSTONE_WORKSPACE_HOST "$RELEASE_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_HTTP_PORT "$CORNERSTONE_HTTP_PORT"
	deploy_write_env_line "$destination" CORNERSTONE_CONTROL_PLANE_PORT "$CORNERSTONE_CONTROL_PLANE_PORT"
	deploy_write_env_line "$destination" CORNERSTONE_FRONTEND_PORT "$CORNERSTONE_FRONTEND_PORT"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_PORT "$CORNERSTONE_POSTGRES_PORT"
	deploy_write_env_line "$destination" CORNERSTONE_FRONTEND_PUBLIC_URL "$CORNERSTONE_FRONTEND_PUBLIC_URL"
	deploy_write_env_line "$destination" CORNERSTONE_DEVELOPER_DOCS_URL "${CORNERSTONE_DEVELOPER_DOCS_URL:-}"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_DB "$CORNERSTONE_POSTGRES_DB"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_ADMIN_USER "$CORNERSTONE_POSTGRES_ADMIN_USER"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_ADMIN_PASSWORD "$postgres_admin_password"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_APP_USER "$CORNERSTONE_POSTGRES_APP_USER"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_APP_PASSWORD "$postgres_app_password"
	deploy_write_env_line "$destination" CORNERSTONE_POSTGRES_DATA_DIR "$CORNERSTONE_POSTGRES_DATA_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_ARTIFACTS_DIR "$CORNERSTONE_ARTIFACTS_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_EXPORTS_DIR "$CORNERSTONE_EXPORTS_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_FRONTEND_BUILD_HOST "$RELEASE_DIR/fe/flutter/apps/cornerstone/build/web"
	deploy_write_env_line "$destination" CORNERSTONE_DATABASE_URL "postgres://${CORNERSTONE_POSTGRES_APP_USER}:${postgres_app_password}@postgres:5432/${CORNERSTONE_POSTGRES_DB}"
	deploy_write_env_line "$destination" CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID "$google_client_id"
	deploy_write_env_line "$destination" CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET "$google_client_secret"
	chmod 600 "$destination"
}

create_release_bundle() {
	local destination="$1"
	COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 tar -czf "$destination" \
		--exclude=.git \
		--exclude=.venv \
		--exclude='._*' \
		--exclude=scratchpad \
		--exclude=rust/target \
		--exclude=docs_site/node_modules \
		--exclude=fe/flutter/apps/cornerstone/.dart_tool \
		-C "$REPO_ROOT" .
}

print_plan() {
	cat <<EOF
[deploy/vm] Deployment plan
  instance          : $GCP_INSTANCE_NAME
  zone              : $GCP_ZONE
  project           : $GCP_PROJECT_ID
  gcloud account    : ${GCP_ACCOUNT:-<not enforced>}
  domain            : $VM_DOMAIN
  app root          : $VM_APP_ROOT
  release dir       : $RELEASE_DIR
  frontend origin   : $CORNERSTONE_FRONTEND_PUBLIC_URL
  lb backend        : ${GCP_BACKEND_SERVICE_NAME:-<not set>}
  runtime env secret: $GCP_RUNTIME_ENV_SECRET_NAME
  postgres data dir : $CORNERSTONE_POSTGRES_DATA_DIR
  artifacts dir     : $CORNERSTONE_ARTIFACTS_DIR
  exports dir       : $CORNERSTONE_EXPORTS_DIR
EOF
}

upload_and_activate_release() {
	local bundle_path="$1"
	local env_path="$2"
	local remote_bundle="/tmp/${RELEASE_NAME}.tar.gz"
	local remote_env="/tmp/${RELEASE_NAME}.env"
	local remote_command

	"$GCLOUD_BIN" compute scp --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" "$bundle_path" "${TARGET_INSTANCE}:${remote_bundle}"
	"$GCLOUD_BIN" compute scp --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" "$env_path" "${TARGET_INSTANCE}:${remote_env}"

	remote_command="$(cat <<EOF
set -euo pipefail
mkdir -p '$VM_APP_ROOT/releases'
rm -rf '$RELEASE_DIR'
mkdir -p '$RELEASE_DIR'
tar -xzf '$remote_bundle' -C '$RELEASE_DIR'
install -m 600 '$remote_env' '$RELEASE_DIR/deploy/vm/.env'
cd '$RELEASE_DIR'
bash deploy/vm/setup.sh
ln -sfn '$RELEASE_DIR' '$VM_APP_ROOT/current'
rm -f '$remote_bundle' '$remote_env'
cd '$VM_APP_ROOT/releases'
ls -1dt * 2>/dev/null | tail -n +$((VM_KEEP_RELEASES + 1)) | xargs -r rm -rf --
EOF
)"

	"$GCLOUD_BIN" compute ssh --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" "$TARGET_INSTANCE" --command "$remote_command"
}

load_contract
if [[ "$DOCTOR_ONLY" == "1" ]]; then
	dev_gcloud_check_context "deploy/vm"
	deploy_log "deploy/vm" "gcloud config, project, and account match the tracked deploy contract."
	exit 0
fi
check_preflight
prepare_release_metadata
RUNTIME_ENV_SECRET_JSON="$(fetch_runtime_env_secret)"

if [[ "$PLAN_ONLY" == "1" ]]; then
	print_plan
	exit 0
fi

build_frontend

BUNDLE_PATH="$(create_temp_file cornerstone-vm-release)"
ENV_PATH="$(create_temp_file cornerstone-vm-env)"
TEMP_FILES+=("$BUNDLE_PATH" "$ENV_PATH")

create_release_bundle "$BUNDLE_PATH"
render_runtime_env_file "$ENV_PATH"
print_plan
upload_and_activate_release "$BUNDLE_PATH" "$ENV_PATH"

deploy_log "deploy/vm" "Release activated: $RELEASE_NAME"
