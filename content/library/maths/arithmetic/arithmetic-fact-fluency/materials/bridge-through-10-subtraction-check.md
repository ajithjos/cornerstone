---
id: bridge_through_10_subtraction_check
type: quick_check
stage_ids:
  - bridge_through_10_subtraction
skill_ids:
  - bridge_through_10_for_subtraction
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: bridge_through_10_subtraction
  parameters:
    question_count: 10
    difficulty: advanced
  scoring:
    target_accuracy: 0.9
    max_duration_seconds: 120
  gate:
    requires_ready_material_id: bridge_through_10_subtraction_drill
---

# Bridge Through 10 Subtraction Assessment

Start the balanced check when practice is ready for check.
