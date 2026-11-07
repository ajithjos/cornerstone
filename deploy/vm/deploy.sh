#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../common.sh"

REPO_ROOT="$(deploy_repo_root)"
HOST_TOOL="$REPO_ROOT/deploy/host.py"
PLAN_ONLY=0
DOCTOR_ONLY=0
CONTEXT_ONLY=0
GCLOUD_SETUP_ONLY=0
TEMP_FILES=()


usage() {
	cat <<'EOF'
Usage: deploy/vm/deploy.sh [--context|--cloud-setup|--doctor|--plan]

--context       print the resolved deployment context
--cloud-setup   prepare the selected native cloud identity
--doctor        validate native cloud identity and selected host
--plan          print the resolved deployment plan without uploading anything
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
	--context)
		CONTEXT_ONLY=1
		shift
		;;
	--gcloud-setup|--cloud-setup)
		GCLOUD_SETUP_ONLY=1
		shift
		;;
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
	python3 "$HOST_TOOL" secret-read runtime_env
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
    local exports
    exports="$(python3 "$HOST_TOOL" env)" || return $?
    eval "$exports"
    deploy_load_image_catalog "$REPO_ROOT"
}

check_backend_timeout_contract() {
    python3 "$HOST_TOOL" proxy-check
}

check_preflight() {
	local git_status

	deploy_require_cmd "deploy/vm" git
	deploy_require_cmd "deploy/vm" tar
	deploy_require_cmd "deploy/vm" python3
	deploy_require_cmd "deploy/vm" flutter

	python3 "$HOST_TOOL" doctor
	git_status="$(git -C "$REPO_ROOT" status --porcelain)"

	if [[ -n "$git_status" && "${DEPLOY_VM_ALLOW_DIRTY:-0}" != "1" ]]; then
		deploy_fail "deploy/vm" "working tree is dirty. Commit or stash changes before deploying, or rerun with DEPLOY_VM_ALLOW_DIRTY=1"
	fi

    check_backend_timeout_contract
    python3 "$HOST_TOOL" secret-check runtime_env

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
    deploy_write_env_line "$destination" CORNERSTONE_HTTP_BIND "$CORNERSTONE_HTTP_BIND"
    deploy_write_env_line "$destination" CORNERSTONE_TLS_MODE "$CORNERSTONE_TLS_MODE"
    deploy_write_env_line "$destination" CORNERSTONE_TLS_DOMAIN "$VM_DOMAIN"
    deploy_write_env_line "$destination" CORNERSTONE_CADDY_IMAGE "$CORNERSTONE_CADDY_IMAGE"
    deploy_write_env_line "$destination" CORNERSTONE_CONTROL_PLANE_IMAGE "cornerstone-$(printf '%s' "$RELEASE_NAME" | tr '[:upper:]' '[:lower:]')-control-plane"
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
    deploy_write_env_line "$destination" CORNERSTONE_RUNTIME_DATA_ROOT "$CORNERSTONE_RUNTIME_DATA_ROOT"
	deploy_write_env_line "$destination" CORNERSTONE_ARTIFACTS_DIR "$CORNERSTONE_ARTIFACTS_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_EXPORTS_DIR "$CORNERSTONE_EXPORTS_DIR"
	deploy_write_env_line "$destination" CORNERSTONE_FRONTEND_BUILD_HOST "$RELEASE_DIR/fe/flutter/apps/cornerstone/build/web"
	deploy_write_env_line "$destination" CORNERSTONE_DATABASE_URL "postgres://${CORNERSTONE_POSTGRES_APP_USER}:${postgres_app_password}@postgres:5432/${CORNERSTONE_POSTGRES_DB}"
	deploy_write_env_line "$destination" CORNERSTONE_GOOGLE_OAUTH_CLIENT_ID "$google_client_id"
	deploy_write_env_line "$destination" CORNERSTONE_GOOGLE_OAUTH_CLIENT_SECRET "$google_client_secret"
	chmod 600 "$destination"
}

create_release_bundle() {
    rm -f -- "$1"
    python3 "$REPO_ROOT/deploy/package_release.py" --destination "$1"
}

print_plan() {
    cat <<EOF
[deploy/vm] Deployment plan
  provider          : $DEPLOY_PROVIDER
  target            : $DEPLOY_TARGET_ID
  native profile    : $DEPLOY_CONNECTION_PROFILE
  account scope     : $DEPLOY_ACCOUNT_SCOPE
  transport         : $VM_TRANSPORT
  domain            : $VM_DOMAIN
  release dir       : $RELEASE_DIR
  frontend origin   : $CORNERSTONE_FRONTEND_PUBLIC_URL
  credential source : $DEPLOY_SECRET_SOURCE
  postgres data dir : $CORNERSTONE_POSTGRES_DATA_DIR
  artifacts dir     : $CORNERSTONE_ARTIFACTS_DIR
  exports dir       : $CORNERSTONE_EXPORTS_DIR
EOF
}

confirm_deploy() {
	local confirmation
	local phrase="DEPLOY-CORNERSTONE-VM"

	echo
	printf "Type %s to continue: " "$phrase"
	IFS= read -r confirmation
	echo
	if [[ "$confirmation" != "$phrase" ]]; then
		deploy_fail "deploy/vm" "deployment aborted"
	fi
}

upload_and_activate_release() {
	local bundle_path="$1"
	local env_path="$2"
	local remote_dir
    remote_dir="$(python3 "$HOST_TOOL" run 'umask 077; mktemp -d /tmp/cornerstone-deploy.XXXXXXXXXXXX')"
    [[ "$remote_dir" =~ ^/tmp/cornerstone-deploy\.[A-Za-z0-9]{12}$ ]] || deploy_fail deploy/vm "unsafe transfer directory"
    local remote_bundle="$remote_dir/release.tar.gz"
    local remote_env="$remote_dir/runtime.env"
	local remote_command

	python3 "$HOST_TOOL" put "$bundle_path" "$remote_bundle"
	python3 "$HOST_TOOL" put "$env_path" "$remote_env"

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
rm -rf -- '$remote_dir'
cd '$VM_APP_ROOT/releases'
# Release names carry their UTC creation order. Extracted directory mtimes come
# from the source archive and cannot safely identify the newest deployment.
find . -mindepth 1 -maxdepth 1 -type d -name 'release-*' -printf '%f\n' \
  | sort -r \
  | tail -n +$((VM_KEEP_RELEASES + 1)) \
  | xargs -r rm -rf --
EOF
)"

	python3 "$HOST_TOOL" run "sudo -n bash -c $(printf '%q' "$remote_command")"
}

load_contract
if [[ "$CONTEXT_ONLY" == "1" ]]; then
	prepare_release_metadata
	print_plan
	echo
	python3 "$HOST_TOOL" context
	exit 0
fi
if [[ "$GCLOUD_SETUP_ONLY" == "1" ]]; then
	python3 "$HOST_TOOL" setup
	exit 0
fi
if [[ "$DOCTOR_ONLY" == "1" ]]; then
	python3 "$HOST_TOOL" doctor
	deploy_log "deploy/vm" "native cloud identity and selected host match the deployment target."
	exit 0
fi
check_preflight
prepare_release_metadata
RUNTIME_ENV_SECRET_JSON="$(fetch_runtime_env_secret)"

if [[ "$PLAN_ONLY" == "1" ]]; then
	print_plan
	exit 0
fi

print_plan
confirm_deploy
build_frontend

BUNDLE_PATH="$(create_temp_file cornerstone-vm-release)"
ENV_PATH="$(create_temp_file cornerstone-vm-env)"
TEMP_FILES+=("$BUNDLE_PATH" "$ENV_PATH")

create_release_bundle "$BUNDLE_PATH"
render_runtime_env_file "$ENV_PATH"
upload_and_activate_release "$BUNDLE_PATH" "$ENV_PATH"

deploy_log "deploy/vm" "Release activated: $RELEASE_NAME"
