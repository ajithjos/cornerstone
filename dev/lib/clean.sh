#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd)"
DEVKIT_SCRIPT="$REPO_ROOT/dev/devkit/lib/clean.sh"

if [[ ! -f "$DEVKIT_SCRIPT" ]]; then
	echo "Missing devkit submodule. Run: git submodule update --init dev/devkit" >&2
	exit 1
fi

has_repo_root=0
for arg in "$@"; do
	if [[ "$arg" == "--repo-root" ]]; then
		has_repo_root=1
		break
	fi
done

if ((has_repo_root)); then
	exec bash "$DEVKIT_SCRIPT" "$@"
else
	exec bash "$DEVKIT_SCRIPT" "$@" --repo-root "$REPO_ROOT"
fi
