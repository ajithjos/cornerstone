#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib.sh"

deploy_vm_init
deploy_vm_load_runtime_env
deploy_vm_require_runtime_env
deploy_vm_check_docker_prereqs
deploy_vm_prepare_host_dirs

if [[ "${1:-}" == "--skip-build" ]]; then
    deploy_vm_compose up -d --wait postgres control-plane frontend
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--skip-build]" >&2
    exit 2
else
    deploy_vm_compose up -d --build --wait postgres control-plane frontend
fi
if [[ "${CORNERSTONE_TLS_MODE:-external}" == "direct" ]]; then
    mkdir -p "$CORNERSTONE_RUNTIME_DATA_ROOT/tls/data" "$CORNERSTONE_RUNTIME_DATA_ROOT/tls/config"
    chown -R 10001:10001 "$CORNERSTONE_RUNTIME_DATA_ROOT/tls"
    deploy_vm_compose --profile https up -d https
fi
echo "[deploy/vm] Compose stack is healthy."
