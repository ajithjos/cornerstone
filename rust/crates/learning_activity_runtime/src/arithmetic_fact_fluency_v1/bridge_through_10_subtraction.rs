use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{build_generated_activity, integer_candidate, parse_parameters, validate_template};

pub(super) const TEMPLATE_ID: &str = "bridge_through_10_subtraction";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/bridge_through_10_subtraction";

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

    fn whole_range(&self) -> std::ops::RangeInclusive<i32> {
        match self.difficulty {
            Difficulty::Basic => 11..=17,
            Difficulty::Advanced => 12..=19,
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
        "Step back to 10 first, then subtract the rest.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    parameters
        .whole_range()
        .map(|whole| format!("bridge_start:{whole}"))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for whole in parameters.whole_range() {
        let to_ten = whole - 10;
        for rest in 1..=(9 - to_ten).max(1) {
            let part = to_ten + rest;
            let answer = whole - part;
            let coverage_key = format!("bridge_start:{whole}");
            candidates.push(integer_candidate(
                format!("subtraction:{whole}-{part}"),
                [
                    "bridge_through_10_for_subtraction".to_string(),
                    "operation:subtraction".to_string(),
                    coverage_key.clone(),
                ],
                [coverage_key],
                bridge_band(whole),
                format!("{whole} - {part} ="),
                answer,
                format!("Split {part} into {to_ten} and {rest}; step to 10, then subtract {rest}."),
            ));
        }
    }
    candidates
}

fn bridge_band(whole: i32) -> DifficultyBand {
    match whole {
        ..=12 => DifficultyBand::Foundation,
        13..=15 => DifficultyBand::Core,
        _ => DifficultyBand::Challenge,
    }
}
