# Deploy Config

Tracked deployment config is split into:

- `build/`: immutable image and build inputs committed with the repo
- `environments/`: non-secret deploy wiring for dev and hosted VM flows
- `runtime_defaults/`: editable runtime defaults mounted by local or production deployment flows

Current runtime defaults:

- `identity_bootstrap.yaml`: team, users, owner auth fields, and memberships loaded into the control plane at bootstrap time

Curriculum catalogs and library content stay under `content/`. Identity bootstrap is deployment config, not curriculum content.
