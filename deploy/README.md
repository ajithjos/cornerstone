# Deploy Layout

Cornerstone uses the same deployment split in both dev and the VM flow:

- tracked non-secret setup env in `deploy/config/environments/`
- local machine secret JSON in `deploy/dev/local/secrets/` or `deploy/vm/local/secrets/`
- tracked runtime defaults in `deploy/config/runtime_defaults/`

Primary entrypoints:

- one-time VM host prep: `bash deploy/vm/prepare_host.sh`
- local compose: `bash deploy/dev/setup.sh`
- local live frontend mode: `bash deploy/dev/live_frontend/up.sh`
- publish hosted runtime secret: `bash deploy/vm/update_gcp_runtime_env_secret.sh`
- hosted deploy plan: `bash deploy/vm/deploy.sh --plan`
- hosted deploy: `bash deploy/vm/deploy.sh`
