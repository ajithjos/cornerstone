# Production Flow

Cornerstone now follows the same high-level split as the CRM repository:

- tracked non-secret setup env in `deploy/config/environments/prod.gcp.env`
- machine-local secret input in `deploy/vm/local/secrets/runtime-env.json`
- hosted runtime secret payload in GCP Secret Manager under `GCP_RUNTIME_ENV_SECRET_NAME`
- repeated VM deploy entrypoint in `deploy/vm/deploy.sh`

## Active Files

- tracked setup env: `deploy/config/environments/prod.gcp.env`
- local secret input: `deploy/vm/local/secrets/runtime-env.json`
- local secret publisher: `deploy/vm/update_gcp_runtime_env_secret.sh`
- repeated deploy: `deploy/vm/deploy.sh`
- on-host compose runner: `deploy/vm/setup.sh`

## Practical Workflow

For the very first rollout, use `docs/deploy/runbooks/gcp-vm-first-deploy.md` together with this file.

1. Fill `deploy/config/environments/prod.gcp.env` with non-secret GCP and VM values.
2. Copy `deploy/templates/secrets/runtime-env.example.json` to `deploy/vm/local/secrets/runtime-env.json` and fill the real secrets.
3. Prepare the target VM directories once with `make deploy-setup`.
4. Publish that JSON to Secret Manager with `make deploy-secret-push`.
5. Review the resolved plan with `make deploy-plan`.
6. Deploy with `make deploy`.

The older files under `deploy/production/templates/` now exist only as compatibility references for the same contract.
