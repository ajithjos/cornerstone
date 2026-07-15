use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    addition_fact_key, build_generated_activity, integer_candidate, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "bridge_through_10_addition";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/bridge_through_10_addition";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Difficulty {
    Basic,
    Advanced,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default = "default_difficulty")]
    difficulty: Difficulty,
}

fn default_question_count() -> usize {
    10
}

fn default_difficulty() -> Difficulty {
    Difficulty::Basic
}

impl Parameters {
    fn parse(runtime: &MaterialRuntime) -> anyhow::Result<Self> {
        parse_parameters(runtime)
    }

    fn left_range(&self) -> std::ops::RangeInclusive<i32> {
        match self.difficulty {
            Difficulty::Basic => 6..=9,
            Difficulty::Advanced => 5..=9,
        }
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
        "Make 10 first, then add the leftover part.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    parameters
        .left_range()
        .map(|left| format!("bridge_start:{left}"))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for left in parameters.left_range() {
        let needed = 10 - left;
        for leftover in 1..=(9 - needed).max(1) {
            let right = needed + leftover;
            let answer = left + right;
            let coverage_key = format!("bridge_start:{left}");
            candidates.push(integer_candidate(
                addition_fact_key(left, right),
                [
                    "bridge_through_10_for_addition".to_string(),
                    "operation:addition".to_string(),
                    coverage_key.clone(),
                ],
                [coverage_key],
                bridge_band(answer),
                format!("{left} + {right} ="),
                answer,
                format!("Split {right} into {needed} and {leftover}; make 10, then add {leftover}."),
            ));
        }
    }
    candidates
}

fn bridge_band(total: i32) -> DifficultyBand {
    match total {
        ..=12 => DifficultyBand::Foundation,
        13..=15 => DifficultyBand::Core,
        _ => DifficultyBand::Challenge,
    }
}
