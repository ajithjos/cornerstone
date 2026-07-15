use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    addition_fact_key, build_generated_activity, integer_candidate, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "anchor_facts_to_20";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/anchor_facts_to_20";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Mode {
    Double,
    #[serde(rename = "add_10")]
    Add10,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default = "default_modes")]
    modes: Vec<Mode>,
}

fn default_question_count() -> usize {
    10
}

fn default_modes() -> Vec<Mode> {
    vec![Mode::Double, Mode::Add10]
}

impl Parameters {
    fn parse(runtime: &MaterialRuntime) -> anyhow::Result<Self> {
        let parameters: Self = parse_parameters(runtime)?;
        if parameters.modes.is_empty() {
            anyhow::bail!("modes must contain at least one supported mode");
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
        "Answer the anchor facts quickly and exactly, without counting on.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    parameters
        .modes
        .iter()
        .map(|mode| format!("anchor:{}", mode_key(*mode)))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for mode in &parameters.modes {
        let coverage_key = format!("anchor:{}", mode_key(*mode));
        match mode {
            Mode::Double => {
                for value in 1..=10 {
                    let answer = value * 2;
                    candidates.push(integer_candidate(
                        addition_fact_key(value, value),
                        ["recall_doubles_to_20".to_string(), coverage_key.clone()],
                        [coverage_key.clone()],
                        anchor_band(value),
                        format!("{value} + {value} ="),
                        answer,
                        format!("This is double {value}: {value} and {value} make {answer}."),
                    ));
                }
            }
            Mode::Add10 => {
                for addend in 1..=9 {
                    let answer = 10 + addend;
                    candidates.push(integer_candidate(
                        addition_fact_key(10, addend),
                        ["add_10_to_single_digits".to_string(), coverage_key.clone()],
                        [coverage_key.clone()],
                        anchor_band(addend),
                        format!("10 + {addend} ="),
                        answer,
                        format!("Keep the ten and add {addend}: the answer is {answer}."),
                    ));
                }
            }
        }
    }
    candidates
}

fn mode_key(mode: Mode) -> &'static str {
    match mode {
        Mode::Double => "double",
        Mode::Add10 => "add_10",
    }
}

fn anchor_band(value: i32) -> DifficultyBand {
    match value {
        0..=4 => DifficultyBand::Foundation,
        5..=7 => DifficultyBand::Core,
        _ => DifficultyBand::Challenge,
    }
}
