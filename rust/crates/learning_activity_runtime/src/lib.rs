mod arithmetic_fact_fluency_v1;

use anyhow::{Context, anyhow, bail};
use catalog::{MaterialDocument, MaterialRuntime};
use serde_json::Value as JsonValue;
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct ActivityResponseInput {
    pub item_id: String,
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GeneratedActivityItem {
    pub item_id: String,
    pub content: String,
    pub response_kind: String,
    pub expected_response: i32,
    pub family: String,
}

#[derive(Debug, Clone)]
pub struct GeneratedActivity {
    pub seed: u64,
    pub runtime_id: String,
    pub engine_id: String,
    pub template_id: String,
    pub instructions: String,
    pub items: Vec<GeneratedActivityItem>,
    pub pass_accuracy: Option<f64>,
    pub soft_time_limit_seconds: Option<u32>,
    pub store_response_log: bool,
}

#[derive(Debug, Clone)]
pub struct ScoredActivity {
    pub attempted_count: usize,
    pub correct_count: usize,
    pub item_count: usize,
    pub accuracy: f64,
    pub passed: bool,
    pub completion_reason: String,
    pub weak_groups: Vec<String>,
    pub response_log: Vec<JsonValue>,
}

pub type GenerateActivityFn = fn(&MaterialRuntime, u64) -> anyhow::Result<GeneratedActivity>;
pub type ScoreActivityFn = fn(&GeneratedActivity, &[ActivityResponseInput]) -> ScoredActivity;

#[derive(Debug, Clone, Copy)]
pub struct RuntimeProgramRegistration {
    pub runtime_id: &'static str,
    pub engine_id: &'static str,
    pub template_id: &'static str,
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

pub fn build_activity_instance_id(session_material_id: &str, seed: u64) -> String {
    format!("{session_material_id}:{seed}")
}

pub fn parse_activity_instance_id(activity_instance_id: &str) -> anyhow::Result<(String, u64)> {
    let (session_material_id, seed) = activity_instance_id
        .rsplit_once(':')
        .ok_or_else(|| anyhow!("invalid activity instance id"))?;
    let parsed_seed = seed.parse::<u64>().context("invalid activity instance seed")?;
    Ok((session_material_id.to_string(), parsed_seed))
}

pub fn generate_activity(material: &MaterialDocument, seed: u64) -> anyhow::Result<GeneratedActivity> {
    let runtime = material
        .runtime
        .as_ref()
        .ok_or_else(|| anyhow!("material '{}' is not executable", material.id))?;
    let program = resolve_program(runtime)?;
    (program.generate)(runtime, seed)
        .with_context(|| format!("runtime '{}' failed to generate activity", program.runtime_id))
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
    let program = resolve_program(runtime)?;
    if generated.runtime_id != program.runtime_id {
        bail!(
            "activity runtime '{}' does not match material runtime '{}'",
            generated.runtime_id,
            program.runtime_id,
        );
    }
    Ok((program.score)(generated, responses))
}

pub fn resolve_program(runtime: &MaterialRuntime) -> anyhow::Result<&'static RuntimeProgramRegistration> {
    let runtime_id = build_runtime_id(&runtime.engine_id, &runtime.template_id);
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
    use serde_json::json;

    use super::*;

    fn build_material(template_id: &str, parameters: JsonValue) -> MaterialDocument {
        MaterialDocument {
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
                engine_id: "arithmetic_fact_fluency.v1".to_string(),
                spec_version: 1,
                template_id: template_id.to_string(),
                parameters,
                scoring: None,
                persistence: None,
                proficiency: None,
                gate: None,
            }),
            title: "Test runtime".to_string(),
            body: String::new(),
            source_path: "test.md".to_string(),
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
    fn generates_deterministic_items_for_same_seed() {
        let material = build_material(
            "mixed_add_sub_to_10",
            json!({
                "question_count": 4,
                "operations": ["addition", "subtraction"],
                "item_forms": ["equation", "bond_missing"]
            }),
        );

        let first = generate_activity(&material, 42).expect("first generation");
        let second = generate_activity(&material, 42).expect("second generation");

        let first_items = first
            .items
            .iter()
            .map(|item| (item.content.clone(), item.expected_response))
            .collect::<Vec<_>>();
        let second_items = second
            .items
            .iter()
            .map(|item| (item.content.clone(), item.expected_response))
            .collect::<Vec<_>>();

        assert_eq!(first.runtime_id, second.runtime_id);
        assert_eq!(first_items, second_items);
    }
}
