# Planning, Authoring, And Runtime

This doc describes the cleaned Cornerstone shape after content cleanup.

The model is easiest to use when three concerns stay separate but connected:

1. the whole teaching route a parent or coach wants to see
2. the curriculum objects that delivery and progress depend on
3. the repo structure used to maintain those objects

Those concerns belong to one unified content tree. They should not be split into disconnected mental models.

## Short Answer

- `pathway` is the canonical whole-route object.
- A pathway can be authored directly in Markdown.
- A separate pathway YAML file is optional, not required.
- `subject` and `area` stay as the global taxonomy.
- `stage` means learning progression, not age or school year.
- age or year sits in entry guidance on pathways and playlists.
- drills and quick checks are material kinds inside sessions.
- runtime stays anchored on playlist, assignment, session, evidence, and progress.

## Unified Content Tree

After cleanup, authored curriculum lives in one content tree:

```text
content/
  library/
    registry.yaml
    maths/
      arithmetic/
        arithmetic-fact-fluency/
          pathway.md
          stages/
          skills/
          playlists/
          materials/
```

This keeps the system connected in one place:

- `registry.yaml` defines the stable top-level boundaries: subject, area, and pathway registry
- each pathway directory is the contained authoring unit for one real route
- stages, skills, playlists, and materials live inside the pathway they belong to

The brief stays in [docs/authoring/examples/arithmetic-fact-fluency-brief.md](../authoring/examples/arithmetic-fact-fluency-brief.md) as the planning input. The authored pathway under `content/library/` is the curriculum output built from that brief.

## The Three Layers

### 1. Planning Layer

The planning layer is the whole route a human wants to read and reason about.

Canonical object:

- `pathway`

A pathway answers questions like:

- What is the whole arithmetic route for this learner?
- What comes next after this playlist?
- Where should a five-year-old, seven-year-old, or ten-year-old enter?
- Which playlists belong to the same larger route?

The pathway owns route order and entry guidance. It does not replace progress tracking.

### 2. Curriculum Layer

The curriculum layer is the reusable learning structure inside a pathway.

- Subject: the top domain such as maths
- Area: the slice inside a subject such as arithmetic
- Stage: the broad learning step inside the pathway
- Skill: the smallest tracked outcome
- Material: the teaching, practice, drill, or checking asset
- Playlist: the short assignable teaching block

These objects stay distinct because reuse, assignment, evidence, and progress depend on that separation.

### 3. Runtime Layer

The runtime layer is the live learner state.

- Learner: the child receiving work
- Assignment: one learner using one playlist over time
- Session: one scheduled work block inside the assignment
- Evidence: the recorded outcome of completed work
- Progress: the learner's current state for each skill

The runtime model stays close to delivery. Long-range planning belongs in pathways, not in assignments.

## The Two Connected Structures

Inside the unified content tree there are still two connected structures.

### Delivery Route

- pathway
- playlist
- session

This answers:

- What is the whole route?
- What short plan comes next?
- What should happen today?

### Learning Route

- subject
- area
- stage
- skill
- material

This answers:

- What domain is this in?
- What broad slice is the learner working through?
- Which skills matter here?
- Which materials teach or check them?

### How They Connect

- a pathway orders playlists
- a playlist schedules sessions
- a session uses materials
- materials support skills
- skills belong to stages
- evidence from completed sessions updates skill progress

That is why pathway and playlist can feel similar at first glance. Both are planning objects. Their responsibilities are different:

- pathway = the route across multiple playlists
- playlist = one short assignable block
- session = one work block inside that block

## Why Pathway Does Not Need A Separate YAML File

The pathway is a domain object. YAML is only one storage format.

If a pathway reads naturally as a primary authored Markdown document, that is a valid and often better fit. A pathway document can carry the route, entry guidance, sequencing notes, and the stage and playlist links in one human-readable place.

Use a separate pathway YAML file only when the structured metadata becomes awkward to maintain in Markdown frontmatter or inside the pathway document itself.

That means:

- pathway is required as a concept
- pathway YAML is optional as an implementation detail

## Stage Versus Age

`stage` is not age.

Use stage for pedagogical progression, such as:

- readiness and bonds within 5
- addition and subtraction facts to 10
- multiplication facts foundations

Use age or school year only for entry guidance, such as:

- a five-year-old usually starts at readiness and bonds within 5
- a seven-year-old usually starts at addition and subtraction facts to 10
- a ten-year-old usually takes a quick check first, then jumps to the first playlist that is not yet confirmed

This keeps the pathway reusable across different learners without duplicating the entire route for every age band.

## Where Drills And Exercises Live

Drills and quick checks are material kinds used inside sessions. They are not separate top-level planning objects.

When a drill needs live execution, keep that runtime contract on the material itself rather than introducing a new planning object. See [Runtime Program Contract](./runtime-program-contract.md) for the exact developer contract, [How Live Materials Work](./how-live-materials-work.md) for the short walkthrough, and [Executable Drills And Assignment Delivery](./executable-drills-and-assignment-delivery.md) for the fuller architecture note.

Recommended material kinds:

- lesson_note
- teaching_note
- worksheet
- drill
- quick_check

That gives one clean rule:

- pathway, playlist, and session decide sequence
- material kind decides what the learner actually does

Use `lesson_note` as the durable learner reference, including tables, models, definitions, and worked examples when useful. Use `worksheet` for consumable practice prompts that ask the learner to retrieve or apply that reference.

## Recommended Authoring Flow

1. Start from a brief that states the learner context and desired outcome.
2. Author the pathway as the whole route.
3. Define the stages inside that pathway.
4. Define the smallest real skills worth tracking.
5. Write the materials needed to teach, practise, review, and check.
6. Build playlists that order those materials into short assignable blocks.
7. Add entry guidance that maps approximate ages or current readiness to the right starting playlist.

## Example: Arithmetic Fact Fluency

The first complete pathway in this model is:

- subject: `maths`
- area: `arithmetic`
- pathway: `arithmetic_fact_fluency`

Its authored source lives under:

- `content/library/registry.yaml`
- `content/library/maths/arithmetic/arithmetic-fact-fluency/pathway.md`
- `content/library/maths/arithmetic/arithmetic-fact-fluency/stages/`
- `content/library/maths/arithmetic/arithmetic-fact-fluency/skills/`
- `content/library/maths/arithmetic/arithmetic-fact-fluency/playlists/`
- `content/library/maths/arithmetic/arithmetic-fact-fluency/materials/`

That pathway contains the route, stage sequence, skills, playlists, material links, and age-based entry guidance in one contained scope.

## Status

The cleaned authoring shape now lives under `content/library/`.

The arithmetic fact-fluency pathway is the first end-to-end slice in that tree.

The Rust loader and the docs-site renderer now read directly from `content/library/`.
