#!/usr/bin/env bash

if [ -n "${ROOT_DIR:-}" ] && [ -f "$ROOT_DIR/deploy/common.sh" ]; then
	source "$ROOT_DIR/deploy/common.sh"
elif [ -n "${BASH_SOURCE[0]:-}" ]; then
	source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)/common.sh"
else
	echo "[deploy/dev] ERROR: unable to locate deploy/common.sh" >&2
	exit 1
fi

deploy_dev_resolve_tokens() {
	local value="$1"
	value="${value//__CORNERSTONE_DEV_LOCAL_ROOT__/$CORNERSTONE_DEV_LOCAL_ROOT}"
	value="${value//__CORNERSTONE_DEV_DATA_REVISION__/$CORNERSTONE_DEV_DATA_REVISION}"
	printf '%s' "$(deploy_resolve_path "$DEPLOY_DEV_REPO_ROOT" "$value")"
}

deploy_dev_init() {
	DEPLOY_DEV_REPO_ROOT="$(deploy_repo_root)"
	DEPLOY_DEV_DIR="$DEPLOY_DEV_REPO_ROOT/deploy/dev"
	DEPLOY_DEV_COMPOSE_FILE="$DEPLOY_DEV_DIR/docker-compose.yml"
	DEPLOY_DEV_LOCAL_DIR="${DEPLOY_DEV_LOCAL_DIR:-}"
	DEPLOY_DEV_CONTROL_DIR="${DEPLOY_DEV_CONTROL_DIR:-}"
	DEPLOY_DEV_SECRETS_DIR="${DEPLOY_DEV_SECRETS_DIR:-}"
	DEPLOY_DEV_SETUP_ENV_FILE="${DEPLOY_DEV_SETUP_ENV_FILE:-$DEPLOY_DEV_REPO_ROOT/deploy/config/environments/dev.env}"
	DEPLOY_DEV_LOCAL_SETUP_ENV_FILE="${DEPLOY_DEV_LOCAL_SETUP_ENV_FILE:-}"
	DEPLOY_DEV_RUNTIME_ENV_FILE="${DEPLOY_DEV_RUNTIME_ENV_FILE:-}"
	deploy_load_image_catalog "$DEPLOY_DEV_REPO_ROOT"
}

deploy_dev_load_config() {
	[[ -f "$DEPLOY_DEV_SETUP_ENV_FILE" ]] || deploy_fail "deploy/dev" "setup env file not found: $DEPLOY_DEV_SETUP_ENV_FILE"

	setup_env_get() {
		deploy_env_merged_get "$1" "$DEPLOY_DEV_SETUP_ENV_FILE" "$DEPLOY_DEV_LOCAL_SETUP_ENV_FILE"
	}

	if [[ -z "$DEPLOY_DEV_LOCAL_DIR" ]]; then
		DEPLOY_DEV_LOCAL_DIR="$(deploy_resolve_path "$DEPLOY_DEV_REPO_ROOT" "$(deploy_trim "$(setup_env_get CORNERSTONE_DEV_LOCAL_ROOT)")")"
	fi
	if [[ -z "$DEPLOY_DEV_LOCAL_DIR" ]]; then
		DEPLOY_DEV_LOCAL_DIR="$DEPLOY_DEV_REPO_ROOT/scratchpad/dev/local"
	fi
	DEPLOY_DEV_CONTROL_DIR="${DEPLOY_DEV_CONTROL_DIR:-$DEPLOY_DEV_LOCAL_DIR/control}"
	DEPLOY_DEV_SECRETS_DIR="${DEPLOY_DEV_SECRETS_DIR:-$DEPLOY_DEV_LOCAL_DIR/secrets}"
	DEPLOY_DEV_LOCAL_SETUP_ENV_FILE="${DEPLOY_DEV_LOCAL_SETUP_ENV_FILE:-$DEPLOY_DEV_CONTROL_DIR/dev.env}"
	DEPLOY_DEV_RUNTIME_ENV_FILE="${DEPLOY_DEV_RUNTIME_ENV_FILE:-$DEPLOY_DEV_SECRETS_DIR/runtime-env.json}"

	[[ -f "$DEPLOY_DEV_RUNTIME_ENV_FILE" ]] || deploy_fail "deploy/dev" "runtime env secret file not found: $DEPLOY_DEV_RUNTIME_ENV_FILE. Copy $DEPLOY_DEV_REPO_ROOT/deploy/templates/secrets/runtime-env.example.json to that path and edit it"

	export CORNERSTONE_DEV_COMPOSE_PROJECT_NAME="$(deploy_trim "$(setup_env_get CORNERSTONE_DEV_COMPOSE_PROJECT_NAME)")"
	export CORNERSTONE_DEV_LIVE_FE_COMPOSE_PROJECT_NAME="$(deploy_trim "$(setup_env_get CORNERSTONE_DEV_LIVE_FE_COMPOSE_PROJECT_NAME)")"
	export CORNERSTONE_DEV_LOCAL_ROOT="$(deploy_trim "$(setup_env_get CORNERSTONE_DEV_LOCAL_ROOT)")"
	export CORNERSTONE_DEV_DATA_REVISION="$(deploy_trim "$(setup_env_get CORNERSTONE_DEV_DATA_REVISION)")"
	export CORNERSTONE_WORKSPACE_HOST="$(deploy_trim "$(setup_env_get CORNERSTONE_WORKSPACE_HOST)")"
	export CORNERSTONE_POSTGRES_PORT="$(deploy_trim "$(setup_env_get CORNERSTONE_POSTGRES_PORT)")"
	export CORNERSTONE_CONTROL_PLANE_PORT="$(deploy_trim "$(setup_env_get CORNERSTONE_CONTROL_PLANE_PORT)")"
	export CORNERSTONE_FRONTEND_PORT="$(deploy_trim "$(setup_env_get CORNERSTONE_FRONTEND_PORT)")"
	export CORNERSTONE_LIVE_FRONTEND_PORT="$(deploy_trim "$(setup_env_get CORNERSTONE_LIVE_FRONTEND_PORT)")"
	export CORNERSTONE_DOCS_SITE_PORT="$(deploy_trim "$(setup_env_get CORNERSTONE_DOCS_SITE_PORT)")"
	export CORNERSTONE_COMPOSE_WAIT_TIMEOUT="$(deploy_trim "$(setup_env_get CORNERSTONE_COMPOSE_WAIT_TIMEOUT)")"
	export CORNERSTONE_POSTGRES_DB="$(deploy_trim "$(setup_env_get CORNERSTONE_POSTGRES_DB)")"
	export CORNERSTONE_POSTGRES_ADMIN_USER="$(deploy_trim "$(setup_env_get CORNERSTONE_POSTGRES_ADMIN_USER)")"
	export CORNERSTONE_POSTGRES_APP_USER="$(deploy_trim "$(setup_env_get CORNERSTONE_POSTGRES_APP_USER)")"
	export CORNERSTONE_FRONTEND_PUBLIC_URL="$(deploy_trim "$(setup_env_get CORNERSTONE_FRONTEND_PUBLIC_URL)")"
	export CORNERSTONE_DEVELOPER_DOCS_URL="$(deploy_trim "$(setup_env_get CORNERSTONE_DEVELOPER_DOCS_URL)")"
	export CORNERSTONE_POSTGRES_ADMIN_PASSWORD="$(deploy_trim "$(deploy_runtime_env_json_value "$DEPLOY_DEV_RUNTIME_ENV_FILE" postgres_admin_password 1)")"
	export CORNERSTONE_POSTGRES_APP_PASSWORD="$(deploy_trim "$(deploy_runtime_env_json_value "$DEPLOY_DEV_RUNTIME_ENV_FILE" postgres_app_password 1)")"
	export CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID="$(deploy_trim "$(deploy_runtime_env_json_value "$DEPLOY_DEV_RUNTIME_ENV_FILE" google_oauth_client_id 0)")"
	export CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET="$(deploy_trim "$(deploy_runtime_env_json_value "$DEPLOY_DEV_RUNTIME_ENV_FILE" google_oauth_client_secret 0)")"

	CORNERSTONE_DEV_LOCAL_ROOT="$(deploy_dev_resolve_tokens "$CORNERSTONE_DEV_LOCAL_ROOT")"
	CORNERSTONE_WORKSPACE_HOST="$(deploy_dev_resolve_tokens "$CORNERSTONE_WORKSPACE_HOST")"
	CORNERSTONE_POSTGRES_DATA_HOST="$(deploy_dev_resolve_tokens "$(setup_env_get CORNERSTONE_POSTGRES_DATA_HOST)")"
	CORNERSTONE_ARTIFACTS_HOST="$(deploy_dev_resolve_tokens "$(setup_env_get CORNERSTONE_ARTIFACTS_HOST)")"
	CORNERSTONE_EXPORTS_HOST="$(deploy_dev_resolve_tokens "$(setup_env_get CORNERSTONE_EXPORTS_HOST)")"
	CORNERSTONE_FRONTEND_BUILD_HOST="$DEPLOY_DEV_REPO_ROOT/fe/flutter/apps/cornerstone/build/web"
	CORNERSTONE_DATABASE_URL="postgres://${CORNERSTONE_POSTGRES_APP_USER}:${CORNERSTONE_POSTGRES_APP_PASSWORD}@postgres:5432/${CORNERSTONE_POSTGRES_DB}"
	CORNERSTONE_HOST_DATABASE_URL="postgres://${CORNERSTONE_POSTGRES_APP_USER}:${CORNERSTONE_POSTGRES_APP_PASSWORD}@127.0.0.1:${CORNERSTONE_POSTGRES_PORT}/${CORNERSTONE_POSTGRES_DB}"

	export CORNERSTONE_DEV_COMPOSE_PROJECT_NAME
	export CORNERSTONE_DEV_LIVE_FE_COMPOSE_PROJECT_NAME
	export CORNERSTONE_DEV_LOCAL_ROOT
	export CORNERSTONE_DEV_DATA_REVISION
	export CORNERSTONE_WORKSPACE_HOST
	export CORNERSTONE_POSTGRES_PORT
	export CORNERSTONE_CONTROL_PLANE_PORT
	export CORNERSTONE_FRONTEND_PORT
	export CORNERSTONE_LIVE_FRONTEND_PORT
	export CORNERSTONE_DOCS_SITE_PORT
	export CORNERSTONE_COMPOSE_WAIT_TIMEOUT
	export CORNERSTONE_POSTGRES_DB
	export CORNERSTONE_POSTGRES_ADMIN_USER
	export CORNERSTONE_POSTGRES_ADMIN_PASSWORD
	export CORNERSTONE_POSTGRES_APP_USER
	export CORNERSTONE_POSTGRES_APP_PASSWORD
	export CORNERSTONE_POSTGRES_DATA_HOST
	export CORNERSTONE_ARTIFACTS_HOST
	export CORNERSTONE_EXPORTS_HOST
	export CORNERSTONE_FRONTEND_BUILD_HOST
	export CORNERSTONE_DATABASE_URL
	export CORNERSTONE_HOST_DATABASE_URL
	export CORNERSTONE_FRONTEND_PUBLIC_URL
	export CORNERSTONE_DEVELOPER_DOCS_URL
	export CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID
	export CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET
	export CORNERSTONE_POSTGRES_IMAGE
	export CORNERSTONE_RUST_IMAGE
	export CORNERSTONE_RUNTIME_IMAGE
	export CORNERSTONE_NGINX_IMAGE
}

deploy_dev_ensure_dirs() {
	mkdir -p \
		"$DEPLOY_DEV_CONTROL_DIR" \
		"$DEPLOY_DEV_SECRETS_DIR" \
		"$CORNERSTONE_POSTGRES_DATA_HOST" \
		"$CORNERSTONE_ARTIFACTS_HOST" \
		"$CORNERSTONE_EXPORTS_HOST"
}

deploy_dev_prepare_static_artifacts() {
	echo "[deploy/dev] Building Flutter web app..."
	(
		cd "$DEPLOY_DEV_REPO_ROOT/fe/flutter/apps/cornerstone" || exit 1
		flutter pub get
		flutter build web --release --pwa-strategy=none
	)
}

deploy_dev_check_docker_prereqs() {
	deploy_check_docker_prereqs "deploy/dev"
}
