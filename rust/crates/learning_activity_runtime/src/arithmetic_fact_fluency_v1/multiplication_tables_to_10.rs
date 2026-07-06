use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, parameter_bool, parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "multiplication_tables_to_10";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/multiplication_tables_to_10";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let table_min = parameter_usize(runtime, "table_min").unwrap_or(2) as u32;
    let table_max = parameter_usize(runtime, "table_max").unwrap_or(10) as u32;
    let max_multiplier = parameter_usize(runtime, "max_multiplier").unwrap_or(10) as u32;
    let include_zero_facts = parameter_bool(runtime, "include_zero_facts").unwrap_or(true);
    let include_one_facts = parameter_bool(runtime, "include_one_facts").unwrap_or(true);
    let allow_commuted = parameter_bool(runtime, "allow_commuted").unwrap_or(true);
    let mut rng = ActivityRng::new(seed);
    let items = generate_unique_items(item_count, 24, &mut rng, |index, rng| {
        let special_roll = rng.range_inclusive(0, 9);
        if include_zero_facts && special_roll == 0 {
            let other = rng.range_inclusive(2, max_multiplier.max(2)) as i32;
            let switched = allow_commuted && rng.index(2) == 0;
            let (left, right) = if switched { (other, 0) } else { (0, other) };
            return integer_item(index, format!("{left} x {right} ="), 0, "zero_facts");
        }
        if include_one_facts && special_roll == 1 {
            let other = rng.range_inclusive(2, max_multiplier.max(2)) as i32;
            let switched = allow_commuted && rng.index(2) == 0;
            let (left, right) = if switched { (other, 1) } else { (1, other) };
            return integer_item(index, format!("{left} x {right} ="), other, "one_facts");
        }

        let table = rng.range_inclusive(table_min.min(table_max), table_min.max(table_max)) as i32;
        let multiplier = rng.range_inclusive(1, max_multiplier.max(1)) as i32;
        let switched = allow_commuted && rng.index(2) == 0;
        let (left, right) = if switched {
            (multiplier, table)
        } else {
            (table, multiplier)
        };
        integer_item(
            index,
            format!("{left} x {right} ="),
            left * right,
            &format!("table_{table}"),
        )
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Answer the multiplication facts in mixed order, including switched-factor forms, without rebuilding every group."
            .to_string(),
        items,
    ))
}
