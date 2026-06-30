# Authoring Rules

These rules apply whether the work is being done by a human author, subject expert, teacher, contractor, LLM, or AI agent.

## Source Of Truth

- Treat `content/library/registry.yaml` and pathway-contained files under `content/library/{subject}/{area}/{pathway}/` as the source of truth for cleaned curriculum slices.
- Reuse existing objects when that is clearly better than creating duplicates.

## Required Vocabulary

Use these curriculum names:

- Subject
- Area
- Pathway
- Stage
- Skill
- Material
- Playlist

Know these runtime names:

- Team
- User
- Learner
- Assignment
- Session
- Evidence
- Progress

Do not reintroduce old aliases such as `capability`, `milestone`, `resource`, `program`, `checkpoint`, or `plan template`.

## Tone And Teaching Stance

- Write in a calm, direct, practice-first tone.
- Sound like an honest adult who wants real improvement, not like a hype system.
- Prefer observable actions, clear checks, and steady repetition.
- Do not use sugary praise, filler encouragement, or theatrical motivation.
- Do not hide weak work behind soft language.

## Family And Cultural Context

- Author ordinary examples and background tone so they fit naturally inside a Christian and specifically Catholic family or school context when that context is relevant.
- Treat that as background context, not as a command to turn ordinary maths or reading materials into explicit religious instruction.
- When an example needs people, prefer ordinary traditional names and family roles that fit that context naturally.
- Use family language such as boy, girl, brother, sister, mother, and father when the example genuinely needs those roles.
- Keep examples modest, sincere, and family-centred rather than trendy, stylised, or culture-war coded.
- Do not add sectarian comparison, political commentary, or forced devotional language unless the brief explicitly asks for it.
- In authored examples and stories, use specific named people or `he or she` when a singular generic person must be described. Do not use the singular "they" for individuals in the curriculum unless the reference is to an actual group of people.
- In stories and examples, prefer traditional family and household contexts when they are natural and helpful, but do not force every example into a family context if that would feel unnatural or confusing.
- Do not generate or promote content that promote or describe non-traditional family structures, non-traditional gender roles, or non-traditional relationships.

## Pedagogy Policy

- Define teaching style with concrete instructional rules, not with vague national, regional, or political labels.
- Prefer explicit instruction for new arithmetic content: state the idea clearly, show a worked example, then practise it.
- Use representations such as number bonds, fact families, place-value partitioning, arrays, and equal groups when they reduce errors and make later arithmetic easier.
- Keep conceptual explanation short and useful. Theory exists to support accurate performance, not to replace it.
- Build fluency deliberately with mixed practice, retrieval, cumulative review, and fast correction of weak spots.
- Introduce standard written methods once the learner can explain the structure underneath them.
- Treat age guidance as an entry hint, not as a rule that blocks a learner from the right starting point.
- Do not delay real arithmetic behind long discovery-only activities, reflective journaling, or motivational padding.
- Do not introduce a drill or check before the learner has seen a direct teaching step.
- Do not generate multiple competing strategies for the same small skill unless the brief explicitly calls for comparison.

## Arithmetic-Specific Guidance

- Number bonds are a useful arithmetic tool, not a region-specific ideology. Use them because they strengthen recall, inverse reasoning, and later written methods.
- Fact families are useful when they help the learner connect addition to subtraction and multiplication to division.
- Place value should be explicit early. Do not teach written addition, subtraction, multiplication, or division as empty symbol shuffling.
- Mental methods and written methods should support each other. Do not present them as rival systems.
- Use concise explanation, then repetition, then mixed review. Do not overbuild theory pages that delay practice.

## Curriculum Structure Rules

- Keep ids in `snake_case`.
- Keep subject and area explicit in the registry and pathway frontmatter.
- Track learner progress at the skill level, not at the material level.
- Use pathway as the contained authoring boundary for one whole route.
- Use stages to group related skills in parent-facing language.
- Use stages for learning progression, not for age bands.
- Use materials as reusable learner or adult delivery artifacts.
- Use playlists as ordered session plans that reference real materials.
- Keep stage, skill, playlist, and material files inside `content/library/{subject_id}/{area_id}/{pathway_id}/`.
- Do not hide curriculum structure inside playlists.
- Do not invent compatibility aliases or parallel schema.
- Do not add a separate pathway YAML file unless the metadata truly no longer fits the pathway document.
- Do not add placeholder materials that will never be used.

## Material Quality Rules

- Materials should be usable in a real session by a parent, teacher, or coach.
- Prefer concrete prompts, examples, checks, and adaptations over abstract guidance.
- Write for repeatable use, not for a one-time demo activity.
- Treat `lesson_note` as the durable learner reference or textbook page. It may include full fact tables, models, definitions, and worked examples when those are what the learner needs to revisit.
- Treat `worksheet` as consumable practice for paper, offline work, or A4 printing. It should be lighter than the lesson note and should not duplicate the full reference content unless the task is explicitly to copy or reconstruct it from memory.
- Keep print-focused worksheets compact and repeatable: include learner/date lines when useful, clear sections, enough writing space, and a brief coach check. Do not turn them into decorative posters or duplicate the entire lesson note.
- Keep material metadata in the material file itself. Do not duplicate it in a separate material index.
- Make review and recap deliberate when the slice needs them; do not leave reinforcement to chance.
- For arithmetic, every material should make the teaching move clear: what is being taught directly, what is being practised, what counts as secure, and what mistake pattern should trigger reteaching.
- When a material uses named examples, choose names and family details deliberately instead of using random contemporary filler.

## Required Material Kind Contract

- Use canonical material kind names exactly in authored content and downstream APIs.
- `lesson_note` is the learner-facing explanation and durable reference material for what is being learned.
- `teaching_note` is adult-facing guidance for prompts, misconceptions, and delivery choices.
- `worksheet` is learner practice for paper, offline work, or printing; it is not the primary reference page.
- `drill` is repetitive or live learner practice.
- `quick_check` is a short learner check or stop point.
- Do not use `teaching_note` as a substitute for learner-facing instruction.
- Do not use `drill` or `quick_check` as the learner's first exposure to a new skill cluster.
- The default playlist contract is at least one `lesson_note`, at least one practice material (`worksheet` or `drill`), and at least one `quick_check`.
- Include `teaching_note` when the playlist depends on adult mediation beyond the learner-facing `lesson_note`.
- Review-only or diagnostic playlists are allowed, but that exception must be explicit in the brief.

## Validation Rules

- Every active pathway must contain real downstream curriculum, not just a top-level pathway document.
- Every skill must appear in at least one stage, one material, and one playlist session.
- Every stage must be used by at least one material and one playlist.
- Every material file inside a pathway must be used by at least one playlist session unless it is clearly marked as a reference note in the pathway.
- Session materials must match the session skills and stay within the playlist's pathway and stages.
- Every non-diagnostic playlist must include at least one `lesson_note`, at least one practice material (`worksheet` or `drill`), and at least one `quick_check`.
- Skills checked in a `quick_check` or practised in a standalone `drill` must already appear in a prior `lesson_note` or guided instruction step.
- Entry guidance must point to real playlists.

## Validation Commands

- Run `uv run --with pytest python -m pytest tests/test_pathway_library.py` while iterating on the cleaned pathway tree.
- Run `make rust-library-validate` and `make content-validate` when you want the runtime-facing validation pass for the library tree.
- Validate the full in-scope pathway after any slice change.

## Review Checklist

Before accepting authored output, check that:

1. every referenced `skill_id` exists
2. every referenced `stage_id` exists
3. every playlist references real materials
4. subject, area, and pathway ids are consistent across the whole slice
5. every skill, stage, and material has downstream usage and no orphan remains
6. there is no stray markdown outside the owning pathway directory
7. no duplicate object exists for the same teaching job
8. all explicit constraints from the brief are respected
