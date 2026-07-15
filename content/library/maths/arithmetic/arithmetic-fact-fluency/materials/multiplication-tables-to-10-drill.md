---
id: multiplication_tables_to_10_drill
type: drill
stage_ids:
  - multiplication_tables_to_10
skill_ids:
  - recall_multiplication_facts_to_10
  - use_commutativity_for_multiplication
estimated_minutes: 7
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: multiplication_tables_to_10
  parameters:
    question_count: 14
    table_min: 2
    table_max: 10
    max_multiplier: 10
    include_zero_facts: true
    include_one_facts: true
    allow_commuted: true
  scoring:
    target_accuracy: 0.85
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 28
    minimum_family_count: 9
---

# Multiplication Tables Through 10 Drill

Start the live drill after the lesson note and guided practice. Balance table coverage and replay weak facts.
