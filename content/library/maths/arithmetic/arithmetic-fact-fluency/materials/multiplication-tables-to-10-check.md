---
id: multiplication_tables_to_10_check
type: quick_check
stage_ids:
  - multiplication_tables_to_10
skill_ids:
  - recall_multiplication_facts_to_10
  - use_commutativity_for_multiplication
estimated_minutes: 8
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: multiplication_tables_to_10
  parameters:
    question_count: 10
    table_min: 2
    table_max: 10
    max_multiplier: 10
    include_zero_facts: true
    include_one_facts: true
    allow_commuted: true
  scoring:
    pass_accuracy: 0.8
    max_duration_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
  gate:
    requires_ready_material_id: multiplication_tables_to_10_drill
---

# Multiplication Tables Through 10 Assessment

Start the live assessment after the drill target is ready.
