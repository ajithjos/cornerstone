use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, item_forms, parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "readiness_within_5";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/readiness_within_5";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let mut rng = ActivityRng::new(seed);
    let forms = item_forms(runtime).unwrap_or_else(|| {
        vec![
            "count_group".to_string(),
            "bond_missing".to_string(),
            "addition".to_string(),
            "subtraction".to_string(),
        ]
    });
    let items = generate_unique_items(item_count, 10, &mut rng, |index, rng| {
        let form = &forms[rng.index(forms.len())];
        match form.as_str() {
            "count_group" => {
                let count = rng.range_inclusive(1, 5) as i32;
                let group = std::iter::repeat_n("o", count as usize).collect::<Vec<_>>().join(" ");
                integer_item(
                    index,
                    format!("Count the group: {group}"),
                    count,
                    "count_small_groups_within_5",
                )
            }
            "bond_missing" => {
                let shown = rng.range_inclusive(1, 4) as i32;
                integer_item(
                    index,
                    format!("{shown} and __ make 5"),
                    5 - shown,
                    "number_bonds_within_5",
                )
            }
            "subtraction" => {
                let whole = rng.range_inclusive(2, 5) as i32;
                let part = rng.range_inclusive(1, whole as u32 - 1) as i32;
                integer_item(
                    index,
                    format!("{whole} - {part} ="),
                    whole - part,
                    "add_and_subtract_within_5",
                )
            }
            _ => {
                let total = rng.range_inclusive(2, 5) as i32;
                let left = rng.range_inclusive(1, total as u32 - 1) as i32;
                let right = total - left;
                integer_item(index, format!("{left} + {right} ="), total, "add_and_subtract_within_5")
            }
        }
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Answer each item calmly and say the whole fact if that helps.".to_string(),
        items,
    ))
}
