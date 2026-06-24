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
    pass_accuracy: 0.8
    max_duration_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
  gate:
    requires_ready_material_id: doubles_and_add_10_drill
---

# Doubles And Add 10 Assessment

This assessment opens after the practice target is ready. Work steadily and carefully.

Passing guide: 8 or more quick correct answers means the anchor facts are ready to support make-`10` work.
