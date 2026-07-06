---
id: division_facts_from_tables_check
type: quick_check
stage_ids:
  - division_facts_from_tables
skill_ids:
  - derive_division_facts_from_multiplication
  - check_division_facts_with_multiplication
estimated_minutes: 8
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: division_facts_from_tables
  parameters:
    question_count: 10
    divisor_min: 2
    divisor_max: 10
    max_quotient: 10
    include_zero_dividend: true
  scoring:
    pass_accuracy: 0.8
    max_duration_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
  gate:
    requires_ready_material_id: division_facts_from_tables_drill
---

# Division Facts From Tables Assessment

Start the live assessment after the drill target is ready.
