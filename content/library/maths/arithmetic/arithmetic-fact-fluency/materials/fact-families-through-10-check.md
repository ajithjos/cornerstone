---
id: fact_families_to_10_check
type: quick_check
stage_ids:
  - fact_families_to_10
skill_ids:
  - compose_numbers_to_10
  - subtract_within_10_from_known_facts
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: mixed_add_sub_to_10
  parameters:
    question_count: 10
    operations:
      - addition
      - subtraction
    item_forms:
      - equation
    min_total: 1
    max_total: 10
    allow_zero: true
  scoring:
    pass_accuracy: 0.8
    soft_time_limit_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
---

# Fact Families Through 10 Check

Keep this short and calm.

1. `0 + 7 =`
2. `5 + 3 =`
3. `9 - 4 =`
4. `10 - 0 =`
5. `1 - 1 =`
6. `6 + 0 =`
7. `7 - 7 =`
8. `2 + 6 =`
9. `10 - 3 =`
10. `4 + 4 =`

Passing guide: 8 or more quick correct answers means the learner is ready for the next anchor facts.