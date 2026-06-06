#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib.sh"

mode="full"
case "${1:-}" in
	"")
		;;
	--postgres-only)
		mode="postgres-only"
		;;
	*)
		echo "Usage: $0 [--postgres-only]" >&2
		exit 2
		;;
esac

deploy_dev_init
deploy_dev_load_config
deploy_require_cmd "deploy/dev" uv
deploy_require_cmd "deploy/dev" flutter
deploy_dev_check_docker_prereqs
deploy_dev_ensure_dirs

if [[ "$mode" != "postgres-only" ]]; then
	deploy_dev_prepare_static_artifacts
fi

echo "[deploy/dev] Starting postgres..."
docker compose -f "$DEPLOY_DEV_COMPOSE_FILE" up -d postgres --wait --wait-timeout "$CORNERSTONE_COMPOSE_WAIT_TIMEOUT"

if [[ "$mode" == "postgres-only" ]]; then
	echo "[deploy/dev] Postgres is healthy."
	exit 0
fi

echo "[deploy/dev] Building and starting control plane..."
docker compose -f "$DEPLOY_DEV_COMPOSE_FILE" up -d --build control-plane --wait --wait-timeout "$CORNERSTONE_COMPOSE_WAIT_TIMEOUT"

echo "[deploy/dev] Starting frontend..."
docker compose -f "$DEPLOY_DEV_COMPOSE_FILE" up -d frontend --wait --wait-timeout "$CORNERSTONE_COMPOSE_WAIT_TIMEOUT"

echo "[deploy/dev] Stack is healthy."
echo "[deploy/dev] Frontend: http://127.0.0.1:${CORNERSTONE_FRONTEND_PORT}"
echo "[deploy/dev] Control plane: http://127.0.0.1:${CORNERSTONE_CONTROL_PLANE_PORT}"
