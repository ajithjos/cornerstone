# How Live Materials Work

This is the short developer explanation of how Cornerstone turns a material runtime block into a real learner activity.

If you want the exact code contract for adding or registering runtime programs, read [Runtime Program Contract](./runtime-program-contract.md). If you want the fuller architecture note, read `executable-drills-and-assignment-delivery.md`. This guide is the practical version.

## Short Answer

Yes, the normal product flow is simple:

1. A parent, teacher, or owner assigns a playlist to a learner.
2. That assignment creates scheduled sessions from the playlist session pattern.
3. If one of those session materials has a `runtime` block, the app shows it as a live item.
4. When the learner starts it, the backend generates the activity items, the client renders them, and the backend scores the completed submission.
5. The result becomes session evidence and updates skill progress.

The important rule is that authored content never executes code directly. The runtime block is only a contract that tells trusted backend code what kind of activity to generate.

## What This Does Not Mean

This part needs to be explicit.

- It does not mean Google Chrome.
- It does not mean an LLM is inventing activity items at runtime.
- It does not mean an AI agent is writing new code while the learner waits.
- It does not mean content markdown is executed like a script.

When this guide says `generate activity items from a backend seed`, it means:

- the backend creates a random seed value such as a number
- the backend passes that seed into normal Rust functions
- those Rust functions choose the exact arithmetic facts to show

So this is ordinary program execution inside the running backend service.

The word `seed` here means the starting value for deterministic random generation. It does not mean AI, LLM, or browser automation.

## What Actually Executes

The real execution path is:

1. A material markdown file declares a `runtime` block in frontmatter.
2. The catalog loader reads that block into `MaterialDocument.runtime`.
3. The library and learner APIs expose enough metadata for the UI to know that the material is executable.
4. The Flutter app calls a start endpoint for the current session material.
5. The Rust control plane selects the run mode and focus; the runtime generates a balanced or deliberately focused immutable activity plan.
6. Flutter renders those items using normal UI widgets.
7. The learner submits answers.
8. The Rust control plane scores the persisted plan, writes compact fact and family evidence, finishes the run, and returns corrections and the next action.

So the runtime block maps to real execution through a fixed backend dispatch, not through dynamic code loading.

## Where The Program Actually Lives

The program is the Rust code already compiled into the control-plane service.

Right now the live arithmetic runtime is implemented in the dedicated runtime layer:

- `rust/crates/learning_activity_runtime/src/lib.rs`
- `rust/crates/learning_activity_runtime/src/arithmetic_fact_fluency_v1/readiness_within_5.rs`
- `rust/crates/learning_activity_runtime/src/arithmetic_fact_fluency_v1/mixed_add_sub_to_10.rs`
- `rust/crates/learning_activity_runtime/src/arithmetic_fact_fluency_v1/mixed_add_sub_to_20.rs`
- `rust/crates/learning_activity_runtime/src/arithmetic_fact_fluency_v1/shared.rs`

That is the important distinction:

- content files describe which approved runtime to use
- backend code contains the actual program that runs

So if you were expecting a real program on the backend, that expectation was correct. The program is just not authored inside the content files. It is authored in Rust code and deployed as part of the control plane.

## The Main Files

These are the key handoff points.

- `content/library/.../materials/*.md`: authored materials define the optional `runtime` block.
- `rust/crates/catalog/src/lib.rs`: loads material frontmatter and carries `runtime` into the in-memory library model.
- `rust/crates/control_plane/src/http.rs`: exposes the activity start and complete endpoints.
- `rust/crates/control_plane/src/service.rs`: creates assignments, starts and completes activities, and persists results.
- `fe/flutter/apps/cornerstone/lib/services/api_service.dart`: calls the start and complete endpoints.
- `fe/flutter/apps/cornerstone/lib/ui/screens/home/home_shell.dart`: launches live activities from the current learner session.
- `fe/flutter/apps/cornerstone/lib/ui/widgets/home/activity_dialog.dart`: renders the executable activity dialog, correction, and retry flow.

## The Runtime Contract

An executable material adds a `runtime` block like this:

```yaml
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: mixed_add_sub_to_10
  parameters:
    operations: [addition, subtraction]
    item_forms: [equation, bond_missing]
    question_count: 14
  scoring:
    target_accuracy: 0.85
    max_duration_seconds: 150
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 20
    minimum_family_count: 2
    max_duration_seconds: 150
```

This is not code. It is only data.

The current control plane reads those values and decides which trusted Rust functions to run.

Today that means:

- `engine_id` selects the backend engine
- `template_id` selects the generator inside that engine
- `parameters` tune item generation
- `scoring` defines this run's target
- `readiness` defines sufficient representative practice before a check

The control plane always persists the immutable plan plus compact run, fact, and family summaries. Authored content cannot enable raw response logging.

You can think of the runtime block as a configuration record for a backend program that already exists.

It is similar to this relationship:

- content file = recipe choice and settings
- backend runtime code = the actual kitchen work

The content file says, in effect, "use the arithmetic fact fluency engine with this template and these limits." The Rust backend then performs the work.

## How Assignment Connects To Live Work

This is the part that is easy to miss.

You do not assign a runtime directly.

You assign a playlist.

The playlist already contains ordered sessions, and each session already contains material ids. One of those materials may be executable.

That means the real product rule is:

- assignment creates the learner's scheduled sessions
- the current session decides what the learner can do now
- the material inside that session decides whether the work is static or live

So yes, from the parent's point of view it is mostly as simple as assigning a playlist to a learner. The live runtime becomes available because the assigned session contains a material with a valid runtime block.

## Student And Parent Flow

Use this as the mental model.

### Parent or teacher flow

1. Open the library view.
2. Inspect the pathway, playlist, sessions, and materials.
3. Assign the playlist to a learner.
4. Open the learner's current session.
5. If the session contains a live material, start it.

### Learner flow

1. Open the current assigned session.
2. See the live material for that session.
3. Start the activity.
4. Answer the items.
5. Submit once; the run is now finished regardless of its outcome.
6. See the target outcome and correct any mistakes.
7. Retry weak material, take a check when ready, or move on as directed.

The learner does not need to know about engines, templates, or runtime contracts.

## What The Backend Does On Start

When Flutter calls the start endpoint, the backend:

1. loads the scheduled session and session material
2. finds the matching material in the library bundle
3. checks that the material has a supported runtime
4. generates activity items from a backend seed
5. persists the exact plan and returns an `activity_instance_id`, item list, instructions, and scoring summary
6. marks the session and material active

In the current arithmetic implementation, this happens in `start_session_material_activity`, which calls `generate_activity`.

This is not a long-running worker process per learner. In the current design it is a normal request-time function call inside the running backend service.

In plain words:

1. the backend receives "start this live material"
2. the backend runs Rust code immediately
3. the backend returns a JSON activity payload

That payload contains the item list, instructions, and scoring settings for that one activity instance.

## What The Backend Does On Complete

When Flutter submits the answers, the backend:

1. loads the `activity_instance_id` for the active learner
2. verifies that the instance is still `in_progress`
3. loads its persisted immutable activity plan
4. validates and scores the submitted answers against that plan
5. writes compact run, fact, and family evidence
6. marks the run `finished` and the submitted session `completed`
7. updates readiness, confirmation, and review-due state independently
8. returns exact corrections and whether an immediate retry is available

In the current arithmetic implementation, this happens in `complete_activity_instance`, which calls `score_activity` and then `persist_session_result`.

Persisting the issued plan is important because practice generation can use mutable learner evidence. Regenerating later from only a seed could otherwise produce a different batch after that evidence changes.

That means the backend does not need to keep a separate in-memory process alive for each learner activity.

## What To Do When You Add More Live Items

There are three common cases.

### 1. New live material using the existing engine

This is the simplest case.

Do this when you want more arithmetic drills or checks that still fit the existing item types and scoring model.

Steps:

1. Add a new material file with a `runtime` block.
2. Reuse an existing `engine_id` and `template_id`.
3. Adjust `parameters`, `scoring`, and `estimated_minutes`.
4. Add the material id to a playlist session.
5. Validate content.

In this case you usually do not need backend or frontend changes.

### 2. New template inside the existing engine

Do this when the runtime is still arithmetic fact fluency, but you need a new item family or generation rule.

Steps:

1. Register the new `template_id` in the activity-runtime crate.
2. Add a generator that produces typed candidate items and a run-mode coverage blueprint.
3. Make sure `score_activity` still matches the item structure.
4. Add or update authored materials to use the new template.
5. Validate the end-to-end flow.

If the items still use the current integer-response UI, Flutter may not need any changes.

### 3. New engine or new interaction type

Do this only when the current engine and item shapes are not enough.

Examples:

- multiple choice instead of integer input
- drag and drop
- sentence construction
- audio playback or recording

Steps:

1. Add backend support for the new `engine_id`.
2. Define the render model and scoring behavior.
3. Extend the activity payloads if the client needs new prompt fields.
4. Extend Flutter so it can render the new prompt type.
5. Add authored materials that use the new engine.
6. Validate with a real start and complete flow.

This is the point where you are adding a real product capability, not just more authored content.

## Who Manages What

This is the clean split.

### Content writer responsibility

Content writers can:

- create a new material file
- choose an approved `engine_id`
- choose an approved `template_id`
- set parameters such as item count, operations, or thresholds
- place that material into playlist sessions

Content writers should not:

- create a brand new backend engine in markdown
- invent new item payload shapes without code changes
- assume the frontend can render new interaction types automatically

### Developer responsibility

Developers own:

- the backend engine code
- the supported templates
- the scoring logic
- the activity payload shape
- any frontend renderer needed for new interaction types

So the management model is related, but not identical:

- content manages approved runtime configuration
- code manages runtime behavior

If one person is doing both jobs, that is fine. But they are still two kinds of work.

## A Simple Decision Rule

Use this rule before you write code.

- If the interaction is the same and only the facts or thresholds change, add content only.
- If the interaction is the same but the generation logic changes, extend the existing backend engine.
- If the interaction itself changes, extend both backend and frontend.

## What Not To Do

Avoid these mistakes.

- Do not put executable code in material markdown.
- Do not create a new top-level planning object for drills.
- Do not treat the markdown body as the source of session structure.
- Do not store every keystroke by default.
- Do not create a new runtime engine when a new material file would be enough.

## Current Working Example

The first three arithmetic playlist items are the reference example.

They show:

- executable drill materials in `content/library/maths/arithmetic/arithmetic-fact-fluency/materials/`
- playlists that schedule those materials in `content/library/maths/arithmetic/arithmetic-fact-fluency/playlists/`
- backend runtime generation and scoring in `rust/crates/learning_activity_runtime/`
- immutable-instance and learner-evidence orchestration in `rust/crates/control_plane/src/service.rs`
- frontend activity start and completion in the Flutter app

If you are unsure how to add a new live item, copy one of those three materials first and only add new backend code when the copied contract is no longer enough.
