use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    build_generated_activity, integer_candidate, multiplication_fact_key, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "multiplication_tables_to_10";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/multiplication_tables_to_10";

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default = "default_table_min")]
    table_min: i32,
    #[serde(default = "default_table_max")]
    table_max: i32,
    #[serde(default = "default_max_multiplier")]
    max_multiplier: i32,
    #[serde(default = "default_true")]
    include_zero_facts: bool,
    #[serde(default = "default_true")]
    include_one_facts: bool,
    #[serde(default = "default_true")]
    allow_commuted: bool,
}

fn default_question_count() -> usize {
    10
}

fn default_table_min() -> i32 {
    2
}

fn default_table_max() -> i32 {
    10
}

fn default_max_multiplier() -> i32 {
    10
}

fn default_true() -> bool {
    true
}

impl Parameters {
    fn parse(runtime: &MaterialRuntime) -> anyhow::Result<Self> {
        let parameters: Self = parse_parameters(runtime)?;
        if !(2..=10).contains(&parameters.table_min) {
            anyhow::bail!("table_min must be between 2 and 10");
        }
        if !(2..=10).contains(&parameters.table_max) {
            anyhow::bail!("table_max must be between 2 and 10");
        }
        if parameters.table_min > parameters.table_max {
            anyhow::bail!("table_min must not exceed table_max");
        }
        if !(2..=10).contains(&parameters.max_multiplier) {
            anyhow::bail!("max_multiplier must be between 2 and 10");
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
        "Answer the multiplication facts in mixed order. Recall each whole fact instead of rebuilding every group."
            .to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    (parameters.table_min..=parameters.table_max)
        .map(|table| format!("table:{table}"))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for table in parameters.table_min..=parameters.table_max {
        for multiplier in 2..=parameters.max_multiplier {
            let coverage_key = format!("table:{table}");
            push_fact_variants(
                &mut candidates,
                parameters.allow_commuted,
                table,
                multiplier,
                table_families(table, multiplier),
                vec![coverage_key],
                multiplication_band(table, multiplier),
            );
        }
    }

    if parameters.include_zero_facts {
        for other in parameters.table_min..=parameters.table_max {
            push_fact_variants(
                &mut candidates,
                parameters.allow_commuted,
                0,
                other,
                vec![
                    "multiplication_facts_to_10".to_string(),
                    "zero_facts".to_string(),
                    format!("table:{other}"),
                ],
                Vec::new(),
                DifficultyBand::Foundation,
            );
        }
    }
    if parameters.include_one_facts {
        for other in parameters.table_min..=parameters.table_max {
            push_fact_variants(
                &mut candidates,
                parameters.allow_commuted,
                1,
                other,
                vec![
                    "multiplication_facts_to_10".to_string(),
                    "one_facts".to_string(),
                    format!("table:{other}"),
                ],
                Vec::new(),
                DifficultyBand::Foundation,
            );
        }
    }
    candidates
}

fn push_fact_variants(
    candidates: &mut Vec<GeneratedActivityItem>,
    allow_commuted: bool,
    left: i32,
    right: i32,
    family_keys: Vec<String>,
    coverage_keys: Vec<String>,
    difficulty_band: DifficultyBand,
) {
    let answer = left * right;
    let cue = if left == 0 || right == 0 {
        "Any number multiplied by 0 equals 0.".to_string()
    } else if left == 1 || right == 1 {
        format!("Multiplying by 1 keeps the other factor: the answer is {answer}.")
    } else {
        format!("Recall the whole fact: {left} times {right} is {answer}.")
    };
    candidates.push(integer_candidate(
        multiplication_fact_key(left, right),
        family_keys.clone(),
        coverage_keys.clone(),
        difficulty_band,
        format!("{left} x {right} ="),
        answer,
        cue.clone(),
    ));
    if allow_commuted && left != right {
        candidates.push(integer_candidate(
            multiplication_fact_key(left, right),
            family_keys,
            coverage_keys,
            difficulty_band,
            format!("{right} x {left} ="),
            answer,
            cue,
        ));
    }
}

fn table_families(left: i32, right: i32) -> Vec<String> {
    let mut families = vec!["multiplication_facts_to_10".to_string(), format!("table:{left}")];
    if left != right && (2..=10).contains(&right) {
        families.push(format!("table:{right}"));
    }
    families
}

fn multiplication_band(left: i32, right: i32) -> DifficultyBand {
    if left <= 1 || right <= 1 {
        DifficultyBand::Foundation
    } else if (6..=9).contains(&left) && (6..=9).contains(&right) {
        DifficultyBand::Challenge
    } else {
        DifficultyBand::Core
    }
}
