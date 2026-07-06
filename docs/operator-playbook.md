# Operator Playbook

This runbook is for making curriculum changes and validating the local Cornerstone stack.

## Core References

- [Learning product definition](./architecture/learning-product-definition.md)
- [Authoring guide](./authoring/README.md)
- [Product and curriculum model](./authoring/product-and-curriculum-model.md)
- [Authoring rules](./authoring/authoring-rules.md)
- [Authoring workflow](./authoring/authoring-workflow.md)
- [Curriculum slice brief template](./authoring/curriculum-slice-brief-template.md)

## Curriculum File Locations

- `content/library/registry.yaml`
- `content/library/{subject}/{area}/{pathway}/pathway.md`
- `content/library/{subject}/{area}/{pathway}/stages/*.md`
- `content/library/{subject}/{area}/{pathway}/skills/*.md`
- `content/library/{subject}/{area}/{pathway}/playlists/*.md`
- `content/library/{subject}/{area}/{pathway}/materials/*.md`

## Standard Authoring Flow

0. Share `docs/authoring/` and any relevant curriculum files with whoever is doing the work, then state the current request plainly.
1. Define the subject and area.
2. Draft or revise the pathway.
3. Draft the skills.
4. Group those skills into stages.
5. Write the materials.
6. Assemble one or more playlists.
7. Add or revise entry guidance.
8. Re-render docs and validate the runtime.

## Local Validation Commands

Use these from the repo root.

```bash
uv run --with pytest python -m pytest tests/test_pathway_library.py
make rust-library-validate
make content-validate
uv run python scripts/sync_docs_site_docs.py
uv run --with pytest python -m pytest tests/test_sync_docs_site_docs.py
cargo test -p catalog --manifest-path rust/Cargo.toml
cargo check -p control_plane --manifest-path rust/Cargo.toml
cd fe/flutter/apps/cornerstone && flutter analyze
```

Use the pathway-library test while shaping cleaned pathway content. Use `make rust-library-validate` and `make content-validate` for the broader runtime and docs-sync validation pass.

## Local Stack Commands

```bash
make db
make dev-up
make dev-down
make dev-reset

# For live frontend iteration with hot reload  up/down the BE in Docker and run the FE separately with flutter run:
make dev-live
make dev-live-down
# Run FE separately with:
flutter run -d chrome --web-port=2255 --dart-define=CORNERSTONE_API_BASE_URL=http://127.0.0.1:8788
# or
make frontend-dev

```

If tracked Postgres defaults become incompatible, the repo rotates `CORNERSTONE_DEV_DATA_REVISION` to move local work onto a fresh dev data window.

## Assignment Plan Refresh

Material body/runtime edits are read from the current library by `material_id`.

Playlist session membership edits are assignment-plan edits. Existing assignments keep their own `session` and `session_material` rows until the database is reset or an owner explicitly reconciles active assignments:

```bash
make dev-reset
make dev-up
```

For a running environment where you do not want a reset, call:

```text
POST /api/v1/assignments/reconcile
{}
```

The reset-era schema is intentionally kept in one SQLx migration file: `rust/crates/control_plane/migrations/001_initial.sql`.

## Runtime Expectations

- pathways organize the whole route
- playlists become assignments at runtime
- assignments schedule sessions
- sessions produce evidence
- evidence updates progress

If a review queue exists in the UI, treat it as a helper derived from progress rather than a separate curriculum object.
