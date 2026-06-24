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

# Doubles And Add 10 Drill

Use this once the learner can already say the facts from the page.

Keep the drill short. The point is immediate recognition of anchor facts, not long endurance work.
