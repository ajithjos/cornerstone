#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../lib.sh"

deploy_dev_init
deploy_dev_load_config
deploy_dev_check_docker_prereqs
deploy_dev_ensure_dirs

live_fe_compose_file="$DEPLOY_DEV_DIR/live_frontend/docker-compose.yml"

echo "[deploy/dev/live_frontend] Starting postgres..."
docker compose -f "$live_fe_compose_file" up -d postgres --wait --wait-timeout "$CORNERSTONE_COMPOSE_WAIT_TIMEOUT"

echo "[deploy/dev/live_frontend] Building and starting control plane..."
docker compose -f "$live_fe_compose_file" up -d --build control-plane --wait --wait-timeout "$CORNERSTONE_COMPOSE_WAIT_TIMEOUT"

echo "[deploy/dev/live_frontend] Backend stack is healthy."
echo "[deploy/dev/live_frontend] Control plane: http://127.0.0.1:${CORNERSTONE_CONTROL_PLANE_PORT}"
echo "[deploy/dev/live_frontend] Start Flutter separately, for example:"
echo "[deploy/dev/live_frontend] cd fe/flutter/apps/cornerstone && flutter run -d chrome --web-port ${CORNERSTONE_LIVE_FRONTEND_PORT} --dart-define=CORNERSTONE_API_BASE_URL=http://127.0.0.1:${CORNERSTONE_CONTROL_PLANE_PORT}"