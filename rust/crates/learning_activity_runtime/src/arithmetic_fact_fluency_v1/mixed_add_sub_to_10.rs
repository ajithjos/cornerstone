use catalog::MaterialRuntime;
use serde::Deserialize;

use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};

use super::shared::{
    addition_fact_key, build_generated_activity, integer_candidate, parse_parameters, validate_template,
};

pub(super) const TEMPLATE_ID: &str = "mixed_add_sub_to_10";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/mixed_add_sub_to_10";

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
    #[serde(default = "default_min_total")]
    min_total: i32,
    #[serde(default = "default_max_total")]
    max_total: i32,
    #[serde(default = "default_bond_total")]
    bond_total: i32,
    #[serde(default)]
    allow_zero: bool,
}

fn default_question_count() -> usize {
    10
}

fn default_operations() -> Vec<Operation> {
    vec![Operation::Addition, Operation::Subtraction]
}

fn default_min_total() -> i32 {
    2
}

fn default_max_total() -> i32 {
    10
}

fn default_bond_total() -> i32 {
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
        if parameters.forms().contains(&ItemForm::Equation) && parameters.operations.is_empty() {
            anyhow::bail!("operations must contain at least one operation when equation items are enabled");
        }
        if !(1..=10).contains(&parameters.min_total) || !(1..=10).contains(&parameters.max_total) {
            anyhow::bail!("min_total and max_total must be between 1 and 10");
        }
        if parameters.min_total > parameters.max_total {
            anyhow::bail!("min_total must not exceed max_total");
        }
        if !parameters.allow_zero && parameters.min_total < 2 {
            anyhow::bail!("min_total must be at least 2 when allow_zero is false");
        }
        if !(1..=10).contains(&parameters.bond_total) {
            anyhow::bail!("bond_total must be between 1 and 10");
        }
        if !parameters.allow_zero && parameters.bond_total < 2 {
            anyhow::bail!("bond_total must be at least 2 when allow_zero is false");
        }
        Ok(parameters)
    }

    fn forms(&self) -> Vec<ItemForm> {
        self.item_forms
            .clone()
            .or_else(|| self.prompt_forms.clone())
            .unwrap_or_else(|| vec![ItemForm::Equation, ItemForm::BondMissing])
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
        "Answer each item in mixed order without counting for every question.".to_string(),
        parameters.question_count,
        candidates(&parameters),
        required,
    )
}

fn candidates(parameters: &Parameters) -> Vec<GeneratedActivityItem> {
    let mut candidates = Vec::new();
    for form in parameters.forms() {
        match form {
            ItemForm::BondMissing => push_bond_candidates(&mut candidates, parameters),
            ItemForm::Equation => {
                for operation in &parameters.operations {
                    match operation {
                        Operation::Addition => push_addition_candidates(&mut candidates, parameters),
                        Operation::Subtraction => push_subtraction_candidates(&mut candidates, parameters),
                    }
                }
            }
        }
    }
    candidates
}

fn push_bond_candidates(candidates: &mut Vec<GeneratedActivityItem>, parameters: &Parameters) {
    let start = if parameters.allow_zero { 0 } else { 1 };
    let end = if parameters.allow_zero {
        parameters.bond_total
    } else {
        parameters.bond_total - 1
    };
    for shown in start..=end {
        let missing = parameters.bond_total - shown;
        for content in [
            format!("__ + {shown} = {}", parameters.bond_total),
            format!("{shown} + __ = {}", parameters.bond_total),
        ] {
            candidates.push(integer_candidate(
                addition_fact_key(shown, missing),
                [
                    "number_bonds_within_10".to_string(),
                    "operation:addition".to_string(),
                    "form:bond_missing".to_string(),
                ],
                ["form:bond_missing".to_string()],
                fact_band(parameters.bond_total, shown == 0 || missing == 0),
                content,
                missing,
                format!(
                    "The two parts must total {}: {shown} and {missing}.",
                    parameters.bond_total
                ),
            ));
        }
    }
}

fn push_addition_candidates(candidates: &mut Vec<GeneratedActivityItem>, parameters: &Parameters) {
    for total in parameters.min_total..=parameters.max_total {
        let start = if parameters.allow_zero { 0 } else { 1 };
        let end = if parameters.allow_zero { total } else { total - 1 };
        for left in start..=end {
            let right = total - left;
            candidates.push(integer_candidate(
                addition_fact_key(left, right),
                [
                    "add_within_10".to_string(),
                    "operation:addition".to_string(),
                    "form:equation".to_string(),
                ],
                ["form:equation".to_string(), "operation:addition".to_string()],
                fact_band(total, left == 0 || right == 0),
                format!("{left} + {right} ="),
                total,
                format!("Combine {left} and {right}; the whole is {total}."),
            ));
        }
    }
}

fn push_subtraction_candidates(candidates: &mut Vec<GeneratedActivityItem>, parameters: &Parameters) {
    for whole in parameters.min_total..=parameters.max_total {
        let start = if parameters.allow_zero { 0 } else { 1 };
        let end = if parameters.allow_zero { whole } else { whole - 1 };
        for part in start..=end {
            candidates.push(integer_candidate(
                format!("subtraction:{whole}-{part}"),
                [
                    "subtract_within_10".to_string(),
                    "operation:subtraction".to_string(),
                    "form:equation".to_string(),
                ],
                ["form:equation".to_string(), "operation:subtraction".to_string()],
                fact_band(whole, part == 0 || part == whole),
                format!("{whole} - {part} ="),
                whole - part,
                format!("Start with {whole} and remove {part}; {} remains.", whole - part),
            ));
        }
    }
}

fn required_coverage(parameters: &Parameters) -> Vec<String> {
    let forms = parameters.forms();
    let mut required = forms
        .iter()
        .map(|form| match form {
            ItemForm::Equation => "form:equation".to_string(),
            ItemForm::BondMissing => "form:bond_missing".to_string(),
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

fn fact_band(total: i32, identity: bool) -> DifficultyBand {
    if identity || total <= 4 {
        DifficultyBand::Foundation
    } else if total <= 7 {
        DifficultyBand::Core
    } else {
        DifficultyBand::Challenge
    }
}
