mod anchor_facts_to_20;
mod bridge_through_10_addition;
mod bridge_through_10_subtraction;
mod division_facts_from_tables;
mod mixed_add_sub_to_10;
mod mixed_add_sub_to_20;
mod multiplication_tables_to_10;
mod readiness_within_5;
mod shared;

use super::RuntimeProgramRegistration;

const ENGINE_ID: &str = "arithmetic_fact_fluency.v1";

pub const PROGRAMS: &[RuntimeProgramRegistration] = &[
    RuntimeProgramRegistration {
        runtime_id: readiness_within_5::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: readiness_within_5::TEMPLATE_ID,
        generate: readiness_within_5::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: anchor_facts_to_20::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: anchor_facts_to_20::TEMPLATE_ID,
        generate: anchor_facts_to_20::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: bridge_through_10_addition::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: bridge_through_10_addition::TEMPLATE_ID,
        generate: bridge_through_10_addition::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: bridge_through_10_subtraction::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: bridge_through_10_subtraction::TEMPLATE_ID,
        generate: bridge_through_10_subtraction::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: multiplication_tables_to_10::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: multiplication_tables_to_10::TEMPLATE_ID,
        generate: multiplication_tables_to_10::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: division_facts_from_tables::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: division_facts_from_tables::TEMPLATE_ID,
        generate: division_facts_from_tables::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: mixed_add_sub_to_10::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: mixed_add_sub_to_10::TEMPLATE_ID,
        generate: mixed_add_sub_to_10::generate,
        score: shared::score_integer_activity,
    },
    RuntimeProgramRegistration {
        runtime_id: mixed_add_sub_to_20::RUNTIME_ID,
        engine_id: ENGINE_ID,
        template_id: mixed_add_sub_to_20::TEMPLATE_ID,
        generate: mixed_add_sub_to_20::generate,
        score: shared::score_integer_activity,
    },
];
