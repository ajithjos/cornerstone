# Deploy Layout

Cornerstone uses the same deployment split in both dev and the VM flow:

- tracked non-secret setup env in `deploy/config/environments/`
- local development secret JSON in `dev/site_root/secrets/`
- local hosted-deploy secret JSON in `deploy/vm/local/secrets/`
- tracked runtime defaults in `deploy/config/runtime_defaults/`

Primary entrypoints:

- first hosted rollout guide: `docs/deploy/runbooks/gcp-vm-first-deploy.md`
- one-time VM host prep: `make deploy-setup`
- local compose: `bash deploy/dev/setup.sh`
- local live frontend mode: `bash deploy/dev/live_frontend/up.sh`
- publish hosted runtime secret: `make deploy-secret-push`
- hosted deploy plan: `make deploy-plan`
- hosted deploy: `make deploy`
