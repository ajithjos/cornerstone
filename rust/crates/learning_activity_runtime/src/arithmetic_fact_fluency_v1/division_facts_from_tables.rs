use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{build_generated_activity, integer_candidate, parse_parameters, validate_template};

pub(super) const TEMPLATE_ID: &str = "division_facts_from_tables";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/division_facts_from_tables";

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default = "default_divisor_min")]
    divisor_min: i32,
    #[serde(default = "default_divisor_max")]
    divisor_max: i32,
    #[serde(default = "default_max_quotient")]
    max_quotient: i32,
    #[serde(default = "default_true")]
    include_zero_dividend: bool,
}

fn default_question_count() -> usize {
    10
}

fn default_divisor_min() -> i32 {
    2
}

fn default_divisor_max() -> i32 {
    10
}

fn default_max_quotient() -> i32 {
    10
}

fn default_true() -> bool {
    true
}

impl Parameters {
    fn parse(runtime: &MaterialRuntime) -> anyhow::Result<Self> {
        let parameters: Self = parse_parameters(runtime)?;
        if !(2..=10).contains(&parameters.divisor_min) {
            anyhow::bail!("divisor_min must be between 2 and 10");
        }
        if !(2..=10).contains(&parameters.divisor_max) {
            anyhow::bail!("divisor_max must be between 2 and 10");
        }
        if parameters.divisor_min > parameters.divisor_max {
            anyhow::bail!("divisor_min must not exceed divisor_max");
        }
        if !(2..=10).contains(&parameters.max_quotient) {
            anyhow::bail!("max_quotient must be between 2 and 10");
        }
        Ok(parameters)
    }
}

pub(super) fn validate(runtime: &MaterialRuntime) -> anyhow::Result<()> {
    let parameters = Parameters::parse(runtime)?;
    let required = required_coverage(&parameters);
    validate_template(runtime, parameters.question_count, &candidates(&parameters), &required)
}

pub(super) fn generate(runtime: &MaterialRuntime, context: &GenerationContext) -> anyhow::Result<GeneratedActivity> {
    let parameters = Parameters::parse(runtime)?;
    let required = required_coverage(&parameters);
    build_generated_activity(
        runtime,
        context,
        RUNTIME_ID,
        "Use the matching multiplication fact to answer each exact division item.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    (parameters.divisor_min..=parameters.divisor_max)
        .map(|divisor| format!("divide_by:{divisor}"))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for divisor in parameters.divisor_min..=parameters.divisor_max {
        let family_key = format!("divide_by:{divisor}");
        for quotient in 1..=parameters.max_quotient {
            let dividend = divisor * quotient;
            let coverage_keys = if quotient == 1 {
                Vec::new()
            } else {
                vec![family_key.clone()]
            };
            candidates.push(integer_candidate(
                format!("division:{dividend}/{divisor}"),
                ["division_facts_from_tables".to_string(), family_key.clone()],
                coverage_keys,
                division_band(divisor, quotient),
                format!("{dividend} / {divisor} ="),
                quotient,
                format!("Use the matching fact: {divisor} x {quotient} = {dividend}."),
            ));
        }
        if parameters.include_zero_dividend {
            candidates.push(integer_candidate(
                format!("division:0/{divisor}"),
                [
                    "division_facts_from_tables".to_string(),
                    "zero_dividend_facts".to_string(),
                    family_key,
                ],
                Vec::new(),
                DifficultyBand::Foundation,
                format!("0 / {divisor} ="),
                0,
                "Zero shared into equal groups still gives zero in each group.".to_string(),
            ));
        }
    }
    candidates
}

fn division_band(divisor: i32, quotient: i32) -> DifficultyBand {
    if quotient <= 1 {
        DifficultyBand::Foundation
    } else if (6..=9).contains(&divisor) && (6..=9).contains(&quotient) {
        DifficultyBand::Challenge
    } else {
        DifficultyBand::Core
    }
}
