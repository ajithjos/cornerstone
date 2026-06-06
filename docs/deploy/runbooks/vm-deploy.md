# VM Deploy Runbook

## Goal

Cornerstone’s hosted deploy now follows the same shape as the CRM repository:

- tracked non-secret setup in `deploy/config/environments/prod.gcp.env`
- local secret input in `deploy/vm/local/secrets/runtime-env.json`
- hosted runtime secret in GCP Secret Manager
- repeated deploy through `deploy/vm/deploy.sh`

## One-Time Setup

1. Fill `deploy/config/environments/prod.gcp.env` with the VM, domain, GCP project, and non-secret runtime paths.
2. Create the local secret input:

```bash
mkdir -p deploy/vm/local/secrets deploy/vm/local/control
cp deploy/templates/secrets/runtime-env.example.json deploy/vm/local/secrets/runtime-env.json
```

3. Edit `deploy/vm/local/secrets/runtime-env.json` with the real Postgres passwords and Google OAuth client values.
4. Publish the secret bundle:

```bash
make vm-setup
make vm-runtime-secret-push
```

## Repeated Deploy

Review the resolved deploy plan first:

```bash
make vm-deploy-plan
```

When the plan looks correct:

```bash
make vm-deploy
```

What the deploy script does:

1. validates the local gcloud config and the target VM
2. builds the Flutter web frontend locally
3. fetches the hosted runtime secret JSON from Secret Manager
4. renders a VM-local `deploy/vm/.env` file for that release
5. uploads the repo bundle to the VM
6. runs `deploy/vm/setup.sh` on the VM to start the Docker stack

## Notes

- Real secrets do not belong in tracked files, including `prod.gcp.env`.
- If you need machine-specific non-secret overrides on your laptop, put them in `deploy/vm/local/control/prod.gcp.env`.
- The older files under `deploy/production/templates/` are only compatibility references now.
