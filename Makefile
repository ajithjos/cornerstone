.PHONY: help install-dev fmt fmt-check lint test rust-fmt rust-lint rust-test rust-run rust-migrate rust-bootstrap-apply rust-library-validate content-validate frontend-pub-get flutter-version-check flutter-analyze flutter-test frontend-sanity docs-site-install docs-site-prepare docs-site-build docs-site-dev control-plane-db-up control-plane-db-migrate control-plane-bootstrap-apply control-plane-library-reload control-plane-compose-up control-plane-compose-down control-plane-compose-reset control-plane-live-frontend-up control-plane-live-frontend-down frontend-live-run vm-setup vm-runtime-secret-push vm-deploy-plan vm-deploy daily-local daily

PYTHON_RUN ?= uv run
FLUTTER_APP_DIR ?= $(CURDIR)/fe/flutter/apps/cornerstone
DOCS_SITE_DIR ?= $(CURDIR)/docs_site
RUST_MANIFEST ?= $(CURDIR)/rust/Cargo.toml
FLUTTER_REQUIRED_VERSION ?= 3.41.9
CONTENT_ROOT ?= $(CURDIR)/content
LIVE_FRONTEND_PORT ?= 2255
LIVE_FRONTEND_API_BASE_URL ?= http://127.0.0.1:8788

help:
	@echo "Primary targets: daily-local, control-plane-compose-up, rust-run"
	@echo "Validation targets: fmt-check, lint, test, rust-library-validate, content-validate, frontend-sanity, docs-site-build"
	@echo "Control-plane targets: control-plane-db-up, control-plane-db-migrate, control-plane-bootstrap-apply, control-plane-library-reload, control-plane-compose-up, control-plane-compose-down, control-plane-compose-reset"
	@echo "Live frontend targets: control-plane-live-frontend-up, control-plane-live-frontend-down, frontend-live-run"
	@echo "VM deploy targets: vm-setup, vm-runtime-secret-push, vm-deploy-plan, vm-deploy"

install-dev:
	uv sync --all-extras

fmt:
	cargo fmt --manifest-path $(RUST_MANIFEST) --all
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && dart format lib test'
	$(PYTHON_RUN) ruff format scripts tests

fmt-check:
	cargo fmt --manifest-path $(RUST_MANIFEST) --all --check
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && dart format lib test --set-exit-if-changed'
	$(PYTHON_RUN) ruff format scripts tests --check

lint:
	cargo clippy --manifest-path $(RUST_MANIFEST) --workspace --all-targets --all-features -- -D warnings
	$(PYTHON_RUN) ruff check scripts tests

test:
	cargo test --manifest-path $(RUST_MANIFEST) --workspace --all-features
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter test'
	$(PYTHON_RUN) pytest -q

rust-fmt:
	cargo fmt --manifest-path $(RUST_MANIFEST) --all

rust-lint:
	cargo clippy --manifest-path $(RUST_MANIFEST) --workspace --all-targets --all-features -- -D warnings

rust-test:
	cargo test --manifest-path $(RUST_MANIFEST) --workspace --all-features

rust-run:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- server

rust-migrate:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- migrate

rust-bootstrap-apply:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- bootstrap-apply

rust-library-validate:
	CORNERSTONE_CONTENT_ROOT="$(CONTENT_ROOT)" cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- library-validate

content-validate: rust-library-validate
	$(PYTHON_RUN) --with pytest python -m pytest tests/test_pathway_library.py tests/test_sync_docs_site_docs.py

learner-content-validate: rust-library-validate
	cargo test --manifest-path $(RUST_MANIFEST) -p control_plane learner_workspace_sanitizes_adult_materials
	$(PYTHON_RUN) --with pytest python -m pytest tests/test_pathway_library.py

frontend-pub-get:
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter pub get'

flutter-version-check:
	@bash -lc 'required="$(FLUTTER_REQUIRED_VERSION)"; current="$$(flutter --version | head -n 1 | awk "{print \$$2}")"; [ "$$current" = "$$required" ] || { echo "Expected Flutter $$required but found $$current"; exit 1; }'

flutter-analyze: frontend-pub-get flutter-version-check
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter analyze'

flutter-test: frontend-pub-get flutter-version-check
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter test'

frontend-sanity: flutter-analyze flutter-test

docs-site-install:
	@bash -lc 'cd "$(DOCS_SITE_DIR)" && npm install'

docs-site-prepare:
	$(PYTHON_RUN) python scripts/sync_docs_site_docs.py

docs-site-build:
	@bash -lc 'cd "$(DOCS_SITE_DIR)" && npm install && npm run build'

docs-site-dev:
	@bash -lc 'cd "$(DOCS_SITE_DIR)" && npm install && npm run start'

control-plane-db-up:
	bash deploy/dev/setup.sh --postgres-only

control-plane-db-migrate:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- migrate

control-plane-bootstrap-apply:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- bootstrap-apply

control-plane-library-reload:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- library-validate

control-plane-compose-up:
	bash deploy/dev/setup.sh

control-plane-compose-down:
	bash deploy/dev/down.sh

control-plane-compose-reset:
	bash deploy/dev/reset.sh

control-plane-live-frontend-up:
	bash deploy/dev/live_frontend/up.sh

control-plane-live-frontend-down:
	bash deploy/dev/live_frontend/down.sh

frontend-live-run: frontend-pub-get
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter run -d chrome --web-port $(LIVE_FRONTEND_PORT) --dart-define=CORNERSTONE_API_BASE_URL=$(LIVE_FRONTEND_API_BASE_URL)'

vm-setup:
	bash deploy/vm/prepare_host.sh

vm-runtime-secret-push:
	bash deploy/vm/update_gcp_runtime_env_secret.sh

vm-deploy-plan:
	bash deploy/vm/deploy.sh --plan

vm-deploy:
	bash deploy/vm/deploy.sh

daily-local: fmt-check lint rust-test frontend-sanity content-validate docs-site-build

daily: daily-local test
