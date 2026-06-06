# Dev Control Templates

Cornerstone keeps curriculum source of truth under `content/` and deployment-owned identity bootstrap under `deploy/config/runtime_defaults/`.

Tracked non-secret dev wiring now lives in `deploy/config/environments/dev.env`.
Machine-local secrets live in `scratchpad/dev/local/secrets/runtime-env.json`.

This folder remains intentionally small because the early-stage app only needs the tracked bootstrap defaults plus the local runtime secret JSON.
