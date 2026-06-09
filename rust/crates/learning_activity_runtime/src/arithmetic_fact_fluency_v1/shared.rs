use std::collections::{BTreeMap, BTreeSet};

use anyhow::bail;
use catalog::MaterialRuntime;
use serde_json::json;

use crate::{ActivityResponseInput, GeneratedActivity, GeneratedActivityItem, ScoredActivity};

pub(super) const RESPONSE_KIND_INTEGER: &str = "integer";

#[derive(Debug, Clone)]
pub(super) struct ActivityRng {
    state: u64,
}

impl ActivityRng {
    pub(super) fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 1 } else { seed },
        }
    }

    pub(super) fn next_u32(&mut self) -> u32 {
        self.state = self
            .state
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        (self.state >> 32) as u32
    }

    pub(super) fn index(&mut self, len: usize) -> usize {
        if len <= 1 {
            return 0;
        }
        (self.next_u32() as usize) % len
    }

    pub(super) fn range_inclusive(&mut self, start: u32, end: u32) -> u32 {
        if start >= end {
            return start;
        }
        start + (self.next_u32() % (end - start + 1))
    }
}

pub(super) fn build_generated_activity(
    runtime: &MaterialRuntime,
    seed: u64,
    runtime_id: &str,
    instructions: String,
    items: Vec<GeneratedActivityItem>,
) -> GeneratedActivity {
    GeneratedActivity {
        seed,
        runtime_id: runtime_id.to_string(),
        engine_id: runtime.engine_id.clone(),
        template_id: runtime.template_id.clone(),
        instructions,
        items,
        pass_accuracy: runtime.scoring.as_ref().and_then(|scoring| scoring.pass_accuracy),
        soft_time_limit_seconds: runtime
            .scoring
            .as_ref()
            .and_then(|scoring| scoring.soft_time_limit_seconds),
        store_response_log: runtime
            .persistence
            .as_ref()
            .map(|persistence| persistence.store_response_log)
            .unwrap_or(false),
    }
}

pub(super) fn generate_unique_items(
    item_count: usize,
    attempt_multiplier: usize,
    rng: &mut ActivityRng,
    mut builder: impl FnMut(usize, &mut ActivityRng) -> GeneratedActivityItem,
) -> anyhow::Result<Vec<GeneratedActivityItem>> {
    let mut items = Vec::new();
    let mut seen = BTreeSet::new();
    let max_attempts = item_count.saturating_mul(attempt_multiplier).max(item_count);
    for index in 0..max_attempts {
        if items.len() >= item_count {
            break;
        }
        let item = builder(items.len(), rng);
        if seen.insert(item.content.clone()) {
            items.push(item);
        }
        if index + 1 == max_attempts && items.len() < item_count {
            bail!("unable to generate enough unique items");
        }
    }
    Ok(items)
}

pub(super) fn parameter_usize(runtime: &MaterialRuntime, key: &str) -> Option<usize> {
    runtime.parameters.get(key)?.as_u64().map(|value| value as usize)
}

pub(super) fn parameter_bool(runtime: &MaterialRuntime, key: &str) -> Option<bool> {
    runtime.parameters.get(key)?.as_bool()
}

pub(super) fn parameter_string(runtime: &MaterialRuntime, key: &str) -> Option<String> {
    runtime.parameters.get(key)?.as_str().map(ToOwned::to_owned)
}

pub(super) fn parameter_string_list(runtime: &MaterialRuntime, key: &str) -> Option<Vec<String>> {
    parameter_string_list_for_keys(runtime, &[key])
}

pub(super) fn item_forms(runtime: &MaterialRuntime) -> Option<Vec<String>> {
    parameter_string_list_for_keys(runtime, &["item_forms", "prompt_forms"])
}

fn parameter_string_list_for_keys(runtime: &MaterialRuntime, keys: &[&str]) -> Option<Vec<String>> {
    for key in keys {
        let values = runtime.parameters.get(key)?.as_array()?;
        let items = values
            .iter()
            .filter_map(|value| value.as_str().map(ToOwned::to_owned))
            .collect::<Vec<_>>();
        if !items.is_empty() {
            return Some(items);
        }
    }
    None
}

pub(super) fn integer_item(
    index: usize,
    content: String,
    expected_response: i32,
    family: &str,
) -> GeneratedActivityItem {
    GeneratedActivityItem {
        item_id: format!("item_{index}"),
        content,
        response_kind: RESPONSE_KIND_INTEGER.to_string(),
        expected_response,
        family: family.to_string(),
    }
}

pub(super) fn score_integer_activity(
    generated: &GeneratedActivity,
    responses: &[ActivityResponseInput],
) -> ScoredActivity {
    let responses_by_item = responses
        .iter()
        .map(|response| (response.item_id.as_str(), response.value.trim()))
        .collect::<BTreeMap<_, _>>();
    let mut attempted_count = 0usize;
    let mut correct_count = 0usize;
    let mut weak_group_counts = BTreeMap::<String, usize>::new();
    let mut response_log = Vec::new();

    for item in &generated.items {
        let submitted = responses_by_item.get(item.item_id.as_str()).copied().unwrap_or("");
        let parsed = submitted.parse::<i32>().ok();
        let is_attempted = !submitted.is_empty();
        let is_correct = parsed == Some(item.expected_response);
        if is_attempted {
            attempted_count += 1;
        }
        if is_correct {
            correct_count += 1;
        } else {
            *weak_group_counts.entry(item.family.clone()).or_insert(0) += 1;
        }
        response_log.push(json!({
            "item_id": item.item_id,
            "content": item.content,
            "submitted_response": submitted,
            "expected_response": item.expected_response,
            "correct": is_correct,
            "family": item.family,
        }));
    }

    let item_count = generated.items.len();
    let accuracy = if item_count == 0 {
        0.0
    } else {
        correct_count as f64 / item_count as f64
    };
    let passed = generated
        .pass_accuracy
        .map(|threshold| accuracy >= threshold)
        .unwrap_or(accuracy >= 0.8);
    let completion_reason = if attempted_count < item_count {
        "partial_submission".to_string()
    } else if passed {
        "pass_threshold_met".to_string()
    } else {
        "completed_below_threshold".to_string()
    };
    let mut weak_groups = weak_group_counts.into_iter().collect::<Vec<_>>();
    weak_groups.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(&right.0)));

    ScoredActivity {
        attempted_count,
        correct_count,
        item_count,
        accuracy,
        passed,
        completion_reason,
        weak_groups: weak_groups.into_iter().map(|(group, _)| group).collect(),
        response_log,
    }
}
