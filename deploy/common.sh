#!/usr/bin/env bash

set -euo pipefail

if [ -n "${ROOT_DIR:-}" ] && [ -d "$ROOT_DIR/deploy" ]; then
	DEPLOY_COMMON_REPO_ROOT="$ROOT_DIR"
elif [ -n "${BASH_SOURCE[0]:-}" ]; then
	DEPLOY_COMMON_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
else
	DEPLOY_COMMON_REPO_ROOT="$(pwd)"
fi

deploy_repo_root() {
	printf '%s\n' "$DEPLOY_COMMON_REPO_ROOT"
}

deploy_log() {
	local scope="$1"
	shift
	printf '[%s] %s\n' "$scope" "$*" >&2
}

deploy_fail() {
	local scope="$1"
	shift
	deploy_log "$scope" "ERROR: $*"
	exit 1
}

deploy_require_cmd() {
	local scope="$1"
	local cmd="$2"
	command -v "$cmd" >/dev/null 2>&1 || deploy_fail "$scope" "required command not found: $cmd"
}

deploy_resolve_cmd() {
	local scope="$1"
	local env_var_name="$2"
	local fallback_cmd="$3"
	local configured_path="${!env_var_name:-}"

	if [[ -n "$configured_path" ]]; then
		[[ -x "$configured_path" ]] || deploy_fail "$scope" "$env_var_name is set but not executable: $configured_path"
		printf '%s\n' "$configured_path"
		return 0
	fi

	deploy_require_cmd "$scope" "$fallback_cmd"
	command -v "$fallback_cmd"
}

deploy_check_docker_prereqs() {
	local scope="$1"
	deploy_require_cmd "$scope" docker
	docker compose version >/dev/null 2>&1 || deploy_fail "$scope" "docker compose is required"
	docker info >/dev/null 2>&1 || deploy_fail "$scope" "docker daemon is not reachable"
}

deploy_load_env_file() {
	local env_file="$1"
	[[ -f "$env_file" ]] || return 0
	set -a
	# shellcheck disable=SC1090
	source "$env_file"
	set +a
}

deploy_load_image_catalog() {
	local repo_root="$1"
	local image_catalog="$repo_root/deploy/config/build/images.lock.env"
	[[ -f "$image_catalog" ]] || deploy_fail "deploy" "image catalog not found: $image_catalog"
	deploy_load_env_file "$image_catalog"
}

deploy_trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

deploy_env_file_has_key() {
	local env_file="$1"
	local key="$2"
	[[ -f "$env_file" ]] || return 1
	python3 - "$env_file" "$key" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith(f"{key}="):
        raise SystemExit(0)
raise SystemExit(1)
PY
}

deploy_env_file_get() {
	local env_file="$1"
	local key="$2"
	[[ -f "$env_file" ]] || {
		printf ''
		return 0
	}
	python3 - "$env_file" "$key" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith(f"{key}="):
        print(line.split("=", 1)[1], end="")
        raise SystemExit(0)
print("", end="")
PY
}

deploy_env_merged_get() {
	local key="$1"
	shift
	local files=("$@")
	local index
	for (( index=${#files[@]}-1; index>=0; index-- )); do
		if deploy_env_file_has_key "${files[$index]}" "$key"; then
			deploy_env_file_get "${files[$index]}" "$key"
			return 0
		fi
	done
	printf ''
}

deploy_runtime_env_json_value() {
	local source_file="$1"
	local key="$2"
	local required="${3:-1}"
	RUNTIME_ENV_SOURCE_FILE="$source_file" python3 - "$key" "$required" <<'PY'
import json
import os
import pathlib
import sys

source_file = pathlib.Path(os.environ["RUNTIME_ENV_SOURCE_FILE"])
key = sys.argv[1]
required = sys.argv[2] == "1"

if not source_file.is_file():
    if required:
        raise SystemExit(f"runtime env secret file not found: {source_file}")
    raise SystemExit(0)

try:
    payload = json.loads(source_file.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    raise SystemExit(f"runtime env secret file is not valid JSON: {exc}") from exc

if not isinstance(payload, dict):
    raise SystemExit("runtime env secret file must be a top-level JSON object")

value = payload.get(key)
if value is None:
    if required:
        raise SystemExit(f"runtime env secret file is missing required key '{key}'")
    raise SystemExit(0)

if not isinstance(value, str):
    raise SystemExit(f"runtime env secret key '{key}' must be a string")

sys.stdout.write(value)
PY
}

deploy_resolve_path() {
	local repo_root="$1"
	local raw_path="${2:-}"
	local expanded_path="$raw_path"

	expanded_path="${expanded_path//__REPO_ROOT__/$repo_root}"
	expanded_path="${expanded_path//__HOME__/$HOME}"

	if [[ -z "$expanded_path" ]]; then
		printf '%s\n' ""
		return 0
	fi

	if [[ "$expanded_path" = /* ]]; then
		printf '%s\n' "$expanded_path"
		return 0
	fi

	printf '%s/%s\n' "$repo_root" "$expanded_path"
}

deploy_string_is_placeholder() {
	local value
	value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	case "$value" in
		""|replace-me*|replace_me*|change-me*|changeme*|example*|todo*|set-me*|your-*|placeholder*)
			return 0
			;;
	esac
	return 1
}

deploy_quote_env_value() {
	printf '%s' "$1" | sed "s/'/'\\''/g; 1s/^/'/; \$s/\$/'/"
}

deploy_write_env_line() {
	local destination="$1"
	local key="$2"
	local value="${3:-}"
	printf '%s=%s\n' "$key" "$(deploy_quote_env_value "$value")" >> "$destination"
}

deploy_timestamp_utc() {
	date -u +%Y%m%dT%H%M%SZ
}
