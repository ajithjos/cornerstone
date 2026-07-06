use catalog::MaterialRuntime;

use crate::GeneratedActivity;

use super::shared::{
    ActivityRng, build_generated_activity, generate_unique_items, integer_item, parameter_bool, parameter_usize,
};

pub(super) const TEMPLATE_ID: &str = "division_facts_from_tables";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/division_facts_from_tables";

pub(super) fn generate(runtime: &MaterialRuntime, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let item_count = parameter_usize(runtime, "question_count").unwrap_or(10);
    let divisor_min = parameter_usize(runtime, "divisor_min").unwrap_or(2) as u32;
    let divisor_max = parameter_usize(runtime, "divisor_max").unwrap_or(10) as u32;
    let max_quotient = parameter_usize(runtime, "max_quotient").unwrap_or(10) as u32;
    let include_zero_dividend = parameter_bool(runtime, "include_zero_dividend").unwrap_or(true);
    let mut rng = ActivityRng::new(seed);
    let items = generate_unique_items(item_count, 24, &mut rng, |index, rng| {
        let divisor = rng.range_inclusive(divisor_min.min(divisor_max), divisor_min.max(divisor_max)) as i32;
        let use_zero_dividend = include_zero_dividend && rng.range_inclusive(0, 9) == 0;
        if use_zero_dividend {
            return integer_item(index, format!("0 / {divisor} ="), 0, &format!("divide_by_{divisor}"));
        }

        let quotient = rng.range_inclusive(1, max_quotient.max(1)) as i32;
        integer_item(
            index,
            format!("{} / {divisor} =", divisor * quotient),
            quotient,
            &format!("divide_by_{divisor}"),
        )
    })?;

    Ok(build_generated_activity(
        runtime,
        seed,
        RUNTIME_ID,
        "Use the matching multiplication fact to answer each exact division item.".to_string(),
        items,
    ))
}
