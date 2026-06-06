Machine-local development overrides live here.

- Put optional machine-local control files in `deploy/dev/local/control/`.
- Put machine-local secret files in `deploy/dev/local/secrets/`.

The active dev contract is now:

1. `deploy/config/environments/dev.env`
2. `deploy/dev/local/secrets/runtime-env.json`
3. `deploy/config/runtime_defaults/identity_bootstrap.yaml`

Tracked local secret example:

- `deploy/templates/secrets/runtime-env.example.json`

Optional non-secret dev override:

- `deploy/dev/local/control/dev.env`

Recommended bootstrap:

```bash
mkdir -p deploy/dev/local/secrets deploy/dev/local/control
cp deploy/templates/secrets/runtime-env.example.json deploy/dev/local/secrets/runtime-env.json
```
