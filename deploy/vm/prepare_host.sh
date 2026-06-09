#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../common.sh"

REPO_ROOT="$(deploy_repo_root)"
CONFIG_FILE="${DEPLOY_VM_GCP_ENV_FILE:-$REPO_ROOT/deploy/config/environments/prod.gcp.env}"
LOCAL_CONFIG_FILE="${DEPLOY_VM_LOCAL_SETUP_ENV_FILE:-$REPO_ROOT/deploy/vm/local/control/prod.gcp.env}"
GCLOUD_BIN="$(deploy_resolve_cmd "deploy/vm" GCLOUD_BIN gcloud)"

load_contract() {
	[[ -f "$CONFIG_FILE" ]] || deploy_fail "deploy/vm" "tracked setup env file not found: $CONFIG_FILE"
	deploy_load_env_file "$CONFIG_FILE"
	deploy_load_env_file "$LOCAL_CONFIG_FILE"

	: "${GCP_CONFIG_NAME:?GCP_CONFIG_NAME is required}"
	: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
	: "${GCP_ZONE:?GCP_ZONE is required}"
	: "${GCP_INSTANCE_NAME:?GCP_INSTANCE_NAME is required}"
	: "${VM_APP_ROOT:?VM_APP_ROOT is required}"
	: "${CORNERSTONE_RUNTIME_DATA_ROOT:?CORNERSTONE_RUNTIME_DATA_ROOT is required}"
	: "${CORNERSTONE_POSTGRES_DATA_DIR:?CORNERSTONE_POSTGRES_DATA_DIR is required}"
	: "${CORNERSTONE_ARTIFACTS_DIR:?CORNERSTONE_ARTIFACTS_DIR is required}"
	: "${CORNERSTONE_EXPORTS_DIR:?CORNERSTONE_EXPORTS_DIR is required}"

	if [[ -n "${VM_SSH_USER:-}" ]]; then
		TARGET_INSTANCE="${VM_SSH_USER}@${GCP_INSTANCE_NAME}"
	else
		TARGET_INSTANCE="$GCP_INSTANCE_NAME"
	fi
}

check_preflight() {
	local active_config
	local current_project

	active_config="$("$GCLOUD_BIN" config configurations list --filter=is_active:true --format='value(name)')"
	current_project="$("$GCLOUD_BIN" config get-value project 2>/dev/null | tr -d '\n')"

	[[ "$active_config" == "$GCP_CONFIG_NAME" ]] || deploy_fail "deploy/vm" "active gcloud config is '$active_config', expected '$GCP_CONFIG_NAME'"
	[[ "$current_project" == "$GCP_PROJECT_ID" ]] || deploy_fail "deploy/vm" "active gcloud project is '$current_project', expected '$GCP_PROJECT_ID'"

	"$GCLOUD_BIN" compute instances describe "$GCP_INSTANCE_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" >/dev/null
}

prepare_remote_host() {
	local remote_command
	remote_command="$(cat <<EOF
set -euo pipefail
sudo mkdir -p '$VM_APP_ROOT/releases' '$CORNERSTONE_RUNTIME_DATA_ROOT' '$CORNERSTONE_POSTGRES_DATA_DIR' '$CORNERSTONE_ARTIFACTS_DIR' '$CORNERSTONE_EXPORTS_DIR'
sudo chown -R "\$USER:\$USER" '$VM_APP_ROOT' '$CORNERSTONE_RUNTIME_DATA_ROOT'
if ! command -v docker >/dev/null 2>&1; then
  echo '[deploy/vm] WARNING: docker is not installed on the VM yet.'
fi
if ! docker compose version >/dev/null 2>&1; then
  echo '[deploy/vm] WARNING: docker compose is not available on the VM yet.'
fi
echo '[deploy/vm] Host directories prepared.'
EOF
)"

	"$GCLOUD_BIN" compute ssh --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" "$TARGET_INSTANCE" --command "$remote_command"
}

load_contract
check_preflight
prepare_remote_host
