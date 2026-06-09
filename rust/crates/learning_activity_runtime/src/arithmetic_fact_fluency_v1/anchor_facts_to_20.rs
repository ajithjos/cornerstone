use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, parameter_string_list, parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "anchor_facts_to_20";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/anchor_facts_to_20";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let modes =
        parameter_string_list(runtime, "modes").unwrap_or_else(|| vec!["double".to_string(), "add_10".to_string()]);
    let mut rng = ActivityRng::new(seed);
    let items = generate_unique_items(item_count, 12, &mut rng, |index, rng| {
        let mode = &modes[rng.index(modes.len())];
        if mode == "add_10" {
            let addend = rng.range_inclusive(1, 9) as i32;
            integer_item(
                index,
                format!("10 + {addend} ="),
                10 + addend,
                "add_10_to_single_digits",
            )
        } else {
            let value = rng.range_inclusive(1, 10) as i32;
            integer_item(index, format!("{value} + {value} ="), value * 2, "recall_doubles_to_20")
        }
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Answer the anchor facts quickly and exactly, without counting on.".to_string(),
        items,
    ))
}
