---
id: division_facts_from_tables_drill
type: drill
stage_ids:
  - division_facts_from_tables
skill_ids:
  - derive_division_facts_from_multiplication
  - check_division_facts_with_multiplication
estimated_minutes: 7
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: division_facts_from_tables
  parameters:
    question_count: 14
    divisor_min: 2
    divisor_max: 10
    max_quotient: 10
    include_zero_dividend: true
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

# Division Facts From Tables Drill

Start the live drill after the paper practice is secure.
