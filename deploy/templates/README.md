# Deploy Templates

Cornerstone now follows one deployment contract across local development and the VM path.

Use these categories only:

1. Setup env
2. Runtime secret JSON
3. Tracked runtime defaults

Current model:

- setup env selects non-secret host paths, ports, project, zone, and deployment wiring
- runtime secret JSON carries application secret values such as Postgres passwords and Google OAuth secrets
- tracked runtime defaults live under `deploy/config/`

Practical rule:

- dev setup env comes from the tracked `deploy/config/environments/dev.env`
- dev can optionally override non-secret setup with `dev/site/control/dev.env`
- dev runtime secrets come from `dev/site/secrets/runtime-env.json`
- prod setup wiring comes from the tracked `deploy/config/environments/prod.gcp.env`
- prod can optionally override non-secret setup with `deploy/vm/local/control/prod.gcp.env`
- prod maintained runtime secret input comes from `deploy/vm/local/secrets/runtime-env.json` and publishes to `GCP_RUNTIME_ENV_SECRET_NAME`

There is no tracked root `.env` path in the active contract anymore.
