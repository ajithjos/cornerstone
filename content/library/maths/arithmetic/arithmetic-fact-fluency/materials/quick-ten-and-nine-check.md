---
id: quick_ten_and_nine_check
type: quick_check
stage_ids: [quick_ten_and_nine]
skill_ids: [use_ten_to_add_and_subtract_nine]
estimated_minutes: 4
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: quick_ten_and_nine
  presentation:
    package_id: numeric-questions
    version: 1.1.0
  parameters:
    question_count: 10
  scoring:
    target_accuracy: 0.9
  gate:
    requires_ready_material_id: quick_ten_and_nine_drill
---

# Quick ways checkpoint

Use the jumps in your head. Write the answer to each question.
