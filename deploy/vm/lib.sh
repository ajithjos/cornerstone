#!/usr/bin/env bash

if [ -n "${ROOT_DIR:-}" ] && [ -f "$ROOT_DIR/deploy/common.sh" ]; then
	source "$ROOT_DIR/deploy/common.sh"
elif [ -n "${BASH_SOURCE[0]:-}" ]; then
	source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)/common.sh"
else
	echo "[deploy/vm] ERROR: unable to locate deploy/common.sh" >&2
	exit 1
fi

deploy_vm_init() {
	DEPLOY_VM_REPO_ROOT="$(deploy_repo_root)"
	DEPLOY_VM_DIR="$DEPLOY_VM_REPO_ROOT/deploy/vm"
	DEPLOY_VM_COMPOSE_FILE="$DEPLOY_VM_DIR/docker-compose.yml"
	DEPLOY_VM_ENV_FILE="${DEPLOY_VM_ENV_FILE:-$DEPLOY_VM_DIR/.env}"
}

deploy_vm_load_runtime_env() {
	[[ -f "$DEPLOY_VM_ENV_FILE" ]] || deploy_fail "deploy/vm" "runtime env file not found: $DEPLOY_VM_ENV_FILE"
	deploy_load_env_file "$DEPLOY_VM_ENV_FILE"
}

deploy_vm_require_runtime_env() {
	local required_vars=(
		CORNERSTONE_VM_COMPOSE_PROJECT_NAME
		CORNERSTONE_HTTP_PORT
		CORNERSTONE_POSTGRES_PORT
		CORNERSTONE_CONTROL_PLANE_PORT
		CORNERSTONE_FRONTEND_PUBLIC_URL
		CORNERSTONE_POSTGRES_DB
		CORNERSTONE_POSTGRES_ADMIN_USER
		CORNERSTONE_POSTGRES_ADMIN_PASSWORD
		CORNERSTONE_POSTGRES_APP_USER
		CORNERSTONE_POSTGRES_APP_PASSWORD
		CORNERSTONE_DATABASE_URL
		CORNERSTONE_WORKSPACE_HOST
		CORNERSTONE_FRONTEND_BUILD_HOST
		CORNERSTONE_POSTGRES_DATA_DIR
		CORNERSTONE_ARTIFACTS_DIR
		CORNERSTONE_EXPORTS_DIR
	)
	local name
	for name in "${required_vars[@]}"; do
		[[ -n "${!name:-}" ]] || deploy_fail "deploy/vm" "$name must be set in $DEPLOY_VM_ENV_FILE"
	done

	if deploy_string_is_placeholder "${CORNERSTONE_POSTGRES_ADMIN_PASSWORD:-}"; then
		deploy_fail "deploy/vm" "CORNERSTONE_POSTGRES_ADMIN_PASSWORD must be replaced with a real secret"
	fi
	if deploy_string_is_placeholder "${CORNERSTONE_POSTGRES_APP_PASSWORD:-}"; then
		deploy_fail "deploy/vm" "CORNERSTONE_POSTGRES_APP_PASSWORD must be replaced with a real secret"
	fi
}

deploy_vm_prepare_host_dirs() {
	mkdir -p \
		"$CORNERSTONE_POSTGRES_DATA_DIR" \
		"$CORNERSTONE_ARTIFACTS_DIR" \
		"$CORNERSTONE_EXPORTS_DIR"
}

deploy_vm_check_docker_prereqs() {
	deploy_check_docker_prereqs "deploy/vm"
}

deploy_vm_compose() {
	docker compose --env-file "$DEPLOY_VM_ENV_FILE" -f "$DEPLOY_VM_COMPOSE_FILE" "$@"
}
