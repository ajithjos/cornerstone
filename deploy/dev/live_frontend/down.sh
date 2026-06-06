#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../lib.sh"

deploy_dev_init
deploy_dev_load_config
deploy_dev_check_docker_prereqs

live_fe_compose_file="$DEPLOY_DEV_DIR/live_frontend/docker-compose.yml"

docker compose -f "$live_fe_compose_file" down --remove-orphans
echo "[deploy/dev/live_frontend] Backend stack stopped."