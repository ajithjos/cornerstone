use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, parameter_string,
    parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "bridge_through_10_addition";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/bridge_through_10_addition";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let difficulty = parameter_string(runtime, "difficulty").unwrap_or_else(|| "basic".to_string());
    let mut rng = ActivityRng::new(seed);
    let items = generate_unique_items(item_count, 16, &mut rng, |index, rng| {
        let (left_min, left_max) = if difficulty == "advanced" { (5, 9) } else { (6, 9) };
        let left = rng.range_inclusive(left_min, left_max) as i32;
        let needed = 10 - left;
        let max_leftover = (9 - needed).max(1) as u32;
        let leftover = rng.range_inclusive(1, max_leftover) as i32;
        let right = needed + leftover;

        integer_item(
            index,
            format!("{left} + {right} ="),
            left + right,
            "bridge_through_10_for_addition",
        )
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Make 10 first, then add the leftover part.".to_string(),
        items,
    ))
}