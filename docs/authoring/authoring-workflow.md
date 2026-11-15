# Authoring Workflow

Use this workflow whether a human expert is writing curriculum directly or an AI system is drafting changes.

## Gather Inputs First

Before authoring or reviewing a slice, gather:

- this directory
- the subject-specific pedagogy guide when one exists, such as [Arithmetic teaching guidance](./arithmetic-teaching-guidance.md)
- `content/library/registry.yaml`
- the in-scope pathway directory under `content/library/{subject}/{area}/{pathway}/`
- a filled-in [Curriculum slice brief template](./curriculum-slice-brief-template.md), when available
- explicit constraints about which files may change and which must stay fixed

## Standard Authoring Flow

1. Define the subject, area, learner context, and desired outcome.
2. Define the pedagogy stance for the slice in concrete terms: what must be taught directly, what must be practised to fluency, and what anti-patterns must be avoided.
3. Review the existing pathway registry and in-scope pathway files before creating anything new.
4. Draft or revise the pathway as the whole route.
5. Draft or revise the skills for the slice.
6. Group those skills into stages that make sense to a parent or coach.
7. Decide what belongs in owner-only Teach and learner Learn, Practice, and Checkpoint.
8. Write or revise the markdown materials.
9. Assemble or revise one or more playbooks using the explicit `sections` in each playlist file. Keep reusable teaching guidance in Teach, printable explanations in Learn, repeatable generators in Practice, and completion conditions in Checkpoint.
10. Add or revise entry guidance for age or current readiness.
11. Run the [review checklist](./authoring-rules.md).
12. Run `uv run --with pytest python -m pytest tests/test_pathway_library.py` while iterating on the cleaned tree.
13. Validate generated activity packages when the slice includes interactive material; rebuild their shared foundation with `python scripts/build_activity_packages.py` after foundation changes.

These checks should cover the whole in-scope pathway, not only one individual file.

## How To Brief The Author

State the request plainly. Say:

- whether you want generation, revision, or review
- which subject and area are in scope
- which files may change
- which files must stay fixed
- which pedagogy rules are required for the slice and which teaching anti-patterns must be rejected
- which family, faith, or cultural-context preferences should guide names, examples, tone, and pronoun style
- any tone, classroom, family, or accessibility constraints
- whether you want exact file edits or only a proposed plan

If essential slice facts are missing, ask only for those missing facts.

## Expected Deliverables

Good output should include:

1. the exact registry and Markdown files to add or update
2. the exact markdown materials to add or update
3. a short explanation of why the stage and skill boundaries make sense
4. validation notes for cross-references, naming consistency, and reuse choices

The author should produce only the files required for the slice:

- `content/library/registry.yaml`, when subject, area, or pathway registry changes are needed
- `content/library/{subject}/{area}/{pathway}/pathway.md`
- stage, skill, playlist, and material files under that pathway directory

## Repo Validation Commands

Use these from the repo root when you need to validate repository changes:

```bash
uv run --with pytest python -m pytest tests/test_pathway_library.py
make rust-library-validate
make learner-content-validate
make content-validate
uv run python scripts/sync_docs_site_docs.py
cargo test -p catalog --manifest-path rust/Cargo.toml
cargo check -p control_plane --manifest-path rust/Cargo.toml
cd fe/flutter/apps/cornerstone && flutter analyze
```

Use the pathway-library test as the fast structural check for cleaned slices. Use `make rust-library-validate` and `make content-validate` for the broader runtime and docs-sync validation pass.
