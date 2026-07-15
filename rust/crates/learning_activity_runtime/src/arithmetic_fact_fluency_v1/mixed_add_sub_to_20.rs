use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    addition_fact_key, build_generated_activity, integer_candidate, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "mixed_add_sub_to_20";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/mixed_add_sub_to_20";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Operation {
    Addition,
    Subtraction,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
enum ItemForm {
    Equation,
    BondMissing,
    MissingSubtraction,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    #[serde(default = "default_question_count")]
    question_count: usize,
    #[serde(default = "default_operations")]
    operations: Vec<Operation>,
    #[serde(default)]
    item_forms: Option<Vec<ItemForm>>,
    #[serde(default)]
    prompt_forms: Option<Vec<ItemForm>>,
}

fn default_question_count() -> usize {
    10
}

fn default_operations() -> Vec<Operation> {
    vec![Operation::Addition, Operation::Subtraction]
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
        if parameters.forms().contains(&ItemForm::Equation) && parameters.operations.is_empty() {
            anyhow::bail!("operations must contain at least one operation when equation items are enabled");
        }
        Ok(parameters)
    }

    fn forms(&self) -> Vec<ItemForm> {
        self.item_forms
            .clone()
            .or_else(|| self.prompt_forms.clone())
            .unwrap_or_else(|| vec![ItemForm::Equation, ItemForm::BondMissing, ItemForm::MissingSubtraction])
    }
}

pub(super) fn validate(runtime: &MaterialRuntime) -> anyhow::Result<()> {
    let parameters = Parameters::parse(runtime)?;
    let required = required_coverage(&parameters);
    validate_template(runtime, parameters.question_count, &candidates(&parameters), &required)
}

pub(super) fn generate(runtime: &MaterialRuntime, context: &GenerationContext) -> anyhow::Result<GeneratedActivity> {
    let parameters = Parameters::parse(runtime)?;
    build_generated_activity(
        runtime,
        context,
        RUNTIME_ID,
        "Work through the mixed facts and missing-number items without rushing into guesses.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required_coverage(&parameters),
    )
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for form in parameters.forms() {
        match form {
            ItemForm::BondMissing => {
                for shown in 1..=19 {
                    let missing = 20 - shown;
                    for content in [format!("__ + {shown} = 20"), format!("{shown} + __ = 20")] {
                        candidates.push(integer_candidate(
                            addition_fact_key(shown, missing),
                            [
                                "number_bonds_within_20".to_string(),
                                "operation:addition".to_string(),
                                "form:bond_missing".to_string(),
                            ],
                            ["form:bond_missing".to_string()],
                            DifficultyBand::Challenge,
                            content,
                            missing,
                            format!("The two parts must total 20: {shown} and {missing}."),
                        ));
                    }
                }
            }
            ItemForm::MissingSubtraction => {
                for whole in 10..=20 {
                    for remaining in 1..whole {
                        let part = whole - remaining;
                        candidates.push(integer_candidate(
                            format!("subtraction:{whole}-{part}"),
                            [
                                "missing_number_addition_and_subtraction_within_20".to_string(),
                                "operation:subtraction".to_string(),
                                "form:missing_subtraction".to_string(),
                            ],
                            ["form:missing_subtraction".to_string()],
                            fact_band(whole),
                            format!("{whole} - __ = {remaining}"),
                            part,
                            format!("Find what was removed: {remaining} plus {part} makes {whole}."),
                        ));
                    }
                }
            }
            ItemForm::Equation => {
                for operation in &parameters.operations {
                    match operation {
                        Operation::Addition => {
                            for total in 4..=20 {
                                for left in 1..total {
                                    let right = total - left;
                                    candidates.push(integer_candidate(
                                        addition_fact_key(left, right),
                                        [
                                            "add_within_20".to_string(),
                                            "operation:addition".to_string(),
                                            "form:equation".to_string(),
                                        ],
                                        ["form:equation".to_string(), "operation:addition".to_string()],
                                        fact_band(total),
                                        format!("{left} + {right} ="),
                                        total,
                                        format!("Combine {left} and {right}; the whole is {total}."),
                                    ));
                                }
                            }
                        }
                        Operation::Subtraction => {
                            for whole in 4..=20 {
                                for part in 1..whole {
                                    candidates.push(integer_candidate(
                                        format!("subtraction:{whole}-{part}"),
                                        [
                                            "subtract_within_20".to_string(),
                                            "operation:subtraction".to_string(),
                                            "form:equation".to_string(),
                                        ],
                                        ["form:equation".to_string(), "operation:subtraction".to_string()],
                                        fact_band(whole),
                                        format!("{whole} - {part} ="),
                                        whole - part,
                                        format!("Start with {whole} and remove {part}; {} remains.", whole - part),
                                    ));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    candidates
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    let forms = parameters.forms();
    let mut required = forms
        .iter()
        .map(|form| match form {
            ItemForm::Equation => "form:equation".to_string(),
            ItemForm::BondMissing => "form:bond_missing".to_string(),
            ItemForm::MissingSubtraction => "form:missing_subtraction".to_string(),
        })
        .collect::<Vec<_>>();
    if forms.contains(&ItemForm::Equation) {
        required.extend(parameters.operations.iter().map(|operation| match operation {
            Operation::Addition => "operation:addition".to_string(),
            Operation::Subtraction => "operation:subtraction".to_string(),
        }));
    }
    required
}

fn fact_band(total: i32) -> DifficultyBand {
    if total <= 10 {
        DifficultyBand::Foundation
    } else if total <= 15 {
        DifficultyBand::Core
    } else {
        DifficultyBand::Challenge
    }
}
