use super::shared::{build_generated_activity, integer_candidate, parse_parameters, validate_template};
use crate::{DifficultyBand, GeneratedActivity, GeneratedActivityItem, GenerationContext};
use catalog::MaterialRuntime;
use serde::Deserialize;

pub(super) const TEMPLATE_ID: &str = "quick_ten_and_nine";
pub(super) const RUNTIME_ID: &str = "arithmetic_fact_fluency.v1/quick_ten_and_nine";

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Parameters {
    question_count: usize,
}

fn candidates() -> (Vec<GeneratedActivityItem>, Vec<String>) {
    let mut items = Vec::new();
    let mut coverage = Vec::new();
    for (family, sign, delta) in [
        ("add10", "+", 10),
        ("subtract10", "−", -10),
        ("add9", "+", 9),
        ("subtract9", "−", -9),
    ] {
        let amount = i32::abs(delta);
        coverage.push(family.to_owned());
        // Keep the jump through ten within whole numbers, including crossings at 100.
        let first = if delta < 0 { 10 } else { 0 };
        for start in first..=109 {
            let answer = start + delta;
            let ten = start + delta.signum() * 10;
            let adjust = if delta > 0 { "−" } else { "+" };
            let cue = if amount == 9 {
                format!("{start} {sign} 10 = {ten}. Then {ten} {adjust} 1 = {answer}.")
            } else {
                format!("{start} {sign} 10 = {answer}. The ones digit stays the same.")
            };
            let mut item = integer_candidate(
                format!("{family}:{start}"),
                ["use_ten_to_add_and_subtract_nine".into(), family.into()],
                [family.into()],
                DifficultyBand::Core,
                format!("{start} {sign} {amount} ="),
                answer,
                cue,
            )
            .with_answer_prompt("What is the answer?");
            if amount == 9 {
                item.add_step(
                    format!("What is {start} {sign} 10?"),
                    ten,
                    format!("{start} {sign} 10 = {ten}."),
                );
                item.equation = Some(format!("{start} {sign} 9 = □ {adjust} 1 = □"));
            }
            items.push(item);
        }
    }
    (items, coverage)
}

pub(super) fn validate(runtime: &MaterialRuntime) -> anyhow::Result<()> {
    let parameters: Parameters = parse_parameters(runtime)?;
    let (items, coverage) = candidates();
    validate_template(runtime, parameters.question_count, &items, &coverage)
}

pub(super) fn generate(runtime: &MaterialRuntime, context: &GenerationContext) -> anyhow::Result<GeneratedActivity> {
    let parameters: Parameters = parse_parameters(runtime)?;
    let (items, coverage) = candidates();
    build_generated_activity(
        runtime,
        context,
        RUNTIME_ID,
        "Use a jump of ten. For nine, come back one.".into(),
        parameters.question_count,
        items,
        coverage,
    )
}
