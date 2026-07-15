---
id: doubles_and_add_10_drill
type: drill
stage_ids:
  - doubles_and_add_10
skill_ids:
  - recall_doubles_to_20
  - add_10_to_single_digits
estimated_minutes: 6
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: anchor_facts_to_20
  parameters:
    question_count: 14
    modes:
      - double
      - add_10
  scoring:
    target_accuracy: 0.85
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 16
    minimum_family_count: 2
---

# Doubles And Add 10 Drill

Start the live drill after the lesson note and guided practice. Keep doubles and add-10 facts balanced.
