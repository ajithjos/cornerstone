# Cornerstone

Cornerstone is a learning control plane for a small learning team.

This repository now contains an MVP stack with:

- a Rust control-plane API backed by Postgres
- a Flutter web frontend for owner and learner workflows
- a standalone Docusaurus developer-docs site for repo and operator references
- Docker-based dev and VM-oriented deployment templates

Identity bootstrap team definitions live under `deploy/config/runtime_defaults/identity_bootstrap.yaml`.
Curriculum content stays under `content/`.

## Quickstart

```bash
source dev/sourceme
make setup
make dev-up
```

Live frontend mode (backend in Docker, Flutter with hot reload):

```bash
source dev/sourceme
make dev-live

# Then run FE separately with:
flutter run -d chrome --web-port=2255 --dart-define=CORNERSTONE_API_BASE_URL=http://127.0.0.1:8788
# or
make frontend-dev
```

Default local URLs:

- frontend preview: `http://127.0.0.1:8080`
- control plane API and service index: `http://127.0.0.1:8788`

`make dev-up` builds production-style static previews for the
Flutter app and serves it from nginx. It does not run live-reload frontend or
content watchers inside compose.

`make dev-live` keeps only backend dependencies in Docker
and is intended for frontend live iteration via `flutter run` on a separate
port.

Use `make docs-site-dev` when you want the standalone developer-docs site on
`http://127.0.0.1:3001`.

## Repo Shape

- `content/`: the repo-owned pathway library under `content/library/`
- `rust/`: Rust control-plane workspace
- `fe/flutter/apps/cornerstone/`: Flutter web runtime UI
- `docs_site/`: Docusaurus developer-docs site
- `deploy/`: dev and production deployment workflows
- `docs/`: product and operator documentation
