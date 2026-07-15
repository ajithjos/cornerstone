use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    addition_fact_key, build_generated_activity, integer_candidate, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "readiness_within_5";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/readiness_within_5";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum ItemForm {
    CountGroup,
    BondMissing,
    Addition,
    Subtraction,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default)]
    item_forms: Option<Vec<ItemForm>>,
    #[serde(default)]
    prompt_forms: Option<Vec<ItemForm>>,
}

fn default_question_count() -> usize {
    10
}

impl Parameters {
    fn parse(runtime: &MaterialRuntime) -> anyhow::Result<Self> {
        let parameters: Self = parse_parameters(runtime)?;
        if parameters.item_forms.is_some() && parameters.prompt_forms.is_some() {
            anyhow::bail!("use item_forms or prompt_forms, not both");
        }
        if parameters.forms().is_empty() {
            anyhow::bail!("item_forms must contain at least one supported form");
        }
        Ok(parameters)
    }

    fn forms(&self) -> Vec<ItemForm> {
        self.item_forms
            .clone()
            .or_else(|| self.prompt_forms.clone())
            .unwrap_or_else(|| {
                vec![
                    ItemForm::CountGroup,
                    ItemForm::BondMissing,
                    ItemForm::Addition,
                    ItemForm::Subtraction,
                ]
            })
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
        "Answer each item calmly and say the whole fact if that helps.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    parameters
        .forms()
        .into_iter()
        .map(|form| format!("form:{}", form_key(form)))
        .collect()
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for form in parameters.forms() {
        let coverage_key = format!("form:{}", form_key(form));
        match form {
            ItemForm::CountGroup => {
                for count in 1..=5 {
                    let group = std::iter::repeat_n("o", count as usize).collect::<Vec<_>>().join(" ");
                    candidates.push(integer_candidate(
                        format!("count:{count}"),
                        ["count_small_groups_within_5".to_string(), coverage_key.clone()],
                        [coverage_key.clone()],
                        readiness_band(count),
                        format!("Count the group: {group}"),
                        count,
                        format!("Touch each object once: there are {count}."),
                    ));
                }
            }
            ItemForm::BondMissing => {
                for shown in 1..=4 {
                    let missing = 5 - shown;
                    candidates.push(integer_candidate(
                        addition_fact_key(shown, missing),
                        [
                            "number_bonds_within_5".to_string(),
                            "operation:addition".to_string(),
                            coverage_key.clone(),
                        ],
                        [coverage_key.clone()],
                        readiness_band(5),
                        format!("{shown} and __ make 5"),
                        missing,
                        format!("The two parts must total 5: {shown} and {missing}."),
                    ));
                }
            }
            ItemForm::Addition => {
                for total in 2..=5 {
                    for left in 1..total {
                        let right = total - left;
                        candidates.push(integer_candidate(
                            addition_fact_key(left, right),
                            [
                                "add_and_subtract_within_5".to_string(),
                                "operation:addition".to_string(),
                                coverage_key.clone(),
                            ],
                            [coverage_key.clone()],
                            readiness_band(total),
                            format!("{left} + {right} ="),
                            total,
                            format!("Put the two parts together: {left} and {right} make {total}."),
                        ));
                    }
                }
            }
            ItemForm::Subtraction => {
                for whole in 2..=5 {
                    for part in 1..whole {
                        candidates.push(integer_candidate(
                            format!("subtraction:{whole}-{part}"),
                            [
                                "add_and_subtract_within_5".to_string(),
                                "operation:subtraction".to_string(),
                                coverage_key.clone(),
                            ],
                            [coverage_key.clone()],
                            readiness_band(whole),
                            format!("{whole} - {part} ="),
                            whole - part,
                            format!("Start with {whole} and take away {part}."),
                        ));
                    }
                }
            }
        }
    }
    candidates
}

fn form_key(form: ItemForm) -> &'static str {
    match form {
        ItemForm::CountGroup => "count_group",
        ItemForm::BondMissing => "bond_missing",
        ItemForm::Addition => "addition",
        ItemForm::Subtraction => "subtraction",
    }
}

fn readiness_band(value: i32) -> DifficultyBand {
    match value {
        0..=2 => DifficultyBand::Foundation,
        3..=4 => DifficultyBand::Core,
        _ => DifficultyBand::Challenge,
    }
}
