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
    target_accuracy: 0.9
    max_duration_seconds: 120
  gate:
    requires_ready_material_id: fact_families_to_10_drill
---

# Fact Families Through 10 Assessment

Start the balanced check when practice is ready for check.
