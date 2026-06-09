# VM Deploy Runbook

## Goal

Cornerstone’s hosted deploy now follows the same shape as the CRM repository:

- tracked non-secret setup in `deploy/config/environments/prod.gcp.env`
- local secret input in `deploy/vm/local/secrets/runtime-env.json`
- hosted runtime secret in GCP Secret Manager
- repeated deploy through `deploy/vm/deploy.sh`

Use `gcp-vm-first-deploy.md` for the one-time VM, load-balancer, OAuth, and DNS setup. This runbook is for the repeatable deploy path after that hosted shape exists.

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
export GCLOUD_BIN=/absolute/path/to/gcloud # only when gcloud is not on PATH
make vm-setup
make vm-runtime-secret-push
```

## Repeated Deploy

Review the resolved deploy plan first:

```bash
export GCLOUD_BIN=/absolute/path/to/gcloud # only when gcloud is not on PATH
make vm-deploy-plan
```

When the plan looks correct:

```bash
export GCLOUD_BIN=/absolute/path/to/gcloud # only when gcloud is not on PATH
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
- The VM scripts honor `GCLOUD_BIN` when your local `gcloud` binary lives outside the normal shell `PATH`.
- If the public DNS zone is managed outside this GCP project, the DNS `A` record still needs to be updated there before the managed certificate can become active.
- If the DNS zone is on Cloudflare, keep the record `DNS only` until the Google-managed certificate is `ACTIVE`. A proxied record resolves to Cloudflare IPs instead of the load-balancer IP and can block certificate provisioning.
- If you need machine-specific non-secret overrides on your laptop, put them in `deploy/vm/local/control/prod.gcp.env`.
- The older files under `deploy/production/templates/` are only compatibility references now.
