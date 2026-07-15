# Practice Quality Contract

This document defines the backend-owned contract for live practice, checks, correction, mastery evidence, and review.

The product must not use one status word for several different facts. Session lifecycle, run outcome, skill state, and review state are separate domains.

## Explicit Status Domains

### Session lifecycle

`session_status` describes scheduling and completion only.

- `scheduled`: the session has not started
- `active`: work in the session has started
- `completed`: the session was finished and submitted

Completing a session never means that its skills are confirmed.

### Activity run lifecycle

`run_status` describes one generated activity instance.

- `in_progress`: the immutable activity plan has been issued and may be submitted once
- `finished`: the activity was scored and closed

### Run outcome

`run_outcome` describes whether one finished run met its authored target.

- `target_met`
- `target_not_met`

The learner-facing label depends on the run mode:

- practice or review: `Practice target met` / `Keep practising`
- check: `Check passed` / `Check not yet passed`

### Skill state

`skill_status` is the learning-state contract.

- `not_started`: derived when no evidence exists
- `needs_practice`: evidence exists, but representative practice is not ready for a check
- `ready_for_check`: practice has met its accuracy and coverage requirements
- `confirmed`: a representative check met its target

Only a representative check may produce `confirmed`.

### Review state

`review_status` is separate from skill state.

- `not_due`
- `due`

A confirmed skill may become due for review without being relabelled as never learned. A failed review can move the skill back to `needs_practice`.

## Run Modes

Every generated activity has one explicit mode.

- `practice`: balanced practice with a bounded allocation for weak or overdue facts and deliberate preference for unseen facts in the remaining slots
- `check`: fixed representative coverage; never adapted to hide weak material
- `review`: targeted retrieval of due facts while retaining a small mixed component
- `retry`: a short immediate correction run containing missed facts from one finished run

## Selection Rules

Randomness is allowed only inside a pedagogically defined batch blueprint.

Every runtime template must:

- enumerate a validated candidate pool
- assign every candidate a stable `fact_key`
- assign one or more stable `family_keys`
- assign a concrete difficulty band
- select without semantic duplicates
- meet the run-mode coverage blueprint
- remain deterministic from the immutable activity plan

Practice may prioritise recent weak facts. Checks must be representative and comparable across learners and runs.
Across practice runs, the control plane supplies attempted fact keys so the runtime can build required distinct coverage deliberately rather than leaving readiness to seed luck.

## Immutable Activity Instances

The control-plane persists the generated plan before returning it to Flutter.

The stored instance owns:

- activity instance id
- learner, session, session material, and material identity
- run mode and run status
- generated plan and scoring target
- optional review or retry origin
- start and finish timestamps

Completion scores the stored plan. It must not regenerate an adaptive run from current mutable learner state.

## Evidence Contract

Persist compact evidence that supports a learning decision:

- run counts, accuracy, duration, and outcome
- distinct fact coverage
- per-fact attempted and correct counts
- per-family attempted and correct counts
- consecutive correct evidence and last-seen dates

Do not persist keystrokes or a permanent raw response log.
This is a fixed product policy; authored materials cannot enable raw response logging.

The completion response may return current-run corrections containing the prompt, submitted response, expected response, stable fact and family keys, and a concise correction cue. These corrections support immediate retry without becoming the long-term evidence model.

## Readiness And Confirmation

An authored drill may declare `runtime.readiness` with:

- `minimum_runs`
- `recent_run_window`
- `target_accuracy`
- `consecutive_target_runs`
- optional `target_correct_count`
- `minimum_distinct_items`
- `minimum_family_count`
- optional `max_duration_seconds`

`ready_for_check` requires both performance and representative coverage. Run accuracy alone is insufficient.

A check can confirm a skill only when:

- its stored activity plan is marked representative
- the run outcome is `target_met`
- the required families and difficulty bands were present

## Correction And Review

After a run with mistakes, the learner receives exact corrections and may start a short retry containing the missed fact keys.

Review items are stable runtime records. They include a material and activity target, not only explanatory text. A due review must be directly launchable.

Use a small deterministic cadence initially:

- unsuccessful or still-needs-practice evidence: next day
- first successful review: three days
- later successful review: seven days

Do not delete and recreate the whole review queue after every session.

## Ownership Boundary

- Authored material declares the approved runtime, target, and readiness requirements.
- The Rust activity runtime owns validated candidate construction, batch blueprints, generation, and scoring.
- The Rust control-plane owns learner context, immutable instances, evidence, status transitions, and review scheduling.
- Flutter renders the explicit contracts and never derives mastery or selection policy from raw content.
