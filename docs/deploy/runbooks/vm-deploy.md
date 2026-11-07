# VM Deployment

One shared Docker Compose runtime serves provider-selected Linux VMs. AWS is the default destination. Google sign-in, the public origin, PostgreSQL data, curriculum, learner state, artifacts and exports belong to the application and remain independent of the cloud provider.

## Targets And Private Inputs

`CLOUD` defaults to `aws`. `CLOUD_TARGET` defaults to `deploy/config/environments/prod.$(CLOUD).json`; it may instead select an absolute target file. The version-1 target selects native cloud identity, transport, application settings, TLS, secret custody and infrastructure. Provider/account/project/subscription, region, resource names and sizing belong in these targets. Provider mismatches fail before remote work.

- `prod.aws.json` selects AWS provisioning, company IAM Identity Center access and direct HTTPS.
- `prod.gcp.json` selects the retained GCP installation, its named identity, IAP and external HTTPS load balancer.
- `prod.ssh.example.json` demonstrates a prepared Linux VM on another cloud or on-premises host. Azure targets may select a native Azure identity with SSH transport. Automatic provisioning currently belongs only to the AWS adapter.
- `prod.vm.env` owns shared non-secret application settings. The active data revision is `03`; migration never advances or resets it.
- `deploy/config/build/images.lock.env` owns image inputs. Migration preserves the exact live application image and frontend build rather than compiling a different application version during the move.

Workforce authentication and isolated native CLI environments use the shared DevKit `cloudctl`. Put native cloud CLIs on `PATH`. `make cloud-setup` prepares the selected identity; `make cloud-doctor` verifies that identity and its selected host. A browser login alone does not qualify native cloud access.

Private operator state defaults to `~/.config/cornerstone/<target-id>/`; `CORNERSTONE_OPERATOR_ROOT` may select an absolute owner-only directory outside Git. It holds the concrete provisioning plan, incremental resource state, verified SSH host key, private administrator key and `host.json`. Prepared SSH targets supply a matching `target_id`/`provider`, hostname, absolute private key path and verified `known_hosts` path in that binding. SSH uses strict host checks; AWS first trust is verified against authenticated EC2 console fingerprints.

AWS and prepared SSH targets read `secrets/runtime-env.json` under the operator root. Its keys are `postgres_admin_password`, `postgres_app_password`, `google_oauth_client_id` and `google_oauth_client_secret`. Keep this file owner-only. The GCP target explicitly selects its existing Secret Manager resource. The retained `make deploy-secret-push` helper still administers that GCP secret through `prod.gcp.env`; it does not select the default deployment destination.

## Prepare And Deploy

```bash
make cloud-setup
make cloud-plan
# Review the saved native AMI, account, operator IP, capacity and price evidence.
make cloud-create
make cloud-doctor
make deploy-plan
make deploy
make deploy-status

# Select the retained GCP host explicitly.
make deploy-status CLOUD=gcp
```

The AWS adapter creates one VM with encrypted gp3 storage, termination protection, a reserved IPv4 address and an operator SSH key. It reuses the target's explicitly selected VPC/subnet. Only HTTPS, HTTP certificate validation and SSH from the current operator address are public. No new managed database, load balancer, IAM workload identity or scheduled backup system is introduced. The monthly allowance is a planning guard, not a provider-enforced spending cap. Interrupted provisioning retains exact resource identities and a launch client token; retries resume them and never adopt unowned resources.

Normal deployment builds Flutter web locally, packages tracked sources plus that explicit build, renders private runtime settings, transfers them through the selected transport and invokes `deploy/vm/setup.sh`. It requires a clean checkout. Untracked secret files never enter the release archive. Releases use UTC creation names; retention orders those names rather than extracted directory modification times, and activation follows healthy startup.

Direct HTTPS runs Caddy on the VM. The nginx frontend binds to loopback; PostgreSQL and the control-plane management port are also loopback-only. External TLS targets retain their load-balancer boundary. Both modes serve frontend and API from the same configured origin. Google OAuth credentials and redirect origin stay unchanged when the domain stays unchanged.

## Preserve A Running Application

Keep downtime simple: stop source application writers, export current state, import into a fresh VM, verify, then change DNS. The source VM and its disks remain the recovery copy until both sites have been checked.

```bash
CLOUD=gcp python3 deploy/state_transfer.py export --workarea /absolute/private/transfer
# Select a clean source checkout whose application files match the export manifest.
CLOUD=aws python3 deploy/state_transfer.py import --workarea /absolute/private/transfer
```

Export checks the exact owned current release and selected state paths, stops the application services, leaves PostgreSQL available and records a source freeze. It preserves the current database, artifacts, exports, rendered settings, live application image and built frontend. Table content, sequence values and files must remain unchanged throughout export. A source release label may contain uncommitted production differences: preserve those exact sources in a reviewed recovery branch; import requires matching application-source hashes and does not silently replace them with repository HEAD.

Import admits only a fresh destination with no current installation and no existing PostgreSQL data. It verifies transfer checksums and archive paths before upload, preserves every existing runtime setting and credential, and changes only host/transport wiring and image references. It restores through PostgreSQL, gives the application role ownership, and compares database content, sequences, file hashes, permissions, ownership and frontend asset hashes before application startup. The actual application image identity must also match. The existing SQLx migrations, bootstrap model, learner history, owner identities and sessions remain intact.

Transfer artifacts and manifests stay owner-only outside Git. Failed operations retain their intent and verification receipts. Inspect them before recovery; never replay a destructive import over uncertain or running state. Old reset-era data directories are not the active application and remain on the retained source host.

## DNS, Verification And Retirement

Once destination data and private health checks pass, update the existing `scholahouse.com` A record to the new reserved AWS address. Preserve unrelated records. The observed Cloudflare record uses a 300-second TTL, so allow roughly five minutes for a previously cached address to expire, with extra time for local caches. Public DNS, valid TLS, API/database health, the Flutter interface and Google sign-in are separate checks. Do not bypass certificate validation or change OAuth registrations merely to work around DNS caching.

Keep the GCP VMs and disks until Intranet and Cornerstone have both been verified. A stopped VM ends compute charges while retaining its disk; storage and retained networking still incur charges. Retire only the exact old service resources after that verification. Once the destination accepts writes, the source is a point-in-time recovery copy; returning DNS alone cannot recover newer destination writes.
