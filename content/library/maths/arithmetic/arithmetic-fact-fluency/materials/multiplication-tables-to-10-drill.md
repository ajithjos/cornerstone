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

# Multiplication Tables Through 10 Drill

Start the live drill after the paper practice is secure.
