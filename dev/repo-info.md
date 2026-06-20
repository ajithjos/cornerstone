# Cornerstone Repo Info

Runtime: Rust control plane, Flutter frontend, docs site, content library, Postgres, and Docker compose for local development.

Daily startup:

```bash
make setup
source dev/sourceme
make dev-up
```

Useful commands:

```bash
make context
make doctor
make clean
make clean-python
make clean-all
make clean-deps
make check-local
make check
make submodules-master-check
make submodules-master
```

Local Cornerstone site state belongs under `dev/site_root/`. That root owns local control overrides, local secrets, Postgres data, artifacts, exports, and generated runtime files.

Deployment commands:

```bash
make deploy-plan
make deploy
make deploy-secret-push
```

Deployment identity is checked through the tracked GCP contract in `deploy/config/environments/prod.gcp.env`. `make doctor` fails fast when the active gcloud config, account, project, or authentication is wrong.
