use std::collections::BTreeMap;

use anyhow::ensure;

use crate::written_arithmetic::{CellFeedback, CheckResult};
use crate::{ActivityResponseInput, FactStep, GeneratedActivity, GeneratedActivityItem, RunMode};

impl GeneratedActivityItem {
    pub(super) fn with_answer_prompt(mut self, prompt: impl Into<String>) -> Self {
        self.answer_prompt = Some(prompt.into());
        self
    }

    pub(super) fn add_step(&mut self, prompt: String, expected_response: i32, correction_cue: String) {
        self.steps.push(FactStep {
            item_id: String::new(), // Assigned after the facts have been selected for this run.
            prompt,
            expected_response,
            correction_cue,
        });
    }

    pub(super) fn bridge_addition(mut self, left: i32, right: i32) -> Self {
        self.equation = Some(format!("{left} + {right} = {left} + □ + □ = □"));
        let first = 10 - left;
        let rest = right - first;
        self.add_step(
            format!("{left} + □ = 10. How much do you add first?"),
            first,
            format!("{left} + {first} = 10."),
        );
        self.add_step(
            format!("You need to add {right}. After you reach 10, how much is left to add?"),
            rest,
            format!("{right} is {first} and {rest}. You used {first}, so add {rest} more."),
        );
        self.with_answer_prompt("Start at 10 and add the rest. What is the total?")
    }

    pub(super) fn bridge_subtraction(mut self, whole: i32, part: i32) -> Self {
        self.equation = Some(format!("{whole} − {part} = {whole} − □ − □ = □"));
        let first = whole - 10;
        let rest = part - first;
        self.add_step(
            format!("{whole} − □ = 10. How much do you take away first?"),
            first,
            format!("{whole} − {first} = 10."),
        );
        self.add_step(
            format!("You need to take away {part}. After you reach 10, how much is left to take away?"),
            rest,
            format!("{part} is {first} and {rest}. You took away {first}, so take away {rest} more."),
        );
        self.with_answer_prompt("Start at 10 and take away the rest. What is left?")
    }

    pub(super) fn guide_addition(mut self, left: i32, right: i32) -> Self {
        let smaller = left.min(right);
        let larger = left.max(right);
        if smaller == 0 {
            self.with_answer_prompt("Adding zero keeps the number the same. Which number stays?")
        } else if left == right {
            self.with_answer_prompt(format!("Double {left}. How many altogether?"))
        } else if left == 10 || right == 10 {
            let ones = left + right - 10;
            self.with_answer_prompt(format!(
                "There is 1 ten. The ones digit is {ones}. What number is that?"
            ))
        } else if left + right > 10 && larger < 10 {
            self.bridge_addition(left, right)
        } else if larger == smaller + 1 && smaller > 1 {
            self.equation = Some(format!("{left} + {right} = □ + 1 = □"));
            self.add_step(
                format!("Use a double first. What is {smaller} + {smaller}?"),
                2 * smaller,
                format!("Two groups of {smaller} make {}.", 2 * smaller),
            );
            self.with_answer_prompt("Add one more to your double. What is the total?")
        } else {
            self.with_answer_prompt(format!("Put {larger} and {smaller} together. What is the whole?"))
        }
    }

    pub(super) fn guide_subtraction(self, whole: i32, part: i32) -> Self {
        if whole > 10 && whole - part < 10 && part < 10 {
            self.bridge_subtraction(whole, part)
        } else {
            self.with_answer_prompt(format!("{part} + □ = {whole}. What is the missing part?"))
        }
    }

    pub(super) fn fields(&self) -> impl Iterator<Item = FactField<'_>> {
        self.steps
            .iter()
            .map(|step| FactField {
                id: &step.item_id,
                prompt: &step.prompt,
                expected: step.expected_response,
                correction: &step.correction_cue,
            })
            .chain(std::iter::once(FactField {
                id: &self.item_id,
                prompt: &self.content,
                expected: self.expected_response,
                correction: &self.correction_cue,
            }))
    }
}

pub(super) struct FactField<'a> {
    pub id: &'a str,
    pub prompt: &'a str,
    pub expected: i32,
    pub correction: &'a str,
}

impl FactField<'_> {
    pub(super) fn correct(&self, submitted: &str) -> bool {
        submitted.parse::<i32>().ok() == Some(self.expected)
    }
}

pub fn check_fact_responses(
    generated: &GeneratedActivity,
    responses: &[ActivityResponseInput],
    finish: bool,
) -> anyhow::Result<CheckResult> {
    ensure!(
        generated.engine_id == super::ENGINE_ID && generated.has_fact_working(),
        "this activity does not support guided fact feedback"
    );
    ensure!(
        finish
            || matches!(
                generated.generation_context.run_mode,
                RunMode::Practice | RunMode::Retry
            ),
        "feedback is available after submission"
    );
    crate::validate_fact_response_ids(generated, responses)?;
    let values: BTreeMap<_, _> = responses.iter().map(|r| (r.item_id.as_str(), r.value.trim())).collect();
    let mut feedback = Vec::new();
    for field in generated.items.iter().flat_map(GeneratedActivityItem::fields) {
        let value = values.get(field.id).copied().unwrap_or("");
        if !finish && value.is_empty() {
            continue;
        }
        let correct = field.correct(value);
        feedback.push(CellFeedback {
            cell_id: field.id.into(),
            correct,
            expected: (!correct).then(|| field.expected.to_string()),
            explanation: if correct {
                "Correct!".into()
            } else {
                field.correction.into()
            },
        });
    }
    Ok(CheckResult {
        correct_count: feedback.iter().filter(|field| field.correct).count(),
        total_count: feedback.len(),
        complete: finish,
        feedback,
    })
}
