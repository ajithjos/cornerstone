---
id: fact_families_to_10_drill
type: drill
stage_ids:
  - fact_families_to_10
skill_ids:
  - compose_numbers_to_10
  - subtract_within_10_from_known_facts
estimated_minutes: 6
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: mixed_add_sub_to_10
  parameters:
    question_count: 14
    operations:
      - addition
      - subtraction
    item_forms:
      - equation
    min_total: 1
    max_total: 10
    allow_zero: true
  scoring:
    target_accuracy: 0.85
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 20
    minimum_family_count: 2
---

# Fact Families Through 10 Drill

Start the live drill after the lesson note and guided practice. Keep addition and subtraction evidence balanced.
