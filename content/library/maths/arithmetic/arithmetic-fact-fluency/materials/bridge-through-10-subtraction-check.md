---
id: bridge_through_10_subtraction_check
type: quick_check
stage_ids:
  - bridge_through_10_subtraction
skill_ids:
  - bridge_through_10_for_subtraction
estimated_minutes: 5
runtime:
  engine_id: arithmetic_fact_fluency.v1
  spec_version: 1
  template_id: bridge_through_10_subtraction
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

# Bridge Through 10 Subtraction Check

```text
13 - 5 =
15 - 8 =
17 - 9 =
14 - 6 =
18 - 9 =
16 - 7 =
19 - 8 =
12 - 4 =
15 - 6 =
17 - 8 =
```

Passing guide: 8 or more quick correct answers means the learner can use bridge-through-`10` subtraction in mixed order.