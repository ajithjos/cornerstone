# Authoring Guide

This directory is the complete authoring pack for Cornerstone.

Share it with whoever is doing the work: a teacher, subject expert, contractor, LLM, or AI agent. It explains what Cornerstone is trying to deliver, how authored curriculum is used in the product, the rules that authored content must follow, and the workflow for producing repo-ready curriculum.

## What This Directory Covers

- product context for Cornerstone
- the stable curriculum model and file ownership
- authoring rules for tone, vocabulary, naming, reuse, and validation
- arithmetic teaching guidance for pathway design and material generation
- family and cultural-context guidance for names, examples, and tone
- the practical workflow for creating, revising, or reviewing curriculum
- a fillable brief template for one curriculum slice
- worked example briefs under `examples/`

Briefs under `examples/` are planning inputs. The canonical authored curriculum built from those briefs lives under `content/library/`.

Architecture decisions about planning objects and runtime surfaces live under `../architecture/`.

## Recommended Reading Order

1. [Product and curriculum model](./product-and-curriculum-model.md)
2. [Authoring rules](./authoring-rules.md)
3. [Arithmetic teaching guidance](./arithmetic-teaching-guidance.md) when the slice touches arithmetic
4. [Authoring workflow](./authoring-workflow.md)
5. [Curriculum slice brief template](./curriculum-slice-brief-template.md)
6. [Planning, authoring, and runtime](../architecture/planning-authoring-and-runtime.md) if you need the whole-system mental model
7. [Arithmetic fact fluency brief](./examples/arithmetic-fact-fluency-brief.md) for a concrete first curriculum slice
8. [Arithmetic written methods brief](./examples/arithmetic-written-methods-brief.md) for the scalable whole-number algorithms route

## How To Use This Directory

Use the whole directory when you want someone to:

- create a new subject or area
- expand an existing area
- revise skills, stages, materials, or playlists
- review existing curriculum for weak structure, duplication, or missing pieces

When making a request, also attach or point to:

- `content/library/registry.yaml`
- the in-scope pathway directory under `content/library/{subject}/{area}/{pathway}/`
- a filled-in [Curriculum slice brief template](./curriculum-slice-brief-template.md), when available
- clear scope constraints about which files may change and which must stay fixed

## What Good Output Looks Like

Good authoring output should give you:

1. exact file changes for `registry.yaml` and pathway-contained Markdown
2. clear stage and skill boundaries
3. reusable materials instead of one-off placeholders
4. validation notes for ids, cross-references, and scope consistency
