# GCP VM First Deploy

This runbook records the first hosted Cornerstone rollout completed on 2026-06-09 and the exact one-time infrastructure shape now expected by the repo.

After this first-time setup is in place, use [vm-deploy.md](vm-deploy.md) for normal redeploys.

## Target Shape

Use this hosted shape:

- one GCP project: `p601-ephphatha-host`
- one Ubuntu VM: `cornerstone-prod-vm`
- one GCP external HTTPS load balancer in front of the VM
- one Google-managed certificate for `cornerstone.dhenara.com`
- one Secret Manager runtime env secret: `cornerstone-runtime-env`
- one CLI-managed OAuth client for hosted owner sign-in

Keep TLS at the load balancer. Keep the VM gateway on plain HTTP port `80` behind that load balancer.

## Current Hosted Values

These are the current production values in this repo and project:

- local gcloud config: `cornerstone-prod`
- project: `p601-ephphatha-host`
- zone: `us-central1-f`
- VM: `cornerstone-prod-vm`
- VM app root: `/opt/cornerstone`
- runtime data root: `/var/lib/cornerstone`
- public domain: `cornerstone.dhenara.com`
- current reserved load-balancer IP: `8.233.205.67`

Load-balancer resources created in the first rollout:

- address: `cornerstone-prod-ip`
- certificate: `cornerstone-prod-cert`
- instance group: `cornerstone-prod-ig`
- VM tag: `allow-cornerstone-lb`
- firewall rule: `cornerstone-prod-allow-lb`
- health check: `cornerstone-prod-hc`
- backend service: `cornerstone-prod-backend`
- URL map: `cornerstone-prod-url-map`
- target HTTPS proxy: `cornerstone-prod-https-proxy`
- forwarding rule: `cornerstone-prod-https-fr`

Hosted OAuth resources created in the first rollout:

- OAuth client: `cornerstone-web`
- OAuth credential: `cornerstone-web-cred`

## 1. Local Tooling

Install these locally before the first deploy:

- `gcloud`
- `flutter`
- `git`
- `tar`
- `python3`

If `gcloud` is installed outside your normal non-interactive shell `PATH`, export `GCLOUD_BIN` to the full binary path before using the VM scripts:

```bash
export GCLOUD_BIN=/absolute/path/to/gcloud
```

The VM scripts now honor `GCLOUD_BIN` directly.

## 2. Select The Gcloud Config

Create or activate the dedicated Cornerstone config:

```bash
$GCLOUD_BIN auth login
$GCLOUD_BIN config configurations create cornerstone-prod
$GCLOUD_BIN config configurations activate cornerstone-prod
$GCLOUD_BIN config set project p601-ephphatha-host
$GCLOUD_BIN config set compute/zone us-central1-f
```

If the config already exists, just activate it and confirm the project and zone.

## 3. Create The VM

Create one Ubuntu VM with these minimum settings:

- machine type: `e2-standard-2`
- image: Ubuntu `24.04 LTS`
- boot disk: `50 GB` balanced persistent disk
- network: default
- firewall: SSH only at creation time

Equivalent command:

```bash
$GCLOUD_BIN compute instances create cornerstone-prod-vm \
  --project p601-ephphatha-host \
  --zone us-central1-f \
  --machine-type e2-standard-2 \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 50GB \
  --boot-disk-type pd-balanced \
  --network-interface subnet=default,network-tier=PREMIUM
```

## 4. Install Docker On The VM

Install Docker and Compose on the VM once:

```bash
$GCLOUD_BIN compute ssh cornerstone-prod-vm \
  --project p601-ephphatha-host \
  --zone us-central1-f \
  --command 'set -euo pipefail; curl -fsSL https://get.docker.com | sh; sudo usermod -aG docker "$USER"; docker --version; docker compose version'
```

## 5. Create The Load Balancer

Run the one-time load-balancer setup:

```bash
$GCLOUD_BIN compute addresses create cornerstone-prod-ip \
  --global \
  --project p601-ephphatha-host

$GCLOUD_BIN compute ssl-certificates create cornerstone-prod-cert \
  --domains=cornerstone.dhenara.com \
  --global \
  --project p601-ephphatha-host

$GCLOUD_BIN compute instance-groups unmanaged create cornerstone-prod-ig \
  --zone us-central1-f \
  --project p601-ephphatha-host

$GCLOUD_BIN compute instance-groups unmanaged add-instances cornerstone-prod-ig \
  --instances cornerstone-prod-vm \
  --zone us-central1-f \
  --project p601-ephphatha-host

$GCLOUD_BIN compute instance-groups set-named-ports cornerstone-prod-ig \
  --named-ports=http:80 \
  --zone us-central1-f \
  --project p601-ephphatha-host

$GCLOUD_BIN compute instances add-tags cornerstone-prod-vm \
  --tags allow-cornerstone-lb \
  --zone us-central1-f \
  --project p601-ephphatha-host

$GCLOUD_BIN compute firewall-rules create cornerstone-prod-allow-lb \
  --allow tcp:80 \
  --direction INGRESS \
  --network default \
  --source-ranges 35.191.0.0/16,130.211.0.0/22 \
  --target-tags allow-cornerstone-lb \
  --project p601-ephphatha-host

$GCLOUD_BIN compute health-checks create http cornerstone-prod-hc \
  --global \
  --port 80 \
  --request-path / \
  --check-interval 30s \
  --timeout 5s \
  --healthy-threshold 2 \
  --unhealthy-threshold 2 \
  --project p601-ephphatha-host

$GCLOUD_BIN compute backend-services create cornerstone-prod-backend \
  --global \
  --load-balancing-scheme EXTERNAL_MANAGED \
  --protocol HTTP \
  --port-name http \
  --health-checks cornerstone-prod-hc \
  --global-health-checks \
  --timeout 300s \
  --project p601-ephphatha-host

$GCLOUD_BIN compute backend-services add-backend cornerstone-prod-backend \
  --global \
  --instance-group cornerstone-prod-ig \
  --instance-group-zone us-central1-f \
  --project p601-ephphatha-host

$GCLOUD_BIN compute url-maps create cornerstone-prod-url-map \
  --default-service cornerstone-prod-backend \
  --global \
  --project p601-ephphatha-host

$GCLOUD_BIN compute target-https-proxies create cornerstone-prod-https-proxy \
  --global \
  --url-map cornerstone-prod-url-map \
  --global-url-map \
  --ssl-certificates cornerstone-prod-cert \
  --global-ssl-certificates \
  --project p601-ephphatha-host

$GCLOUD_BIN compute forwarding-rules create cornerstone-prod-https-fr \
  --global \
  --load-balancing-scheme EXTERNAL_MANAGED \
  --network-tier PREMIUM \
  --address cornerstone-prod-ip \
  --target-https-proxy cornerstone-prod-https-proxy \
  --global-target-https-proxy \
  --ports 443 \
  --project p601-ephphatha-host
```

## 6. Configure Hosted OAuth

Cornerstone now requests only `openid` and `email` for hosted owner sign-in, which is enough for the server-side session flow.

Create the OAuth client and credential once:

```bash
$GCLOUD_BIN iam oauth-clients create cornerstone-web \
  --project p601-ephphatha-host \
  --location=global \
  --client-type=confidential-client \
  --display-name='Cornerstone Web' \
  --description='Cornerstone hosted owner sign-in' \
  --allowed-scopes='openid,email' \
  --allowed-redirect-uris='https://cornerstone.dhenara.com/api/v1/auth/google/callback,http://127.0.0.1:8080/api/v1/auth/google/callback' \
  --allowed-grant-types='authorization-code-grant,refresh-token-grant'

$GCLOUD_BIN iam oauth-clients credentials create cornerstone-web-cred \
  --project p601-ephphatha-host \
  --location=global \
  --oauth-client=cornerstone-web \
  --display-name='Cornerstone Web Credential'
```

Then read the values you need for `runtime-env.json`:

```bash
$GCLOUD_BIN iam oauth-clients describe cornerstone-web \
  --project p601-ephphatha-host \
  --location=global

$GCLOUD_BIN iam oauth-clients credentials describe cornerstone-web-cred \
  --project p601-ephphatha-host \
  --location=global \
  --oauth-client=cornerstone-web
```

## 7. Create The Hosted Runtime Secret Input

Create the local machine-owned input file:

```bash
mkdir -p deploy/vm/local/secrets deploy/vm/local/control
cp deploy/templates/secrets/runtime-env.example.json deploy/vm/local/secrets/runtime-env.json
chmod 600 deploy/vm/local/secrets/runtime-env.json
```

Fill it with:

- `postgres_admin_password`
- `postgres_app_password`
- `google_oauth_client_id`
- `google_oauth_client_secret`

Then publish it:

```bash
GCLOUD_BIN=${GCLOUD_BIN:-gcloud} bash deploy/vm/update_gcp_runtime_env_secret.sh
```

## 8. Prepare The Host And Deploy

Prepare the VM host directories once:

```bash
GCLOUD_BIN=${GCLOUD_BIN:-gcloud} bash deploy/vm/prepare_host.sh
```

Then run the first deploy with the same repeatable deploy path used later:

```bash
GCLOUD_BIN=${GCLOUD_BIN:-gcloud} bash deploy/vm/deploy.sh --plan
GCLOUD_BIN=${GCLOUD_BIN:-gcloud} bash deploy/vm/deploy.sh
```

If you intentionally deploy uncommitted local work, use:

```bash
GCLOUD_BIN=${GCLOUD_BIN:-gcloud} DEPLOY_VM_ALLOW_DIRTY=1 bash deploy/vm/deploy.sh
```

## 9. DNS Step Still Required Outside This Project

The `dhenara.com` DNS zone is not managed in `p601-ephphatha-host`, so the first rollout could not create the record from this repo.

Create this DNS record in the real DNS control plane for `dhenara.com`:

- `A cornerstone.dhenara.com -> 8.233.205.67`

After that record propagates:

- `cornerstone-prod-cert` should move from `PROVISIONING` to `ACTIVE`
- `https://cornerstone.dhenara.com` should become reachable
- hosted Google sign-in should use the configured callback successfully

Current status after the first rollout:

- VM deploy completed successfully
- backend service health is `HEALTHY`
- certificate is still `PROVISIONING` until the DNS record exists

## 10. Verification Commands

Backend health:

```bash
$GCLOUD_BIN compute backend-services get-health cornerstone-prod-backend \
  --global \
  --project p601-ephphatha-host
```

Certificate status:

```bash
$GCLOUD_BIN compute ssl-certificates describe cornerstone-prod-cert \
  --global \
  --project p601-ephphatha-host
```

Direct VM-local app checks:

```bash
$GCLOUD_BIN compute ssh cornerstone-prod-vm \
  --project p601-ephphatha-host \
  --zone us-central1-f \
  --command 'curl -fsS http://127.0.0.1/health && printf "\n---\n" && curl -fsS http://127.0.0.1/api/v1/session'
```

## Future Domain Change

When you move from `cornerstone.dhenara.com` to a new domain later:

1. Update `VM_DOMAIN` and `CORNERSTONE_FRONTEND_PUBLIC_URL` in `deploy/config/environments/prod.gcp.env`.
2. Update the managed certificate to cover the new domain, or create a replacement certificate and attach it to the HTTPS proxy.
3. Point the new DNS `A` record to the same reserved load-balancer IP `8.233.205.67`, unless you intentionally rotate the frontend IP.
4. Update the OAuth client allowed redirect URIs to include the new callback URL, or create a replacement OAuth client and credential.
5. If the OAuth client id or secret changes, update `deploy/vm/local/secrets/runtime-env.json` and republish it with `bash deploy/vm/update_gcp_runtime_env_secret.sh`.
6. Rerun `make vm-deploy-plan` and `make vm-deploy`.

If you keep the same load balancer and reserved IP, the main moving parts are:

- env file domain values
- certificate domain attachment
- DNS record
- OAuth redirect URI
