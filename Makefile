.PHONY: help context doctor gcloud-setup setup devkit-bootstrap submodules-master submodules-master-check clean clean-python clean-all clean-deps fmt fmt-check lint test rust-fmt rust-lint rust-test rust-run rust-migrate rust-bootstrap-apply rust-library-validate content-validate frontend-pub-get flutter-version-check flutter-analyze flutter-test frontend-sanity docs-site-install docs-site-prepare docs-site-build docs-site-dev db db-migrate bootstrap-apply library-reload dev-up dev-down dev-reset dev-live dev-live-down frontend-dev deploy-setup deploy-secret-push deploy-plan deploy check-local check

PYTHON_RUN ?= uv run
FLUTTER_APP_DIR ?= $(CURDIR)/fe/flutter/apps/cornerstone
DOCS_SITE_DIR ?= $(CURDIR)/docs_site
RUST_MANIFEST ?= $(CURDIR)/rust/Cargo.toml
FLUTTER_REQUIRED_VERSION ?= 3.44.1
CONTENT_ROOT ?= $(CURDIR)/content
LIVE_FRONTEND_PORT ?= 2255
LIVE_FRONTEND_API_BASE_URL ?= http://127.0.0.1:8788
DEPLOY_GCP_ENV_FILE ?= deploy/config/environments/prod.gcp.env
DEVKIT_MAKE := $(MAKE) --no-print-directory -C dev/devkit REPO_ROOT=$(CURDIR)

help: context

devkit-bootstrap:
	@if [ ! -f dev/devkit/Makefile ]; then git submodule update --init -- dev/devkit; fi

context: devkit-bootstrap
	@$(DEVKIT_MAKE) context
	@echo
	@DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/deploy.sh --context

doctor: devkit-bootstrap
	@$(DEVKIT_MAKE) doctor
	@command -v uv >/dev/null || (echo "Missing uv. Install uv from https://docs.astral.sh/uv/." >&2; exit 2)
	@command -v cargo >/dev/null || (echo "Missing cargo. Install Rust with rustup." >&2; exit 2)
	@command -v flutter >/dev/null || (echo "Missing flutter. Install the pinned Flutter toolchain before frontend work." >&2; exit 2)
	@command -v docker >/dev/null || (echo "Missing docker. Install/start Docker for make dev-up." >&2; exit 2)
	@DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/deploy.sh --doctor

gcloud-setup: devkit-bootstrap
	@DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/deploy.sh --gcloud-setup

setup: devkit-bootstrap
	$(DEVKIT_MAKE) setup
	uv sync --all-extras

submodules-master: devkit-bootstrap
	$(DEVKIT_MAKE) submodules-master

submodules-master-check: devkit-bootstrap
	$(DEVKIT_MAKE) submodules-master-check

clean: devkit-bootstrap
	$(DEVKIT_MAKE) clean

clean-python: devkit-bootstrap
	$(DEVKIT_MAKE) clean-python

clean-all: devkit-bootstrap
	$(DEVKIT_MAKE) clean-all

clean-deps: devkit-bootstrap
	$(DEVKIT_MAKE) clean-deps

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
	$(PYTHON_RUN) --with pytest python -m pytest -q

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

db:
	bash deploy/dev/setup.sh --postgres-only

db-migrate:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- migrate

bootstrap-apply:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- bootstrap-apply

library-reload:
	cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- library-validate

dev-up:
	bash deploy/dev/setup.sh

dev-down:
	bash deploy/dev/down.sh

dev-reset:
	bash deploy/dev/reset.sh

dev-live:
	bash deploy/dev/live_frontend/up.sh

dev-live-down:
	bash deploy/dev/live_frontend/down.sh

frontend-dev: frontend-pub-get
	@bash -lc 'cd "$(FLUTTER_APP_DIR)" && flutter run -d chrome --web-port $(LIVE_FRONTEND_PORT) --dart-define=CORNERSTONE_API_BASE_URL=$(LIVE_FRONTEND_API_BASE_URL)'

deploy-setup:
	bash deploy/vm/prepare_host.sh

deploy-secret-push:
	DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/update_gcp_runtime_env_secret.sh

deploy-plan:
	DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/deploy.sh --plan

deploy:
	DEPLOY_GCP_ENV_FILE="$(DEPLOY_GCP_ENV_FILE)" bash deploy/vm/deploy.sh

check-local: fmt-check lint rust-test frontend-sanity content-validate docs-site-build

check: check-local test
