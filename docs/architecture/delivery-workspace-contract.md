# Delivery Workspace Contract

This note defines the missing product layer between the stable curriculum model and the current app surfaces.

Cornerstone already has the right authored and runtime spine:

- pathway = the full route
- playlist = the assignable block
- session = one ordered work block inside that playlist
- material = the thing an adult or learner actually uses

The current gap is not missing curriculum.

The current gap is that the product still exposes those objects as a flat pathway browser plus a flat learner session list.

That is why the app can already assign work and launch live drills, but still feels unclear in three places:

- the assignment target is implicit instead of explicit
- the pathway browser is hard to navigate because it mixes browse, inspect, and assign in one long column
- the learner surface does not turn material roles into a clear study plan

## Findings From The Current Stack

The current repository already proves a lot.

- authored materials already carry meaningful canonical kinds such as `teaching_note`, `worksheet`, `drill`, and `quick_check`
- the current arithmetic slice still lacks a dedicated learner-facing instruction kind, so the product does not yet have a first-class artifact for "this is what the learner studies and revisits"
- `/api/v1/library/workspace` already exposes ordered playlists, sessions, material kinds, estimated minutes, and executable flags
- `/api/v1/learners/{learner_id}` already exposes the assigned journey, ordered scheduled sessions, material route paths, and runtime summaries

The missing pieces are product-derived contracts.

- the library workspace does not include per-learner assignment context, so the frontend falls back to one implicit selected learner
- the learner response does not group materials by audience or delivery purpose, so the UI still looks like a generic session list
- the frontend still has to decide too much about how to present assignment, teaching, practice, and checking

This means the next step should be a backend-derived delivery contract, not a new authoring object and not more frontend inference.

## Decisions

Use these as the working product rules.

### 1. Keep the existing curriculum model

Do not add a new top-level planning object such as program, course pack, study plan template, or resource bundle.

Keep the current model:

- subject
- area
- pathway
- stage
- skill
- material
- playlist
- assignment
- session
- evidence

The new product layer should be derived from those objects.

### 2. Keep product logic in the backend

Flutter should render explicit contracts for:

- who a playlist is recommended for
- who it is currently assigned to
- what the next learner action is
- which materials are for adult teaching versus learner practice versus checking

Flutter should not re-derive those rules from raw content payloads.

### 3. Use canonical material kinds everywhere

Keep the authored `kind` value exactly as it is, and use that same canonical value all the way through the backend and frontend.

Do not create one naming scheme for authoring and another naming scheme for UI.

Recommended default kind set:

- `lesson_note`: learner-facing explanation, model, table, worked example, or durable reference artifact for the thing being learned; this is the textbook/notebook page the learner can return to later
- `teaching_note`: adult-facing prompts, misconceptions, adaptation notes, and delivery guidance
- `worksheet`: learner practice artifact for paper or offline work; this should prompt retrieval, solving, explanation, or checking rather than duplicate the full reference page
- `drill`: repetitive or live learner practice
- `quick_check`: short learner check or stop point

If the frontend needs readable text, it should humanize the exact canonical kind value. It should not substitute a different taxonomy.

The API may still derive helper fields such as `audience`, `dominant_kind`, or `requires_adult_support`, but those helpers must not replace the canonical `kind`.

### 4. Define minimum material coverage, not just allowed kinds

The missing contract is not only a list of valid kinds.

The missing contract is the minimum delivery set that makes a playlist teachable and learnable.

Use these default boundaries:

- session = the immediate delivery boundary
- playlist = the minimum completeness boundary

Default playlist contract:

- at least one `lesson_note`
- at least one learner practice material: `worksheet` or `drill`
- at least one `quick_check`
- at least one `teaching_note` when adult guidance is needed beyond what the learner can get from the `lesson_note`

Default session contract:

- instruction session: `lesson_note` as the dominant material, with optional `teaching_note`
- practice session: `worksheet` or `drill` as the dominant material
- check session: `quick_check` as the dominant material

Guardrails:

- do not use `drill` or `quick_check` as the learner's first exposure to a new skill cluster
- a `quick_check` should confirm taught work, not introduce fresh content
- if a playlist is intentionally review-only or diagnostic, that exception should be explicit in the brief and in the contract

### 5. The assign action must choose a learner explicitly

Selecting a learner elsewhere in the app may still be useful for context, but it must not be the hidden source of truth for assignment.

The product rule should be:

- every assign action opens or reveals an explicit learner target chooser
- every playlist card shows current assignment context before the user clicks assign
- age and level guidance is advisory, not a silent hard gate

### 6. The learner surface should be a journey workspace, not only a today surface

The learner needs a stable way to answer four questions.

- What do I do next?
- Where am I in the journey?
- What can I practise now?
- How am I doing?

That should become the top-level learner workspace structure.

## Derived Product Contracts

These are derived runtime contracts, not new authored files.

### Team planning workspace

Use a dedicated parent-facing workspace payload for browse, inspect, and assign.

Recommended endpoint direction:

- extend `GET /api/v1/library/workspace` into a real planning workspace payload, or
- add `GET /api/v1/team/workspace` and keep the current library workspace as the content-only version

Required sections:

- team learner summaries
- pathway summaries
- playlist planning summaries
- explicit assignment target options per playlist
- current assignment state per learner
- document links for pathway, playlist, and material reading

Recommended per-playlist fields:

- `playlist_id`
- `title`
- `description`
- `recommended_age`
- `recommended_level`
- `delivery_shape`
- `sessions`
- `assignment_targets`
- `assigned_learners`

Recommended `delivery_shape` fields:

- `session_count`
- `estimated_total_minutes`
- `teach_material_count`
- `practice_material_count`
- `check_material_count`
- `live_material_count`

Recommended `assignment_targets` fields:

- `learner_id`
- `display_name`
- `current_age`
- `current_level`
- `eligibility`
- `reason`
- `current_assignment_state`

Suggested `eligibility` values:

- `active_here`
- `recommended_entry`
- `stretch`
- `review_ready`
- `too_early`

The exact labels can change, but the backend should choose them.

That gives the UI enough information to show:

- `Assigned to Christopher Joseph`
- `Recommended next for Margaret Joseph`
- `Stretch entry point for Johnpaul Joseph`

without relying on a hidden global learner selection.

### Session delivery block

Each session in a parent or learner workspace should expose a delivery block instead of only a flat material list.

Recommended derived fields:

- `session_id`
- `title`
- `sequence_number`
- `day_offset`
- `status`
- `materials_by_kind`
- `dominant_kind`
- `requires_adult_support`
- `completion_rule`
- `estimated_minutes`

For the current arithmetic content this will often mean one item per session, which is fine.

The point is to define the shape now so later playlists can contain more than one material without forcing the UI to guess how they fit together.

### Learner workspace

Use a dedicated learner-facing workspace payload instead of relying on a generic detail payload for every screen.

Recommended endpoint direction:

- add `GET /api/v1/learners/{learner_id}/workspace`

Required sections:

- learner summary
- workspace audience contract (`workspace_view`, `viewer_role`, `includes_adult_materials`)
- active journey summary
- continue block
- journey outline
- practice lane
- progress snapshot
- recent wins or evidence summary

### Workspace audience contract

The learner workspace endpoint must declare which audience mode is being returned.

- `workspace_view: learner` means learner-safe view only. Adult teaching material is excluded.
- `workspace_view: owner_support` means parent or teacher guidance view. Adult teaching material is included.
- `viewer_role` carries the current viewer role used for policy decisions.
- `includes_adult_materials` is the explicit rendering switch for frontend surfaces.

This keeps the boundary explicit: learner surfaces never infer policy from raw materials; they render the contract directly.

Recommended sections in more detail:

#### Continue block

This is the first screen for the learner.

It should contain:

- the next actionable session
- the learner-safe materials for that session
- simple action labels such as `Start practice`, `Open worksheet`, or `Take check`
- optional adult guidance indicator when an adult should be involved first

Use `Continue`, not `Today`, as the core label. The assignment model is ordered and scheduled, but the learner question is really about next work.

#### Journey outline

Show the current playlist as an ordered path with:

- completed sessions
- current session
- upcoming sessions
- the dominant kind of each session block and whether adult help is required

This is where the learner understands progress through the route, not just one day.

#### Practice lane

Show learner-safe practice materials that are available now, especially:

- `worksheet` materials from scheduled sessions
- `drill` materials that are unlocked for the current point in the journey
- optional review practice derived from weak groups later

Do not show adult-only teaching notes here.

#### Progress snapshot

Show:

- session completion progress
- recent evidence
- review items
- a few skill-level signals

Keep it short and readable.

## Visibility Rules

Use explicit audience rules in the derived contract.

- adult viewers can see adult and learner items
- learner viewers should not be led by adult-only teaching notes as if those were their next actions
- adult-only items should still be visible in the parent workspace, with clear labels

This is the main missing distinction behind the current feeling that teaching and learning materials are present but not actually surfaced.

## Navigation Rules

These are product decisions, not just UI styling choices.

### Parent pathway planner

Use a multi-pane planning flow.

- pane 1: pathway and learner context
- pane 2: playlist list and session outline
- pane 3: document reader and assignment panel

The user should be able to change playlist focus without losing the learner context, and open assignment without losing the playlist detail.

That is materially better than a long nested column.

### Learner workspace

Use clear destinations.

- `Continue`
- `Journey`
- `Practice`
- `Progress`

These can be tabs, sections, or shell destinations.

The important point is that the learner experience should not collapse all meaning into a single `Today` view.

## What We Should Not Do

- do not invent a separate authored study-plan file format
- do not push assignment recommendation logic back into Flutter
- do not flatten teaching notes, worksheets, drills, and checks into one undifferentiated material list
- do not make the library workspace the only contract for both parent planning and learner execution

## Implementation Order

Build this in five passes.

1. Enrich the backend planning contract with explicit assignment targets and derived delivery-shape summaries.
2. Redesign the parent pathway planner so assignment target selection happens inside the assign flow, not through an implicit selected learner.
3. Add a learner workspace payload that groups session materials by audience and role.
4. Redesign the learner shell around `Continue`, `Journey`, `Practice`, and `Progress`.
5. Add richer review and weak-skill practice lanes after the base journey workspace is stable.

## Immediate Consequence For The Current Repo

The first implementation step should not be new content authoring.

The first implementation step should be contract and UI work:

- preserve the current authored pathway, playlist, session, and material model while extending the canonical material kind set with `lesson_note`
- enrich the backend response shape so assignment context is explicit and session materials stay grouped by canonical kind
- redesign the planner and learner workspace around canonical kind coverage instead of inferred frontend labels

The content already has teaching notes, worksheets, drills, and checks.

The product now needs to surface them as a real learning journey, and new slices should add learner-facing `lesson_note` materials where that contract is currently missing.
