---
id: bridge_through_10_addition_check
type: quick_check
stage_ids:
  - bridge_through_10_addition
skill_ids:
  - bridge_through_10_for_addition
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: bridge_through_10_addition
  parameters:
    question_count: 10
    difficulty: advanced
  scoring:
    pass_accuracy: 0.8
    soft_time_limit_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
  gate:
    requires_ready_material_id: bridge_through_10_addition_drill
---

# Bridge Through 10 Addition Assessment

This is a generated assessment. Unlock it after the learner is ready to move on from the bridge-through-`10` addition drill.

Passing guide: 8 or more quick correct answers means the learner can use make-`10` for addition in mixed order.
