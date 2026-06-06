Machine-local production deployment inputs live here.

- Put optional machine-local control overrides in `deploy/vm/local/control/`.
- Put machine-local secret inputs in `deploy/vm/local/secrets/`.

The active production contract is now:

1. `deploy/config/environments/prod.gcp.env`
2. `deploy/vm/local/secrets/runtime-env.json`
3. GCP Secret Manager secret `GCP_RUNTIME_ENV_SECRET_NAME`

Tracked local secret example:

- `deploy/templates/secrets/runtime-env.example.json`

Optional non-secret production override:

- `deploy/vm/local/control/prod.gcp.env`

Recommended bootstrap:

```bash
mkdir -p deploy/vm/local/secrets deploy/vm/local/control
cp deploy/templates/secrets/runtime-env.example.json deploy/vm/local/secrets/runtime-env.json
```
