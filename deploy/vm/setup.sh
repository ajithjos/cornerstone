#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/lib.sh"

deploy_vm_init
deploy_vm_load_runtime_env
deploy_vm_require_runtime_env
deploy_vm_check_docker_prereqs
deploy_vm_prepare_host_dirs

deploy_vm_compose up -d --build --wait
echo "[deploy/vm] Compose stack is healthy."
