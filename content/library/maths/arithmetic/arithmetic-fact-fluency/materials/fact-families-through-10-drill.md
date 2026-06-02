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
    soft_time_limit_seconds: 150
  persistence:
    store_response_log: false
    store_summary: true
---

# Fact Families Through 10 Drill

Use this once the learner can already say most facts on paper.

The drill should mix addition and subtraction through `10`, including zero facts, so the learner must recognise the family instead of following a chant.