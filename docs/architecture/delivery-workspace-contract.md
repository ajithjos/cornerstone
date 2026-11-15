# Delivery workspace contract

The product contract is [Teach, Learn, Practice, Checkpoint](./learning-product-definition.md). Both the owner library and assigned learner work expose the same ordered playbook structure.

## Sections

`PlaylistWorkspaceSummary.sections` and `LearnerAssignedJourneySummary.sections` contain:

```json
{
  "section_id": "practice",
  "title": "Practice",
  "description": "Choose a level. Practise with fresh questions as often as needed, on screen or on paper.",
  "items": [{
    "material_id": "written_addition_2_by_1",
    "session_index": 3,
    "session_id": null,
    "session_material_id": null
  }]
}
```

Library item references resolve to the existing playlist session/material payload. Assigned item references additionally contain the concrete `session_id` and `session_material_id` used for launch and recording. These are execution references, not another navigation hierarchy. Backend section order and membership are authoritative.

Owner responses contain `teach`, `learn`, `practice`, `checkpoint`. Learner responses omit `teach` and adult material bodies from every nested session and continue block. Library and raw learner-detail endpoints require the active owner's permissions; an authenticated owner currently using a learner profile does not bypass that boundary.

## Materials and actions

Material payloads carry `audience`, `printable`, executable runtime capability and optional `activity_level_id`. Written level IDs support contextual generation/printing without leaving the playbook. A checkpoint additionally carries:

```json
{"question_count":6,"target_accuracy":1.0,"max_duration_seconds":null}
```

The UI renders those rules. It does not infer passing, readiness or assessment scope from prose or material filenames. Owner answer keys remain restricted by the print endpoint; learners may generate blank practice sheets.

## Assigning and reviewing

`POST /api/v1/assignments` accepts `learner_id`, `playlist_id` and optional `start_date`. There is no direct-material assignment alternative. Every assign action explicitly chooses a learner.

The owner can preview a playbook, read Teach, print and assign. Opening a learner's assigned playbook adds that learner's results to the same four-section view. Recording paper work targets the selected checkpoint's session; it does not record whichever older session happens to be first.

Assignment progress is checkpoint-owned: `checkpoint_count`, `completed_checkpoint_count`, `completion_percent`, and `status`. A failed generated or paper checkpoint produces evidence while remaining unfinished. Repeating practice is always separate from passing a checkpoint.

## Learner pathway map

`LearnerWorkspaceResponse.pathway_catalog` supplies the first page of the learner’s pathway overview. It defaults to assigned pathways when any exist, otherwise all pathways. `GET /api/v1/learners/{learner_id}/pathways?scope=assigned|all&query=...&page=...` performs search (including playbook titles), scoping and fixed 12-item pagination in Rust. Counts and progress labels are explicit response fields. The catalogue contains summaries only; it does not send every pathway’s sequence or material bodies.

`GET /api/v1/learners/{learner_id}/pathways/{pathway_id}` returns one ordered pathway and its playbook map, including unassigned steps. Each playbook carries `assignment_id`, `can_open`, `status`, and `progress_label`. Unassigned steps contain public title/description metadata only, with `can_open: false`; they expose no Teach material or activity launch authority. Both endpoints enforce learner and team scope.

The learner journey is My learning → pathway → playbook → Learn / Practice / Checkpoint. The home catalogue remembers its page and search while a pathway is explored. The open playbook keeps a compact pathway sequence alongside it on wide screens, and a pathway breadcrumb on small screens. Returning from an activity restores the selected section and practice level. Flutter renders backend eligibility and ordering; it never infers access from catalogue visibility.

## Owner activity preview

Owners can try every executable Practice and Checkpoint material directly from the library, using the same generator, package, checking and scoring as learners. `POST /api/v1/library/materials/{material_id}/preview` returns a fresh seed, a plan revision and the public presentation. The corresponding `/preview/check` and `/preview/complete` endpoints accept that seed/revision and responses. These stateless operations never create assignments, activity instances, evidence or learner progress. A changed plan revision requires reopening the preview. Checkpoint previews give feedback only after submission. Active learner profiles cannot call preview endpoints.

Practice and Checkpoint use one compact level selector and one action area on both owner and learner surfaces. Written practice defaults to nine generated questions; authored checkpoint targets remain independent. New runs use new random seeds. An unfinished assigned attempt resumes its existing plan, preserving consistent scoring.
