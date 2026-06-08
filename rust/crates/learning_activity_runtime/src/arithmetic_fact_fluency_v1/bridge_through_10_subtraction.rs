use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, parameter_string,
    parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "bridge_through_10_subtraction";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/bridge_through_10_subtraction";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let difficulty = parameter_string(runtime, "difficulty").unwrap_or_else(|| "basic".to_string());
    let mut rng = ActivityRng::new(seed);
    let items = generate_unique_items(item_count, 18, &mut rng, |index, rng| {
        let whole = if difficulty == "advanced" {
            rng.range_inclusive(12, 19) as i32
        } else {
            rng.range_inclusive(11, 17) as i32
        };
        let to_ten = whole - 10;
        let max_rest = (9 - to_ten).max(1) as u32;
        let rest = rng.range_inclusive(1, max_rest) as i32;
        let part = to_ten + rest;

        integer_item(
            index,
            format!("{whole} - {part} ="),
            whole - part,
            "bridge_through_10_for_subtraction",
        )
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Step back to 10 first, then subtract the rest.".to_string(),
        items,
    ))
}
