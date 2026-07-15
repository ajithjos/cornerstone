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
    target_accuracy: 0.85
  readiness:
    minimum_runs: 3
    recent_run_window: 3
    target_accuracy: 0.85
    consecutive_target_runs: 2
    target_correct_count: 12
    minimum_distinct_items: 24
    minimum_family_count: 9
---

# Division Facts From Tables Drill

Start the live drill after the lesson note and guided practice. Mix divisors while replaying weak fact families.
