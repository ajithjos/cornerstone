---
id: doubles_and_add_10_check
type: quick_check
stage_ids:
  - doubles_and_add_10
skill_ids:
  - recall_doubles_to_20
  - add_10_to_single_digits
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: anchor_facts_to_20
  parameters:
    question_count: 10
    modes:
      - double
      - add_10
  scoring:
    target_accuracy: 0.9
    max_duration_seconds: 120
  gate:
    requires_ready_material_id: doubles_and_add_10_drill
---

# Doubles And Add 10 Assessment

Start the balanced check when practice is ready for check.
