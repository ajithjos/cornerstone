# Product and curriculum model

Cornerstone is a direct, practice-first, parent-led learning product. Author the explanation children can study, the practice they can repeat and the checkpoint that establishes completion. Add useful teaching guidance for the owner without repeating the learner page.

A pathway is the complete route. A playbook (stored as `playlist`) is the assignable block. Materials are reusable content and executable activity declarations within its explicit sections. Skills are the units of evidence; stages group the progression. Subject and area remain browsing boundaries.

## Canonical playbook

```yaml
id: fact_families_to_10
title: Fact Families Through 10
stage_ids: [fact_families_to_10]
skill_ids: [compose_numbers_to_10, subtract_within_10_from_known_facts]
recommended_age_min: 7
recommended_age_max: 10
sections:
  teach:
    - arithmetic_fact_fluency_teaching_context
    - addition_subtraction_foundations_teaching_note
  learn:
    - fact_families_to_10_lesson_note
  practice:
    - fact_families_to_10_drill
  checkpoint:
    - fact_families_to_10_check
```

All four section keys are required. Learn, Practice and Checkpoint must have material references; Teach can be empty when no extra adult guidance is useful. Each referenced material must retain valid pathway, stage and skill ownership. A material must belong to at least one playbook section. Authored `sessions` are not accepted.

Section membership is explicit. `teaching_note` belongs to Teach; `lesson_note` to Learn; `worksheet` and `drill` to Practice; `quick_check` to Checkpoint. These kinds describe authored content. The learner interface presents the section names instead of exposing kind names and internal execution sessions as competing navigation concepts.

The loader compiles one execution reference per learner material. Shared Teach material is available to the owner throughout the playbook. This storage detail does not create a learner teaching task.

## Materials and runtime

Learn is a durable page: concise explanation, required tables, worked examples and precise language. Practice asks for retrieval, writing, solving or explaining. Teach contains teaching choices, misconceptions, correction prompts and answer keys. Checkpoint states its independent performance target.

An executable material selects a validated Rust runtime and optionally a separately delivered presentation package. Practice and checkpoints can use the same engine/template with different generation and scoring contracts. Paper checkpoints declare `checkpoint: {question_count, target_accuracy, max_duration_seconds?}` instead of an executable runtime.

## Completion and evidence

Assign whole playbooks. Reopening unfinished generated work resumes it; requesting another completed practice creates a fresh set. All checkpoint targets must be met for the assignment to complete. Failed checks remain repeatable. Practice results, checkpoint completion and broad skill confirmation are separate facts.

See [the product definition](../architecture/learning-product-definition.md), [delivery contracts](../architecture/delivery-workspace-contract.md), [practice quality](../architecture/practice-quality-contract.md), and [activity packages](./activity-packages.md).
