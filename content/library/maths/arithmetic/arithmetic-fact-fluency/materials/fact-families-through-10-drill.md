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
    pass_accuracy: 0.85
  persistence:
    store_response_log: false
    store_summary: true
  proficiency:
    min_attempts: 20
    window_size: 20
    target_accuracy: 0.9
    consecutive_passes: 3
    target_correct_count: 13
---

# Fact Families Through 10 Drill

Start the live drill after the paper practice is secure.
