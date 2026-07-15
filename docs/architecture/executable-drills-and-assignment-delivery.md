# Executable Drills And Assignment Delivery

This note fills the gap between the existing curriculum model and the live activity experience.

Cornerstone already has the right planning spine:

- pathway = the whole route
- playlist = the assignable teaching block
- session = one work block inside the playlist
- material = what the learner or parent actually uses

The missing piece is the contract for materials that behave like live drills or quick checks instead of static markdown.

It also needs a clearer parent-facing browse and assignment flow so an adult can see the ordered playlist, the session materials, and the expected target before assigning it.

## Product Capability

Today the repository already holds real ordered playlists for arithmetic fact fluency, including:

- Readiness And Bonds Within 5
- Addition And Subtraction Facts To 10
- Addition And Subtraction Facts To 20

Those playlists already define ordered sessions in playlist frontmatter.

Delivery now uses an explicit runtime contract, structured playlist sessions, persisted activity instances, compact learner evidence, correction, retry, and actionable review. The remaining rule is to extend those contracts deliberately when a new interaction type is introduced, rather than bypassing them in content or Flutter.

## Decisions

Use these as the default product decisions.

### 1. Keep drills as materials

Do not introduce a new top-level planning object for exercises.

Drills and quick checks stay as material kinds inside playlist sessions.

That preserves the current model:

- pathway decides the route
- playlist decides the assignable block
- session decides the order inside the block
- material decides what the learner does

### 2. Never execute arbitrary code from authored content

Content files may describe a drill, but they should not ship raw executable code.

Instead, an executable material points to a trusted backend-owned engine and a validated parameter block.

That gives a stable contract, keeps runtime safe, and still leaves room for future AI-assisted authoring.

AI may later propose material parameters or generate draft specs, but the runtime must still execute only approved engines and validated schemas.

### 3. Backend owns generation and scoring

The backend should:

- validate the material runtime contract
- create a deterministic activity instance for a specific session material
- generate the items from a seed and parameter block
- score the submission
- persist only the summary evidence that Cornerstone actually needs

The client should render trusted interaction primitives from JSON. It should not run remote code.

### 4. Persist summary evidence, not every answer forever

Cornerstone does not need keystroke-level history as the default storage model.

The persistence rule is:

- generate items for one activity instance
- let the learner answer locally in the client
- submit the completed response set once
- score on the backend
- store only the session summary and skill evidence summary

This keeps the model simple and avoids a noisy data trail that does not improve parent decisions.

## Executable Material Contract

Static materials still work exactly as they do today.

Executable materials add one optional `runtime` block to the material frontmatter.

Example:

```yaml
---
id: addition_and_subtraction_facts_to_10_drill
type: drill
stage_ids:
  - addition_and_subtraction_facts_to_10
skill_ids:
  - number_bonds_within_10
  - add_within_10
  - subtract_within_10
estimated_minutes: 6
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: mixed_add_sub_to_10
  parameters:
    operations: [addition, subtraction]
    range_max: 10
    item_forms: [equation, missing_number]
    question_count: 14
    allow_negative_answers: false
  scoring:
    target_accuracy: 0.85
    max_duration_seconds: 180
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 20
    minimum_family_count: 2
    max_duration_seconds: 180
---
```

Recommended contract fields:

- `engine_id`: the approved backend engine
- `spec_version`: schema version for validation
- `template_id`: the named generator template inside that engine
- `parameters`: limits for generation, item forms, timing, and batch size
- `scoring`: the target for this one run
- `readiness`: representative-practice thresholds for becoming ready for a check

This keeps the content expressive without letting content become code.
Persistence is intentionally not authored: the control plane stores compact evidence and never a long-lived raw response log.

## Runtime Objects

These are runtime objects, not new authoring objects.

### Activity Instance

An activity instance is one executable run of one session material for one learner.

It should contain at least:

- `activity_instance_id`
- `session_id`
- `session_material_id`
- `material_id`
- `engine_id`
- `template_id`
- `run_mode`
- `generation_context`
- immutable generated plan
- `render_model`
- `issued_at`
- `expires_at`

The `render_model` should contain only trusted UI primitives such as:

- equation input
- missing-number input
- multiple choice
- flash card or timed prompt

That lets Flutter render live activities without evaluating code.

### Activity Summary

When the learner completes the activity, the backend should score it and produce a summary such as:

- attempted count
- correct count
- accuracy
- duration seconds
- completion reason
- compact fact and family results
- exact correction records for incorrect responses
- skill-level evidence summary

This summary becomes part of session evidence.

## Session Lifecycle

For executable materials, use this flow.

1. Parent assigns a playlist to a learner.
2. The assignment creates scheduled sessions from the playlist session pattern.
3. When the learner opens a session with an executable material, the client asks the backend to start that activity.
4. The backend validates the material runtime block, generates an activity instance, and returns a trusted render model.
5. The learner works locally in the client.
6. The client submits the completed response set once.
7. The backend scores the result, returns corrections, and persists compact fact and family evidence.
8. Readiness, confirmation, and review-due state update independently.

For early versions, avoid per-answer save calls during the activity. One start call and one complete call are enough.

## API Direction

Keep the API shape simple.

### Browse and assignment payloads

The current library bundle already contains playlist session structure on the backend through `playlist.session_pattern.sessions`.

That is the first thing the frontend should expose for browse and assignment.

Do not try to reconstruct session plans from markdown body text.

Near-term direction:

- keep `GET /api/v1/library`
- expose `session_pattern.sessions` in the Flutter `PlaylistInfo` model
- render playlist sessions and material links directly from structured data

The generic document endpoint can keep serving markdown body for reading, but it is not sufficient as the only source for playlist inspection.

### Activity endpoints

Use narrow endpoints for executable materials:

- `POST /api/v1/sessions/{session_id}/materials/{session_material_id}/start`
- `POST /api/v1/activity-instances/{activity_instance_id}/complete`
- `POST /api/v1/activity-instances/{activity_instance_id}/retry`
- `POST /api/v1/review-items/{review_item_id}/start`

The start response returns the activity instance and render model.

The complete request sends the learner responses for scoring. The backend uses them for that request, returns any immediate corrections, and persists only the compact evidence required by the product.

## What To Persist

Persistence is minimal and useful.

Persist:

- assignment
- scheduled session
- session lifecycle status
- run status and run outcome
- notes from the adult if provided
- score summary
- duration summary
- readiness and skill evidence summary
- fact and family progress summaries such as "teen facts" or "bonds to 10"
- review cadence and launch target

Do not persist:

- every keystroke
- every intermediate answer event
- long-lived full response logs

This is a fixed product policy. Authored materials cannot enable raw response logging.

## Parent-Facing Browse And Assign Flow

The parent needs to understand the teaching block before assigning it.

The browse surface should therefore show three levels clearly.

### Pathway page

Show:

- pathway purpose
- ordered playlists in sequence
- entry guidance
- what comes next after each playlist

### Playlist detail

Show:

- playlist purpose
- completion rule
- ordered session list
- materials used in each session
- material kind for each item: teaching note, practice routine, drill, quick check
- estimated minutes per material and rough total for the playlist
- skills covered

This is the level where the parent decides whether to assign.

### Assignment flow

The assignment form should include:

- learner
- playlist
- start date
- target sessions per week
- target minutes per session
- optional due date
- optional parent note

That is enough to support "assign it to a child and set targets" without inventing a complex planning system.

## Handling Supporting Materials

Supporting material should not float around ambiguously.

Use one of these two rules:

- if the material is required during a session, reference it directly in that session
- if the material is background guidance for adults only, label it as reference guidance and keep it outside the assignable session flow

That keeps the playlist readable and stops the parent from guessing whether a material matters for assignment.

## Starter Engine For Arithmetic Fact Fluency

Start with one engine, not a general-purpose plugin system.

Recommended first engine:

- `arithmetic_fact_fluency.v1`

Current templates include:

- `readiness_within_5`
- `mixed_add_sub_to_10`
- `mixed_add_sub_to_20`
- `anchor_facts_to_20`
- `bridge_through_10_addition`
- `bridge_through_10_subtraction`
- `multiplication_tables_to_10`
- `division_facts_from_tables`

Useful parameter families:

- allowed operations
- max total or max operand
- whether missing-number items are allowed
- whether inverse-family items are allowed
- question count
- time limit
- allowed item forms
- run mode and backend-selected fact or family focus

This is enough to cover the first three arithmetic playlists without overbuilding.

## Extending The Rollout

New executable materials should reuse the current runtime when their items fit an existing typed template. Add a template only when candidate construction or the representative-coverage blueprint is genuinely different. Add a new engine only when the learner interaction or scoring model changes.

Every rollout must prove the same complete loop: authored validation, balanced practice, representative check, immutable start and completion, compact evidence, correction and retry, review launch, and parent-visible mastery.
