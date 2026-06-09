use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, item_forms, parameter_string_list,
    parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "mixed_add_sub_to_20";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/mixed_add_sub_to_20";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let mut rng = ActivityRng::new(seed);
    let forms = item_forms(runtime).unwrap_or_else(|| {
        vec![
            "equation".to_string(),
            "bond_missing".to_string(),
            "missing_subtraction".to_string(),
        ]
    });
    let operations = parameter_string_list(runtime, "operations")
        .unwrap_or_else(|| vec!["addition".to_string(), "subtraction".to_string()]);
    let items = generate_unique_items(item_count, 14, &mut rng, |index, rng| {
        let form = &forms[rng.index(forms.len())];
        match form.as_str() {
            "bond_missing" => {
                let shown = rng.range_inclusive(1, 19) as i32;
                let left_blank = rng.index(2) == 0;
                integer_item(
                    index,
                    if left_blank {
                        format!("__ + {shown} = 20")
                    } else {
                        format!("{shown} + __ = 20")
                    },
                    20 - shown,
                    "number_bonds_within_20",
                )
            }
            "missing_subtraction" => {
                let whole = rng.range_inclusive(10, 20) as i32;
                let remaining = rng.range_inclusive(1, whole as u32 - 1) as i32;
                integer_item(
                    index,
                    format!("{whole} - __ = {remaining}"),
                    whole - remaining,
                    "missing_number_addition_and_subtraction_within_20",
                )
            }
            _ => {
                let operation = &operations[rng.index(operations.len())];
                if operation == "subtraction" {
                    let whole = rng.range_inclusive(4, 20) as i32;
                    let part = rng.range_inclusive(1, whole as u32 - 1) as i32;
                    integer_item(index, format!("{whole} - {part} ="), whole - part, "subtract_within_20")
                } else {
                    let total = rng.range_inclusive(4, 20) as i32;
                    let left = rng.range_inclusive(1, total as u32 - 1) as i32;
                    let right = total - left;
                    integer_item(index, format!("{left} + {right} ="), total, "add_within_20")
                }
            }
        }
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Work through the mixed facts and missing-number items without rushing into guesses.".to_string(),
        items,
    ))
}
