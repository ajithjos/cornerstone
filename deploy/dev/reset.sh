#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib.sh"

deploy_dev_init
deploy_dev_load_config
deploy_dev_check_docker_prereqs

echo "WARNING: this will stop the Cornerstone compose stack and delete local Postgres data under $CORNERSTONE_POSTGRES_DATA_HOST."
printf "Type RESET-CORNERSTONE to continue: "
IFS= read -r confirmation
echo

if [[ "$confirmation" != "RESET-CORNERSTONE" ]]; then
	echo "Aborted."
	exit 1
fi

docker compose -f "$DEPLOY_DEV_COMPOSE_FILE" down --remove-orphans

[[ -n "$CORNERSTONE_POSTGRES_DATA_HOST" && "$CORNERSTONE_POSTGRES_DATA_HOST" != "/" ]] || {
	echo "[deploy/dev] ERROR: refusing to delete invalid Postgres path '$CORNERSTONE_POSTGRES_DATA_HOST'" >&2
	exit 2
}

mkdir -p "$CORNERSTONE_POSTGRES_DATA_HOST"
find "$CORNERSTONE_POSTGRES_DATA_HOST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
echo "[deploy/dev] Postgres data deleted. Artifact and export directories were left intact."
