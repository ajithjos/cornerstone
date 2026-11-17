mod arithmetic_fact_fluency_v1;
pub mod written_arithmetic;

use std::collections::BTreeSet;

use anyhow::{Context, anyhow, bail};
use catalog::{MaterialDocument, MaterialRuntime};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActivityResponseInput {
    pub item_id: String,
    pub value: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RunMode {
    Practice,
    Check,
    Review,
    Retry,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GenerationContext {
    pub seed: u64,
    pub run_mode: RunMode,
    #[serde(default)]
    pub focus_fact_keys: Vec<String>,
    #[serde(default)]
    pub weak_fact_keys: Vec<String>,
    #[serde(default)]
    pub seen_fact_keys: Vec<String>,
    #[serde(default)]
    pub focus_family_keys: Vec<String>,
    #[serde(default)]
    pub weak_family_keys: Vec<String>,
}

impl GenerationContext {
    pub fn new(seed: u64, run_mode: RunMode) -> Self {
        Self {
            seed,
            run_mode,
            focus_fact_keys: Vec::new(),
            weak_fact_keys: Vec::new(),
            seen_fact_keys: Vec::new(),
            focus_family_keys: Vec::new(),
            weak_family_keys: Vec::new(),
        }
    }

    pub fn practice(seed: u64) -> Self {
        Self::new(seed, RunMode::Practice)
    }

    pub fn check(seed: u64) -> Self {
        Self::new(seed, RunMode::Check)
    }

    pub fn review(seed: u64) -> Self {
        Self::new(seed, RunMode::Review)
    }

    pub fn retry(seed: u64) -> Self {
        Self::new(seed, RunMode::Retry)
    }

    pub fn with_focus_facts(mut self, fact_keys: impl IntoIterator<Item = String>) -> Self {
        self.focus_fact_keys = fact_keys.into_iter().collect();
        self
    }

    pub fn with_weak_facts(mut self, fact_keys: impl IntoIterator<Item = String>) -> Self {
        self.weak_fact_keys = fact_keys.into_iter().collect();
        self
    }

    pub fn with_seen_facts(mut self, fact_keys: impl IntoIterator<Item = String>) -> Self {
        self.seen_fact_keys = fact_keys.into_iter().collect();
        self
    }

    pub fn with_focus_families(mut self, family_keys: impl IntoIterator<Item = String>) -> Self {
        self.focus_family_keys = family_keys.into_iter().collect();
        self
    }

    pub fn with_weak_families(mut self, family_keys: impl IntoIterator<Item = String>) -> Self {
        self.weak_family_keys = family_keys.into_iter().collect();
        self
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DifficultyBand {
    Foundation,
    Core,
    Challenge,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GeneratedActivityItem {
    pub item_id: String,
    pub fact_key: String,
    pub family_keys: Vec<String>,
    pub coverage_keys: Vec<String>,
    pub difficulty_band: DifficultyBand,
    pub content: String,
    pub response_kind: String,
    pub expected_response: i32,
    pub correction_cue: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub steps: Vec<FactStep>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub answer_prompt: Option<String>,
    /// Each square takes the next working field, followed by the answer.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub equation: Option<String>,
}

/// A required working field in a stored fact. Only its id and prompt go to the learner.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FactStep {
    pub item_id: String,
    pub prompt: String,
    pub expected_response: i32,
    pub correction_cue: String,
}

pub use arithmetic_fact_fluency_v1::check_fact_responses;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DifficultyCoverage {
    pub difficulty_band: DifficultyBand,
    pub item_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActivityCoverage {
    pub required_family_keys: Vec<String>,
    pub covered_family_keys: Vec<String>,
    pub required_difficulty_bands: Vec<DifficultyBand>,
    pub difficulty_counts: Vec<DifficultyCoverage>,
    pub foundation_item_cap: usize,
    pub adaptive_item_cap: usize,
    pub adaptive_item_count: usize,
    pub requirements_met: bool,
    /// Only a check plan can be representative evidence for skill confirmation.
    pub representative: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GeneratedActivity {
    pub generation_context: GenerationContext,
    pub runtime_id: String,
    pub engine_id: String,
    pub template_id: String,
    pub instructions: String,
    pub items: Vec<GeneratedActivityItem>,
    pub coverage: ActivityCoverage,
    pub target_accuracy: f64,
    pub max_duration_seconds: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub written_plan: Option<written_arithmetic::StoredWorksheet>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub package_descriptor: Option<serde_json::Value>,
}

impl GeneratedActivity {
    pub fn has_fact_working(&self) -> bool {
        self.items
            .iter()
            .any(|item| item.answer_prompt.is_some() || !item.steps.is_empty())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FactResult {
    pub fact_key: String,
    pub family_keys: Vec<String>,
    pub difficulty_band: DifficultyBand,
    pub attempted_count: usize,
    pub correct_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FamilyResult {
    pub family_key: String,
    pub attempted_count: usize,
    pub correct_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActivityCorrection {
    pub item_id: String,
    pub content: String,
    pub submitted_response: String,
    pub expected_response: i32,
    pub fact_key: String,
    pub family_keys: Vec<String>,
    pub correction_cue: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ScoredActivity {
    pub attempted_count: usize,
    pub correct_count: usize,
    pub item_count: usize,
    pub accuracy: f64,
    pub target_met: bool,
    pub completion_reason: String,
    pub weak_family_keys: Vec<String>,
    pub fact_results: Vec<FactResult>,
    pub family_results: Vec<FamilyResult>,
    pub corrections: Vec<ActivityCorrection>,
}

pub type ValidateRuntimeFn = fn(&MaterialRuntime) -> anyhow::Result<()>;
pub type GenerateActivityFn = fn(&MaterialRuntime, &GenerationContext) -> anyhow::Result<GeneratedActivity>;
pub type ScoreActivityFn = fn(&GeneratedActivity, &[ActivityResponseInput]) -> ScoredActivity;

#[derive(Debug, Clone, Copy)]
pub struct RuntimeProgramRegistration {
    pub runtime_id: &'static str,
    pub engine_id: &'static str,
    pub template_id: &'static str,
    pub validate: ValidateRuntimeFn,
    pub generate: GenerateActivityFn,
    pub score: ScoreActivityFn,
}

pub fn build_runtime_id(engine_id: &str, template_id: &str) -> String {
    format!("{engine_id}/{template_id}")
}

pub fn activity_seed() -> u64 {
    let raw = Uuid::new_v4().as_u128();
    (raw as u64) ^ ((raw >> 64) as u64)
}

pub fn validate_material_runtime(material: &MaterialDocument) -> anyhow::Result<()> {
    let runtime = material
        .runtime
        .as_ref()
        .ok_or_else(|| anyhow!("material '{}' is not executable", material.id))?;
    validate_runtime(runtime).with_context(|| format!("material '{}' has an invalid runtime", material.id))
}

pub fn validate_runtime(runtime: &MaterialRuntime) -> anyhow::Result<()> {
    if runtime.engine_id == written_arithmetic::ENGINE_ID {
        return written_arithmetic::validate_runtime(runtime);
    }
    let program = resolve_program(runtime)?;
    (program.validate)(runtime).with_context(|| format!("runtime '{}' is invalid", program.runtime_id))
}

pub fn generate_activity(
    material: &MaterialDocument,
    context: &GenerationContext,
) -> anyhow::Result<GeneratedActivity> {
    let runtime = material
        .runtime
        .as_ref()
        .ok_or_else(|| anyhow!("material '{}' is not executable", material.id))?;
    if runtime.engine_id == written_arithmetic::ENGINE_ID {
        return written_arithmetic::generate_activity(runtime, context);
    }
    let program = resolve_program(runtime)?;
    let mut generated = (program.generate)(runtime, context)
        .with_context(|| format!("runtime '{}' failed to generate activity", program.runtime_id))?;
    // A missed checkpoint fact is retaught with working. Its recall timer belongs to the check.
    if material.kind == "quick_check" && context.run_mode == RunMode::Retry && generated.has_fact_working() {
        generated.max_duration_seconds = None;
    }
    Ok(generated)
}

pub fn score_activity(
    material: &MaterialDocument,
    generated: &GeneratedActivity,
    responses: &[ActivityResponseInput],
) -> anyhow::Result<ScoredActivity> {
    let runtime = material
        .runtime
        .as_ref()
        .ok_or_else(|| anyhow!("material '{}' is not executable", material.id))?;
    if generated.engine_id == written_arithmetic::ENGINE_ID {
        if runtime.engine_id != generated.engine_id {
            bail!("stored activity runtime does not match its material");
        }
        return written_arithmetic::score_activity(generated, responses);
    }
    let program = resolve_program(runtime)?;
    if generated.runtime_id != program.runtime_id {
        bail!(
            "activity runtime '{}' does not match material runtime '{}'",
            generated.runtime_id,
            program.runtime_id,
        );
    }
    validate_fact_response_ids(generated, responses)?;
    Ok((program.score)(generated, responses))
}

fn validate_fact_response_ids(
    generated: &GeneratedActivity,
    responses: &[ActivityResponseInput],
) -> anyhow::Result<()> {
    let mut generated_item_ids = BTreeSet::new();
    for item in &generated.items {
        if item.fact_key.trim().is_empty() {
            bail!("generated activity item '{}' has an empty fact_key", item.item_id);
        }
        for id in std::iter::once(&item.item_id).chain(item.steps.iter().map(|step| &step.item_id)) {
            if !generated_item_ids.insert(id.as_str()) {
                bail!("generated activity contains duplicate item_id '{id}'");
            }
        }
    }
    let mut response_item_ids = BTreeSet::new();
    for response in responses {
        if !response_item_ids.insert(response.item_id.as_str()) {
            bail!("duplicate response item_id '{}'", response.item_id);
        }
        if !generated_item_ids.contains(response.item_id.as_str()) {
            bail!("unknown response item_id '{}'", response.item_id);
        }
    }
    Ok(())
}

pub fn resolve_program(runtime: &MaterialRuntime) -> anyhow::Result<&'static RuntimeProgramRegistration> {
    let runtime_id = build_runtime_id(&runtime.engine_id, &runtime.template_id);
    if runtime.spec_version != 1 {
        bail!(
            "unsupported runtime spec_version {} for '{}'; expected 1",
            runtime.spec_version,
            runtime_id
        );
    }
    registered_programs()
        .iter()
        .find(|program| program.engine_id == runtime.engine_id && program.template_id == runtime.template_id)
        .ok_or_else(|| anyhow!("unsupported runtime '{runtime_id}'"))
}

fn registered_programs() -> &'static [RuntimeProgramRegistration] {
    arithmetic_fact_fluency_v1::PROGRAMS
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    use catalog::{MaterialRuntimeReadiness, MaterialRuntimeScoring};
    use serde_json::Value as JsonValue;
    use serde_json::json;

    use super::*;

    fn build_material(template_id: &str, parameters: JsonValue) -> MaterialDocument {
        MaterialDocument {
            checkpoint: None,
            id: format!("test_{template_id}"),
            kind: "drill".to_string(),
            subject_id: "maths".to_string(),
            area_id: "arithmetic".to_string(),
            skill_ids: vec!["skill".to_string()],
            stage_ids: vec!["stage".to_string()],
            recommended_age: 7,
            difficulty: "introductory".to_string(),
            estimated_minutes: 5,
            runtime: Some(MaterialRuntime {
                presentation: None,
                engine_id: "arithmetic_fact_fluency.v1".to_string(),
                spec_version: 1,
                template_id: template_id.to_string(),
                parameters,
                scoring: Some(MaterialRuntimeScoring {
                    target_accuracy: Some(0.8),
                    max_duration_seconds: None,
                }),
                readiness: None,
                gate: None,
            }),
            title: "Test runtime".to_string(),
            body: String::new(),
            source_path: "test.md".to_string(),
        }
    }

    fn multiplication_material(question_count: usize) -> MaterialDocument {
        build_material(
            "multiplication_tables_to_10",
            json!({
                "question_count": question_count,
                "table_min": 2,
                "table_max": 10,
                "max_multiplier": 10,
                "include_zero_facts": true,
                "include_one_facts": true,
                "allow_commuted": true
            }),
        )
    }

    fn bridge_addition_material(question_count: usize) -> MaterialDocument {
        build_material(
            "bridge_through_10_addition",
            json!({
                "question_count": question_count,
                "difficulty": "advanced"
            }),
        )
    }

    fn fact_keys(activity: &GeneratedActivity) -> BTreeSet<String> {
        activity.items.iter().map(|item| item.fact_key.clone()).collect()
    }

    #[test]
    fn guided_bridge_grades_the_split_and_the_answer_as_one_fact() {
        let material = build_material("bridge_through_10_subtraction", json!({"difficulty": "advanced"}));
        let context = GenerationContext::retry(16).with_focus_facts(["subtraction:16-7".into()]);
        let run = generate_activity(&material, &context).unwrap();
        let fact = run
            .items
            .iter()
            .find(|item| item.fact_key == "subtraction:16-7")
            .unwrap();
        assert_eq!(
            fact.steps.iter().map(|s| s.expected_response).collect::<Vec<_>>(),
            [6, 1]
        );
        assert_eq!(fact.expected_response, 9);

        let mut answers = Vec::new();
        for item in &run.items {
            for step in &item.steps {
                answers.push(ActivityResponseInput {
                    item_id: step.item_id.clone(),
                    value: step.expected_response.to_string(),
                });
            }
            answers.push(ActivityResponseInput {
                item_id: item.item_id.clone(),
                value: item.expected_response.to_string(),
            });
        }
        let full = score_activity(&material, &run, &answers).unwrap();
        assert_eq!(full.correct_count, run.items.len());
        assert!(full.target_met);
        let idx = answers.iter().position(|r| r.item_id == fact.steps[1].item_id).unwrap();
        answers[idx].value = "3".into();
        let partial = check_fact_responses(&run, &answers[idx..=idx], false).unwrap();
        assert_eq!(partial.total_count, 1);
        assert_eq!(partial.feedback[0].expected.as_deref(), Some("1"));
        assert_eq!(partial.feedback[0].cell_id, fact.steps[1].item_id);
        let score = score_activity(&material, &run, &answers).unwrap();
        assert_eq!(score.correct_count, score.item_count - 1);
        assert_eq!(score.corrections[0].item_id, fact.steps[1].item_id);
        assert_eq!(score.corrections[0].expected_response, 1);
        assert_eq!(score.corrections[0].fact_key, fact.fact_key);
        answers.remove(idx);
        let missing = score_activity(&material, &run, &answers).unwrap();
        assert_eq!(missing.completion_reason, "partial_submission");
        assert!(!missing.target_met);
        let finish = check_fact_responses(&run, &answers, true).unwrap();
        assert_eq!(finish.correct_count + 1, finish.total_count);
        answers.push(answers[0].clone());
        assert!(check_fact_responses(&run, &answers, false).is_err());
        assert!(score_activity(&material, &run, &answers).is_err());
    }

    #[test]
    fn quick_ways_practises_all_four_moves_and_checks_them_without_working_prompts() {
        let material = build_material("quick_ten_and_nine", json!({"question_count": 8}));
        for context in [GenerationContext::practice(9), GenerationContext::check(9)] {
            let run = generate_activity(&material, &context).unwrap();
            let mut moves = BTreeSet::new();
            for item in &run.items {
                let parts: Vec<_> = item.content.split_whitespace().collect();
                let start = parts[0].parse::<i32>().unwrap();
                let delta = parts[2].parse::<i32>().unwrap() * if parts[1] == "+" { 1 } else { -1 };
                moves.insert(delta);
                assert_eq!(item.expected_response, start + delta);
                if context.run_mode == RunMode::Practice && delta.abs() == 9 {
                    assert_eq!(item.steps.len(), 1);
                    assert_eq!(item.steps[0].expected_response, start + 10 * delta.signum());
                    assert_eq!(item.equation.as_deref().unwrap().matches('□').count(), 2);
                } else {
                    assert!(item.steps.is_empty() && item.equation.is_none());
                }
            }
            assert_eq!(moves, BTreeSet::from([-10, -9, 9, 10]));
        }
    }

    #[test]
    fn addition_steps_match_the_displayed_order_and_checkpoints_stay_independent() {
        let mut material = bridge_addition_material(14);
        let run = generate_activity(&material, &GenerationContext::practice(8)).unwrap();
        for (index, item) in run.items.iter().enumerate() {
            let mut parts = item.content.split_whitespace();
            let left: i32 = parts.next().unwrap().parse().unwrap();
            let right: i32 = parts.nth(1).unwrap().parse().unwrap();
            let step_count = match index {
                0..4 => 2,
                4..9 => 1,
                _ => 0,
            };
            assert_eq!(item.steps.len(), step_count);
            let equation = match step_count {
                2 => Some(format!("{left} + {right} = {left} + □ + □ = □")),
                1 => Some(format!("{left} + {right} = {left} + {} + □ = □", 10 - left)),
                _ => None,
            };
            assert_eq!(item.equation, equation);
            assert_eq!(item.answer_prompt.is_some(), step_count > 0);
            if step_count == 2 {
                assert_eq!(left + item.steps[0].expected_response, 10);
            }
            if let Some(rest) = item.steps.last() {
                assert!(rest.prompt.contains("reach 10"));
                assert_eq!(10 - left + rest.expected_response, right);
                assert_eq!(10 + rest.expected_response, item.expected_response);
            }
        }

        for context in [GenerationContext::check(8), GenerationContext::review(8)] {
            let recall = generate_activity(&material, &context).unwrap();
            assert!(
                recall
                    .items
                    .iter()
                    .all(|i| i.steps.is_empty() && i.answer_prompt.is_none() && i.equation.is_none())
            );
            assert!(check_fact_responses(&recall, &[], false).is_err());
        }
        material.runtime.as_mut().unwrap().presentation = Some(catalog::MaterialPresentation {
            package_id: "numeric-questions".into(),
            version: "1.0.0".into(),
        });
        let scalar = generate_activity(&material, &GenerationContext::practice(8)).unwrap();
        let persisted = serde_json::to_value(&scalar).unwrap();
        assert!(persisted["items"][0].get("steps").is_none());
        assert!(persisted["items"][0].get("answer_prompt").is_none());
        let loaded = serde_json::from_value::<GeneratedActivity>(persisted).unwrap();
        let answers = loaded
            .items
            .iter()
            .map(|item| ActivityResponseInput {
                item_id: item.item_id.clone(),
                value: item.expected_response.to_string(),
            })
            .collect::<Vec<_>>();
        assert!(score_activity(&material, &loaded, &answers).unwrap().target_met);
    }

    #[test]
    fn within_ten_uses_related_facts_without_asking_for_the_answer_twice() {
        let material = build_material("mixed_add_sub_to_10", json!({"item_forms": ["equation"]}));
        let context = GenerationContext::retry(5).with_focus_facts(["subtraction:8-3".into(), "addition:3+4".into()]);
        let run = generate_activity(&material, &context).unwrap();
        let subtraction = run.items.iter().find(|i| i.fact_key == "subtraction:8-3").unwrap();
        assert!(subtraction.steps.is_empty());
        assert!(subtraction.answer_prompt.as_ref().unwrap().contains("3 + □ = 8"));
        assert_eq!(subtraction.expected_response, 5);
        let near_double = run.items.iter().find(|i| i.fact_key == "addition:3+4").unwrap();
        assert_eq!(near_double.steps.len(), 1);
        assert_eq!(near_double.steps[0].expected_response, 6);
        assert_eq!(near_double.expected_response, 7);
    }

    #[test]
    fn authored_foundation_drills_reach_their_coverage_gate_and_launch_independent_checks() {
        let content = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../content");
        let (library, _) = catalog::load_library_bundle(&content).unwrap();
        for id in [
            "fact_families_to_10",
            "doubles_and_add_10",
            "bridge_through_10_addition",
            "bridge_through_10_subtraction",
        ] {
            let drill = library.material(&format!("{id}_drill")).unwrap();
            let check = library.material(&format!("{id}_check")).unwrap();
            validate_material_runtime(drill).unwrap();
            validate_material_runtime(check).unwrap();
            let target = drill.runtime.as_ref().unwrap().readiness.as_ref().unwrap();
            for sequence in 0..32 {
                let mut seen = BTreeSet::new();
                for offset in 1..=target.recent_run_window {
                    let context = GenerationContext::practice((sequence * target.recent_run_window + offset) as u64)
                        .with_seen_facts(seen.iter().cloned());
                    let run = generate_activity(drill, &context).unwrap_or_else(|e| panic!("{id} {sequence}: {e:#}"));
                    assert!(run.items.iter().any(|item| item.answer_prompt.is_some()));
                    assert!(run.coverage.requirements_met);
                    assert!(run.items.len() >= target.target_correct_count.unwrap());
                    seen.extend(fact_keys(&run));
                }
                assert!(
                    seen.len() >= target.minimum_distinct_items,
                    "{id} sequence {sequence}: {}",
                    seen.len()
                );
            }
            let independent = generate_activity(check, &GenerationContext::check(23)).unwrap();
            assert!(independent.coverage.representative);
            assert!(!independent.has_fact_working());
            assert!(independent.max_duration_seconds.is_some());
            let retry = generate_activity(
                check,
                &GenerationContext::retry(24).with_focus_facts([independent.items[0].fact_key.clone()]),
            )
            .unwrap();
            assert!(retry.has_fact_working());
            assert!(retry.max_duration_seconds.is_none());
        }
    }

    #[test]
    fn repeat_bridge_drills_meet_coverage_even_when_weak_families_fill_the_adaptive_quota() {
        let material = bridge_addition_material(14);
        for seed in 1..=256 {
            let previous = generate_activity(&material, &GenerationContext::practice(seed)).unwrap();
            let missed = previous.items.iter().take((seed % 13) as usize);
            let weak_facts = missed.clone().map(|item| item.fact_key.clone());
            let weak_families = missed
                .flat_map(|item| item.family_keys.clone())
                .collect::<BTreeSet<_>>();
            let context = GenerationContext::practice(seed + 996)
                .with_seen_facts(fact_keys(&previous))
                .with_weak_facts(weak_facts)
                .with_weak_families(weak_families.into_iter().take(8));
            let repeat = generate_activity(&material, &context).unwrap_or_else(|e| panic!("{seed}: {e:#}"));
            assert!(repeat.coverage.requirements_met);
        }
    }

    #[test]
    fn resolves_program_by_engine_and_template() {
        let material = build_material(
            "mixed_add_sub_to_10",
            json!({
                "question_count": 4,
                "operations": ["addition", "subtraction"],
                "item_forms": ["equation"]
            }),
        );

        let runtime = material.runtime.as_ref().expect("runtime");
        let program = resolve_program(runtime).expect("program");

        assert_eq!(program.runtime_id, "arithmetic_fact_fluency.v1/mixed_add_sub_to_10");
    }

    #[test]
    fn generated_plan_is_deterministic_and_serde_round_trips() {
        let material = build_material(
            "mixed_add_sub_to_10",
            json!({
                "question_count": 10,
                "operations": ["addition", "subtraction"],
                "item_forms": ["equation", "bond_missing"]
            }),
        );
        let context = GenerationContext::practice(42);

        let first = generate_activity(&material, &context).expect("first generation");
        let second = generate_activity(&material, &context).expect("second generation");
        let encoded = serde_json::to_value(&first).expect("serialize generated plan");
        let decoded: GeneratedActivity = serde_json::from_value(encoded).expect("deserialize generated plan");

        assert_eq!(first, second);
        assert_eq!(first, decoded);
    }

    #[test]
    fn every_template_has_balanced_unique_plans_across_seeds() {
        let templates = [
            ("readiness_within_5", json!({ "question_count": 10 })),
            (
                "anchor_facts_to_20",
                json!({ "question_count": 10, "modes": ["double", "add_10"] }),
            ),
            (
                "bridge_through_10_addition",
                json!({ "question_count": 10, "difficulty": "advanced" }),
            ),
            (
                "bridge_through_10_subtraction",
                json!({ "question_count": 10, "difficulty": "advanced" }),
            ),
            (
                "multiplication_tables_to_10",
                json!({
                    "question_count": 10,
                    "table_min": 2,
                    "table_max": 10,
                    "max_multiplier": 10,
                    "include_zero_facts": true,
                    "include_one_facts": true,
                    "allow_commuted": true
                }),
            ),
            (
                "division_facts_from_tables",
                json!({
                    "question_count": 10,
                    "divisor_min": 2,
                    "divisor_max": 10,
                    "max_quotient": 10,
                    "include_zero_dividend": true
                }),
            ),
            (
                "mixed_add_sub_to_10",
                json!({
                    "question_count": 10,
                    "operations": ["addition", "subtraction"],
                    "item_forms": ["equation", "bond_missing"],
                    "min_total": 1,
                    "max_total": 10,
                    "allow_zero": true
                }),
            ),
            (
                "mixed_add_sub_to_20",
                json!({
                    "question_count": 10,
                    "operations": ["addition", "subtraction"],
                    "item_forms": ["equation", "bond_missing", "missing_subtraction"]
                }),
            ),
        ];

        for (template_id, parameters) in templates {
            let material = build_material(template_id, parameters);
            validate_material_runtime(&material).unwrap_or_else(|error| panic!("{template_id}: {error:#}"));
            for seed in 1..=128 {
                for context in [GenerationContext::practice(seed), GenerationContext::check(seed)] {
                    let generated = generate_activity(&material, &context)
                        .unwrap_or_else(|error| panic!("{template_id} seed {seed}: {error:#}"));
                    assert_eq!(generated.items.len(), 10, "{template_id} seed {seed}");
                    assert_eq!(fact_keys(&generated).len(), 10, "{template_id} seed {seed}");
                    assert!(generated.coverage.requirements_met, "{template_id} seed {seed}");
                    assert_eq!(
                        generated.coverage.representative,
                        context.run_mode == RunMode::Check,
                        "{template_id} seed {seed}"
                    );
                    assert!(
                        generated.items.iter().all(|item| !item.fact_key.is_empty()
                            && !item.family_keys.is_empty()
                            && !item.correction_cue.is_empty()),
                        "{template_id} seed {seed}"
                    );
                }
            }
        }
    }

    #[test]
    fn multiplication_practice_has_hard_quotas_and_bounded_identity_facts() {
        let material = multiplication_material(14);
        let required_tables = (2..=10).map(|table| format!("table:{table}")).collect::<BTreeSet<_>>();

        for seed in 1..=1_000 {
            let generated = generate_activity(&material, &GenerationContext::practice(seed)).expect("practice plan");
            let foundation_count = generated
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Foundation)
                .count();
            let challenge_count = generated
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Challenge)
                .count();
            let covered = generated
                .coverage
                .covered_family_keys
                .iter()
                .cloned()
                .collect::<BTreeSet<_>>();
            assert!(foundation_count <= 2, "seed {seed}");
            assert!(challenge_count >= 4, "seed {seed}");
            assert!(required_tables.is_subset(&covered), "seed {seed}");
            assert_eq!(fact_keys(&generated).len(), 14, "seed {seed}");
        }
    }

    #[test]
    fn fourteen_item_anchor_plan_raises_foundation_cap_only_to_forced_minimum() {
        let material = build_material(
            "anchor_facts_to_20",
            json!({ "question_count": 14, "modes": ["double", "add_10"] }),
        );
        validate_material_runtime(&material).expect("14-item anchor runtime is feasible");

        for seed in 1..=512 {
            for context in [GenerationContext::practice(seed), GenerationContext::check(seed)] {
                let generated = generate_activity(&material, &context).expect("14-item anchor plan");
                let foundation_count = generated
                    .items
                    .iter()
                    .filter(|item| item.difficulty_band == DifficultyBand::Foundation)
                    .count();
                assert_eq!(generated.items.len(), 14, "seed {seed}");
                assert_eq!(fact_keys(&generated).len(), 14, "seed {seed}");
                assert_eq!(generated.coverage.foundation_item_cap, 3, "seed {seed}");
                assert_eq!(foundation_count, 3, "seed {seed}");
                assert!(generated.coverage.requirements_met, "seed {seed}");
            }
        }
    }

    #[test]
    fn representative_check_is_fixed_and_ignores_adaptive_focus() {
        let material = multiplication_material(10);
        let plain = generate_activity(&material, &GenerationContext::check(73)).expect("plain check");
        let focused = generate_activity(
            &material,
            &GenerationContext::check(73)
                .with_focus_facts(["multiplication:0x2".to_string(), "multiplication:1x3".to_string()])
                .with_weak_families(["table:2".to_string()])
                .with_seen_facts(plain.items.iter().map(|item| item.fact_key.clone())),
        )
        .expect("focused check");

        assert_eq!(plain.items, focused.items);
        assert!(plain.coverage.representative);
        assert_eq!(plain.coverage.adaptive_item_count, 0);
        assert_eq!(plain.coverage.adaptive_item_cap, 0);
        assert_eq!(
            plain
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Foundation)
                .count(),
            1
        );
        assert!(
            plain
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Challenge)
                .count()
                >= 3
        );
    }

    #[test]
    fn sequential_practice_prefers_unseen_facts_and_meets_readiness_coverage() {
        let material = multiplication_material(14);
        for sequence in 0..128_u64 {
            let mut seen = BTreeSet::new();
            for offset in 1..=3 {
                let seed = sequence * 3 + offset;
                let generated = generate_activity(
                    &material,
                    &GenerationContext::practice(seed).with_seen_facts(seen.iter().cloned()),
                )
                .expect("sequential practice");
                assert_eq!(fact_keys(&generated).len(), 14);
                assert!(generated.coverage.requirements_met);
                assert!(
                    generated
                        .items
                        .iter()
                        .filter(|item| item.difficulty_band == DifficultyBand::Foundation)
                        .count()
                        <= 2
                );
                assert!(
                    generated
                        .items
                        .iter()
                        .filter(|item| item.difficulty_band == DifficultyBand::Challenge)
                        .count()
                        >= 4
                );
                seen.extend(generated.items.into_iter().map(|item| item.fact_key));
            }

            assert!(
                seen.len() >= 28,
                "sequence {sequence} covered only {} facts in three runs",
                seen.len()
            );
        }
    }

    #[test]
    fn practice_adaptation_is_prioritized_but_capped() {
        let material = multiplication_material(14);
        let focus = [
            "multiplication:2x6",
            "multiplication:2x7",
            "multiplication:2x8",
            "multiplication:2x9",
            "multiplication:3x6",
            "multiplication:3x7",
            "multiplication:3x8",
            "multiplication:3x9",
        ]
        .into_iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
        let focus_set = focus.iter().cloned().collect::<BTreeSet<_>>();
        let generated = generate_activity(&material, &GenerationContext::practice(91).with_weak_facts(focus))
            .expect("adaptive practice");
        let selected_focus = generated
            .items
            .iter()
            .filter(|item| focus_set.contains(&item.fact_key))
            .count();

        assert!(selected_focus > 0);
        assert!(selected_focus <= generated.coverage.adaptive_item_cap);
        assert!(generated.coverage.adaptive_item_count <= generated.coverage.adaptive_item_cap);
        assert_eq!(generated.coverage.adaptive_item_cap, 6);
        assert!(generated.coverage.requirements_met);
    }

    #[test]
    fn completed_bridge_practice_can_generate_an_adaptive_repeat() {
        let material = bridge_addition_material(14);
        let context = GenerationContext::practice(1)
            .with_weak_facts([
                "addition:4+9".to_string(),
                "addition:5+9".to_string(),
                "addition:6+6".to_string(),
                "addition:6+8".to_string(),
                "addition:7+8".to_string(),
            ])
            .with_seen_facts([
                "addition:4+9".to_string(),
                "addition:5+6".to_string(),
                "addition:5+8".to_string(),
                "addition:6+6".to_string(),
                "addition:6+7".to_string(),
                "addition:6+9".to_string(),
                "addition:7+7".to_string(),
                "addition:7+8".to_string(),
                "addition:7+9".to_string(),
                "addition:8+8".to_string(),
                "addition:8+9".to_string(),
                "addition:9+9".to_string(),
            ])
            .with_weak_families([
                "bridge_start:6".to_string(),
                "bridge_start:7".to_string(),
                "bridge_start:9".to_string(),
                "bridge_through_10_for_addition".to_string(),
                "operation:addition".to_string(),
            ]);

        for seed in 1..=1_000 {
            let generated = generate_activity(
                &material,
                &GenerationContext {
                    seed,
                    ..context.clone()
                },
            )
            .unwrap_or_else(|error| panic!("repeat seed {seed}: {error:#}"));
            assert_eq!(generated.items.len(), 14, "seed {seed}");
            assert!(generated.coverage.requirements_met, "seed {seed}");
        }
    }

    #[test]
    fn retry_is_short_and_focuses_exact_facts_or_a_requested_family() {
        let material = multiplication_material(14);
        assert!(generate_activity(&material, &GenerationContext::retry(1)).is_err());
        let focus = [
            "multiplication:6x7".to_string(),
            "multiplication:6x8".to_string(),
            "multiplication:7x8".to_string(),
        ];
        let exact = generate_activity(&material, &GenerationContext::retry(9).with_focus_facts(focus.clone()))
            .expect("exact retry");
        assert_eq!(exact.items.len(), 3);
        assert!(focus.into_iter().all(|fact| fact_keys(&exact).contains(&fact)));
        assert!(!exact.coverage.representative);

        let family = generate_activity(
            &material,
            &GenerationContext::retry(11).with_focus_families(["table:7".to_string()]),
        )
        .expect("family retry");
        assert_eq!(family.items.len(), 5);
        assert!(
            family
                .items
                .iter()
                .all(|item| item.family_keys.contains(&"table:7".to_string()))
        );
    }

    #[test]
    fn review_keeps_balanced_harder_work_and_caps_family_focus() {
        let material = multiplication_material(14);
        let balanced = generate_activity(&material, &GenerationContext::review(17)).expect("balanced review");
        assert!(!balanced.coverage.representative);
        assert!(balanced.coverage.requirements_met);
        assert_eq!(balanced.coverage.adaptive_item_count, 0);
        assert!(
            balanced
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Foundation)
                .count()
                <= 2
        );
        assert!(
            balanced
                .items
                .iter()
                .filter(|item| item.difficulty_band == DifficultyBand::Challenge)
                .count()
                >= 4
        );

        let focused = generate_activity(
            &material,
            &GenerationContext::review(17).with_focus_families(["table:7".to_string()]),
        )
        .expect("focused review");
        let table_seven_count = focused
            .items
            .iter()
            .filter(|item| item.family_keys.contains(&"table:7".to_string()))
            .count();
        assert!(table_seven_count > 0);
        assert!(table_seven_count <= focused.coverage.adaptive_item_cap);
        assert_eq!(focused.coverage.adaptive_item_cap, 10);
        assert!(focused.coverage.adaptive_item_count <= focused.coverage.adaptive_item_cap);
        assert!(focused.coverage.requirements_met);
    }

    #[test]
    fn scoring_returns_compact_evidence_and_self_describing_corrections() {
        let material = multiplication_material(10);
        let generated = generate_activity(&material, &GenerationContext::check(101)).expect("check");
        let mut responses = generated
            .items
            .iter()
            .map(|item| ActivityResponseInput {
                item_id: item.item_id.clone(),
                value: item.expected_response.to_string(),
            })
            .collect::<Vec<_>>();
        responses[0].value = "-999".to_string();
        responses[1].value.clear();

        let scored = score_activity(&material, &generated, &responses).expect("score");
        assert_eq!(scored.attempted_count, 9);
        assert_eq!(scored.correct_count, 8);
        assert!(!scored.target_met);
        assert_eq!(scored.completion_reason, "partial_submission");
        assert_eq!(scored.fact_results.len(), 10);
        assert_eq!(scored.corrections.len(), 2);
        assert!(!scored.weak_family_keys.is_empty());
        assert!(scored.corrections.iter().all(|correction| {
            !correction.fact_key.is_empty()
                && !correction.family_keys.is_empty()
                && !correction.correction_cue.is_empty()
        }));
        assert!(
            scored
                .corrections
                .iter()
                .any(|correction| correction.submitted_response.is_empty())
        );

        let encoded = serde_json::to_value(&scored).expect("serialize score");
        let decoded: ScoredActivity = serde_json::from_value(encoded).expect("deserialize score");
        assert_eq!(scored, decoded);

        for (response, item) in responses.iter_mut().zip(&generated.items) {
            response.value = item.expected_response.to_string();
        }
        let perfect = score_activity(&material, &generated, &responses).expect("perfect score");
        assert!(perfect.target_met);
        assert_eq!(perfect.completion_reason, "target_met");
        assert!(perfect.corrections.is_empty());
    }

    #[test]
    fn scoring_rejects_duplicate_and_unknown_response_ids() {
        let material = multiplication_material(10);
        let generated = generate_activity(&material, &GenerationContext::practice(7)).expect("plan");
        let item_id = generated.items[0].item_id.clone();
        let duplicate = vec![
            ActivityResponseInput {
                item_id: item_id.clone(),
                value: "1".to_string(),
            },
            ActivityResponseInput {
                item_id,
                value: "2".to_string(),
            },
        ];
        assert!(score_activity(&material, &generated, &duplicate).is_err());
        assert!(
            score_activity(
                &material,
                &generated,
                &[ActivityResponseInput {
                    item_id: "not_in_plan".to_string(),
                    value: "1".to_string(),
                }]
            )
            .is_err()
        );
    }

    #[test]
    fn typed_parameter_contracts_reject_unknown_fields_for_every_template() {
        for template_id in [
            "readiness_within_5",
            "anchor_facts_to_20",
            "bridge_through_10_addition",
            "bridge_through_10_subtraction",
            "multiplication_tables_to_10",
            "division_facts_from_tables",
            "mixed_add_sub_to_10",
            "mixed_add_sub_to_20",
        ] {
            let material = build_material(template_id, json!({ "unexpected_parameter": true }));
            assert!(
                validate_material_runtime(&material).is_err(),
                "template {template_id} accepted an unknown parameter"
            );
        }
    }

    #[test]
    fn validation_rejects_invalid_ranges_modes_capacity_and_missing_target() {
        let reversed = build_material(
            "multiplication_tables_to_10",
            json!({ "question_count": 10, "table_min": 10, "table_max": 2, "max_multiplier": 10 }),
        );
        assert!(validate_material_runtime(&reversed).is_err());

        let bad_difficulty = build_material(
            "bridge_through_10_addition",
            json!({ "question_count": 10, "difficulty": "mystery" }),
        );
        assert!(validate_material_runtime(&bad_difficulty).is_err());

        let impossible_coverage = multiplication_material(8);
        assert!(validate_material_runtime(&impossible_coverage).is_err());

        let mut unsupported_version = multiplication_material(10);
        unsupported_version.runtime.as_mut().expect("runtime").spec_version = 2;
        assert!(validate_material_runtime(&unsupported_version).is_err());

        let mut missing_target = multiplication_material(10);
        missing_target.runtime.as_mut().expect("runtime").scoring = None;
        assert!(validate_material_runtime(&missing_target).is_err());

        let mut zero_target = multiplication_material(10);
        zero_target.runtime.as_mut().expect("runtime").scoring = Some(MaterialRuntimeScoring {
            target_accuracy: Some(0.0),
            max_duration_seconds: None,
        });
        assert!(validate_material_runtime(&zero_target).is_err());

        let mut zero_duration = multiplication_material(10);
        zero_duration.runtime.as_mut().expect("runtime").scoring = Some(MaterialRuntimeScoring {
            target_accuracy: Some(0.8),
            max_duration_seconds: Some(0),
        });
        assert!(validate_material_runtime(&zero_duration).is_err());
    }

    #[test]
    fn validation_rejects_impossible_readiness_evidence() {
        let readiness = |minimum_distinct_items, minimum_family_count, target_correct_count| MaterialRuntimeReadiness {
            minimum_runs: 3,
            recent_run_window: 3,
            target_accuracy: 0.85,
            consecutive_target_runs: 2,
            target_correct_count: Some(target_correct_count),
            minimum_distinct_items,
            minimum_family_count,
            max_duration_seconds: None,
        };

        let mut too_many_facts = multiplication_material(14);
        too_many_facts.runtime.as_mut().expect("runtime").readiness = Some(readiness(100, 9, 12));
        assert!(validate_material_runtime(&too_many_facts).is_err());

        let mut too_many_families = multiplication_material(14);
        too_many_families.runtime.as_mut().expect("runtime").readiness = Some(readiness(28, 10, 12));
        assert!(validate_material_runtime(&too_many_families).is_err());

        let mut too_many_for_window = multiplication_material(14);
        too_many_for_window.runtime.as_mut().expect("runtime").readiness = Some(readiness(50, 9, 12));
        assert!(validate_material_runtime(&too_many_for_window).is_err());

        let mut too_many_correct = multiplication_material(14);
        too_many_correct.runtime.as_mut().expect("runtime").readiness = Some(readiness(28, 9, 15));
        assert!(validate_material_runtime(&too_many_correct).is_err());
    }
}
