use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, item_forms,
    parameter_bool, parameter_string_list, parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "mixed_add_sub_to_10";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/mixed_add_sub_to_10";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let min_total = parameter_usize(runtime, "min_total").unwrap_or(2) as u32;
    let max_total = parameter_usize(runtime, "max_total").unwrap_or(10) as u32;
    let bond_total = parameter_usize(runtime, "bond_total").unwrap_or(10) as i32;
    let allow_zero = parameter_bool(runtime, "allow_zero").unwrap_or(false);
    let mut rng = ActivityRng::new(seed);
    let forms = item_forms(runtime)
        .unwrap_or_else(|| vec!["equation".to_string(), "bond_missing".to_string()]);
    let operations = parameter_string_list(runtime, "operations")
        .unwrap_or_else(|| vec!["addition".to_string(), "subtraction".to_string()]);
    let items = generate_unique_items(item_count, 12, &mut rng, |index, rng| {
        let form = &forms[rng.index(forms.len())];
        if form == "bond_missing" {
            let bond_min = if allow_zero { 0 } else { 1 };
            let shown = rng.range_inclusive(bond_min, bond_total as u32) as i32;
            let left_blank = rng.index(2) == 0;
            return integer_item(
                index,
                if left_blank {
                    format!("__ + {shown} = {bond_total}")
                } else {
                    format!("{shown} + __ = {bond_total}")
                },
                bond_total - shown,
                "number_bonds_within_10",
            );
        }

        let operation = &operations[rng.index(operations.len())];
        if operation == "subtraction" {
            let whole = rng.range_inclusive(min_total, max_total) as i32;
            let part_start = if allow_zero { 0 } else { 1 };
            let part_end = if allow_zero {
                whole as u32
            } else {
                whole as u32 - 1
            };
            let part = rng.range_inclusive(part_start, part_end) as i32;
            integer_item(
                index,
                format!("{whole} - {part} ="),
                whole - part,
                "subtract_within_10",
            )
        } else {
            let total = rng.range_inclusive(min_total, max_total) as i32;
            let left_start = if allow_zero { 0 } else { 1 };
            let left_end = if allow_zero {
                total as u32
            } else {
                total as u32 - 1
            };
            let left = rng.range_inclusive(left_start, left_end) as i32;
            let right = total - left;
            integer_item(
                index,
                format!("{left} + {right} ="),
                total,
                "add_within_10",
            )
        }
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Answer each item in mixed order without counting for every question.".to_string(),
        items,
    ))
}
