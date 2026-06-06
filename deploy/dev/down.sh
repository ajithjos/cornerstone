#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib.sh"

deploy_dev_init
deploy_dev_load_config
deploy_dev_check_docker_prereqs

docker compose -f "$DEPLOY_DEV_COMPOSE_FILE" down --remove-orphans
echo "[deploy/dev] Compose stack stopped."
