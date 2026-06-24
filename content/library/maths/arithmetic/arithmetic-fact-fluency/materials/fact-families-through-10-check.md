---
id: fact_families_to_10_check
type: quick_check
stage_ids:
  - fact_families_to_10
skill_ids:
  - compose_numbers_to_10
  - subtract_within_10_from_known_facts
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: mixed_add_sub_to_10
  parameters:
    question_count: 10
    operations:
      - addition
      - subtraction
    item_forms:
      - equation
    min_total: 1
    max_total: 10
    allow_zero: true
  scoring:
    pass_accuracy: 0.8
    soft_time_limit_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
  gate:
    requires_ready_material_id: fact_families_to_10_drill
---

# Fact Families Through 10 Assessment

This is a generated assessment. Unlock it after the learner is ready to move on from the fact-family drill.

Passing guide: 8 or more quick correct answers means the learner is ready for the next anchor facts.
