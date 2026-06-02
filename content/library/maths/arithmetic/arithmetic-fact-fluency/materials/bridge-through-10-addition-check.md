---
id: bridge_through_10_addition_check
type: quick_check
stage_ids:
  - bridge_through_10_addition
skill_ids:
  - bridge_through_10_for_addition
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: bridge_through_10_addition
  parameters:
    question_count: 10
    difficulty: advanced
  scoring:
    pass_accuracy: 0.8
    soft_time_limit_seconds: 120
  persistence:
    store_response_log: false
    store_summary: true
---

# Bridge Through 10 Addition Check

```text
8 + 5 =
7 + 8 =
9 + 4 =
6 + 7 =
9 + 8 =
5 + 9 =
8 + 7 =
6 + 8 =
7 + 6 =
9 + 6 =
```

Passing guide: 8 or more quick correct answers means the learner can use make-`10` for addition in mixed order.