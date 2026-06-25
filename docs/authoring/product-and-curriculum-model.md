# Product And Curriculum Model

Cornerstone is a direct, parent-led or coach-led learning product. It is not a gamified reward system. The point of authored curriculum is to help an adult improve a child's real skills through short, repeated, practical work.

Curriculum in Cornerstone is file-owned in the repository. That curriculum must stay useful in three places at once:

- during authoring and review
- in parent or coach-facing delivery
- in learner progress tracking

## How Authored Curriculum Is Used

Authors need to understand the delivery chain that their work feeds:

1. Adults browse curriculum by subject and area.
2. Adults choose a pathway as the whole route.
3. A playlist becomes an assignment for one learner.
4. An assignment schedules sessions.
5. Sessions use real materials.
6. Completed sessions produce evidence.
7. Evidence updates progress at the skill level.

This is why pathway, stage, skill, material, and playlist must stay distinct. If those boundaries blur, the runtime becomes harder to use and learner progress becomes less trustworthy.

## Core Curriculum Objects

Think in this order when authoring:

1. Subject
2. Area
3. Pathway
4. Stage
5. Skill
6. Material
7. Playlist

That is the smallest model that still supports planning, delivery, and learner progress.

### Subject

A subject is the top-level domain such as maths or english.

Use a subject when you need a stable navigation or reporting boundary.

### Area

An area is a coherent slice inside a subject.

Examples:

- maths -> arithmetic
- english -> reading

Use areas to keep browsing and authoring surfaces manageable.

### Pathway

A pathway is the canonical whole-route container inside one subject and area.

Use it when you need to answer questions like:

- What is the full arithmetic route for this learner?
- What comes next after this playlist?
- Where should a five-year-old, seven-year-old, or ten-year-old start?

The pathway is the contained authoring boundary for its stages, skills, materials, playlists, and entry guidance.

### Stage

A stage is a parent-facing learning progression grouping inside a pathway.

Use stage for pedagogical steps, not for age bands.

### Skill

A skill is the smallest unit tracked in learner progress.

Good skills are specific enough to practise, assess, and revisit.

### Material

A material is one reusable artifact such as a `lesson_note`, `teaching_note`, `worksheet`, `drill`, or `quick_check`.

Use `lesson_note` for the learner-facing durable reference: the textbook or notebook page the learner can return to after the session. It should contain the taught idea, reference tables or models when needed, worked examples, and the correct language for the skill.

Use `worksheet` for consumable learner practice. It should ask the learner to retrieve, write, solve, explain, or check, without duplicating the whole reference page.

Use `teaching_note` for adult-facing delivery guidance.

Each material should point back to real `skill_ids` and `stage_ids`.

### Playlist

A playlist is an ordered set of sessions that references real materials.

Use playlists for repeatable delivery. Do not hide stage or skill structure inside them.

The default playlist contract is at least one `lesson_note`, at least one practice material (`worksheet` or `drill`), and at least one `quick_check`, unless the brief explicitly marks the playlist as review-only or diagnostic.

## Supporting Runtime Context

Authors do not usually edit runtime objects directly, but they should know how the product uses authored curriculum.

- Team: the learning team.
- User: one person in the team.
- Learner: a user who receives assignments.
- Assignment: one learner's live use of one playlist over time.
- Session: a scheduled unit of work inside an assignment.
- Evidence: the recorded outcome of a completed session.
- Progress: the learner's current state for each skill, derived from evidence.

## Relationship Model

- A subject contains one or more areas.
- An area contains one or more pathways.
- A pathway contains stages, skills, materials, playlists, and entry guidance.
- A stage groups a meaningful set of skills.
- A material supports one or more skills and one or more stages.
- A playlist sequences materials into sessions for delivery.
- An assignment instantiates one playlist for one learner.
- A session produces evidence.
- Evidence updates progress.

## Canonical Files

- `content/library/registry.yaml`
- `content/library/{subject}/{area}/{pathway}/pathway.md`
- `content/library/{subject}/{area}/{pathway}/stages/*.md`
- `content/library/{subject}/{area}/{pathway}/skills/*.md`
- `content/library/{subject}/{area}/{pathway}/playlists/*.md`
- `content/library/{subject}/{area}/{pathway}/materials/*.md`

The brief stays in `docs/authoring/examples/` as the planning source. The canonical authored curriculum lives under `content/library/`.

## Recommended Authoring Order

1. Fill in the [Curriculum slice brief template](./curriculum-slice-brief-template.md).
2. Define the subject, area, learner context, and desired outcome.
3. Author the pathway as the whole route.
4. Group the work into stages.
5. Draft the real skills for each stage.
6. Plan and write the materials.
7. Assemble one or more playlists.
8. Add entry guidance for approximate age or current readiness.

## Sizing Guidance

- Start with one subject, one area, and one pathway at a time.
- A stage should be meaningful to a parent, not just to the database.
- A skill should be small enough to practise repeatedly and assess clearly.
- A material should be reusable in more than one playlist when practical.
- A playlist should be short enough to assign confidently and easy to replace if it is not working.

## Naming Rules

- Use the final names everywhere: subject, area, pathway, stage, skill, material, playlist.
- Do not reintroduce aliases such as `capability`, `milestone`, `resource`, `program`, `checkpoint`, or `plan template`.
