use std::collections::{BTreeMap, BTreeSet};

use anyhow::{Context, bail};
use catalog::MaterialRuntime;
use serde::de::DeserializeOwned;

use crate::{
    ActivityCorrection, ActivityCoverage, ActivityResponseInput, DifficultyBand, DifficultyCoverage, FactResult,
    FamilyResult, GeneratedActivity, GeneratedActivityItem, GenerationContext, RunMode, ScoredActivity,
};

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

    pub(super) fn shuffle<T>(&mut self, values: &mut [T]) {
        for index in (1..values.len()).rev() {
            let other = self.index(index + 1);
            values.swap(index, other);
        }
    }
}

pub(super) fn parse_parameters<T: DeserializeOwned>(runtime: &MaterialRuntime) -> anyhow::Result<T> {
    let value = if runtime.parameters.is_null() {
        serde_json::json!({})
    } else {
        runtime.parameters.clone()
    };
    serde_json::from_value(value).with_context(|| format!("invalid parameters for template '{}'", runtime.template_id))
}

pub(super) fn validate_question_count(question_count: usize) -> anyhow::Result<()> {
    if !(1..=100).contains(&question_count) {
        bail!("question_count must be between 1 and 100");
    }
    Ok(())
}

pub(super) fn validate_candidate_capacity(
    question_count: usize,
    candidates: &[GeneratedActivityItem],
) -> anyhow::Result<()> {
    validate_question_count(question_count)?;
    let unique_count = candidates
        .iter()
        .map(|candidate| candidate.fact_key.as_str())
        .collect::<BTreeSet<_>>()
        .len();
    if unique_count < question_count {
        bail!("question_count {question_count} exceeds the template's capacity of {unique_count} semantic facts");
    }
    Ok(())
}

pub(super) fn validate_template(
    runtime: &MaterialRuntime,
    question_count: usize,
    candidates: &[GeneratedActivityItem],
    required_family_keys: &[String],
) -> anyhow::Result<()> {
    validate_candidate_capacity(question_count, candidates)?;
    let scoring = runtime.scoring.as_ref().context("runtime scoring is required")?;
    let target_accuracy = scoring
        .target_accuracy
        .context("runtime scoring.target_accuracy is required")?;
    if !(0.0 < target_accuracy && target_accuracy <= 1.0) {
        bail!("scoring.target_accuracy must be greater than 0 and at most 1");
    }
    if scoring.max_duration_seconds == Some(0) {
        bail!("scoring.max_duration_seconds must be greater than 0 when provided");
    }

    if let Some(readiness) = &runtime.readiness {
        if readiness.minimum_runs == 0
            || readiness.recent_run_window == 0
            || readiness.consecutive_target_runs == 0
            || readiness.minimum_distinct_items == 0
            || readiness.minimum_family_count == 0
        {
            bail!("readiness run, coverage, and consecutive-run requirements must be greater than 0");
        }
        if !(0.0 < readiness.target_accuracy && readiness.target_accuracy <= 1.0) {
            bail!("readiness.target_accuracy must be greater than 0 and at most 1");
        }
        if readiness.max_duration_seconds == Some(0) {
            bail!("readiness.max_duration_seconds must be greater than 0 when provided");
        }
        if readiness.consecutive_target_runs > readiness.recent_run_window {
            bail!("readiness.consecutive_target_runs must not exceed recent_run_window");
        }
        if readiness.consecutive_target_runs > readiness.minimum_runs {
            bail!("readiness.consecutive_target_runs must not exceed minimum_runs");
        }
        let unique_fact_count = candidates
            .iter()
            .map(|candidate| candidate.fact_key.as_str())
            .collect::<BTreeSet<_>>()
            .len();
        if readiness.minimum_distinct_items > unique_fact_count {
            bail!(
                "readiness.minimum_distinct_items {} exceeds the template capacity of {unique_fact_count}",
                readiness.minimum_distinct_items
            );
        }
        if readiness.minimum_distinct_items > question_count.saturating_mul(readiness.recent_run_window) {
            bail!(
                "readiness.minimum_distinct_items {} exceeds the recent run window capacity of {}",
                readiness.minimum_distinct_items,
                question_count.saturating_mul(readiness.recent_run_window)
            );
        }
        if readiness.minimum_family_count > required_family_keys.iter().collect::<BTreeSet<_>>().len() {
            bail!(
                "readiness.minimum_family_count {} exceeds the representative family capacity",
                readiness.minimum_family_count
            );
        }
        if readiness
            .target_correct_count
            .is_some_and(|target| target > question_count)
        {
            bail!("readiness.target_correct_count must not exceed question_count");
        }
    }

    // Validate both balanced policies during library loading rather than failing when a learner starts a run.
    select_items(
        candidates.to_vec(),
        question_count,
        &sorted_unique(required_family_keys.to_vec()),
        &GenerationContext::practice(1),
    )?;
    select_items(
        candidates.to_vec(),
        question_count,
        &sorted_unique(required_family_keys.to_vec()),
        &GenerationContext::check(1),
    )?;
    select_items(
        candidates.to_vec(),
        question_count,
        &sorted_unique(required_family_keys.to_vec()),
        &GenerationContext::review(1),
    )?;
    Ok(())
}

pub(super) fn integer_candidate(
    fact_key: impl Into<String>,
    family_keys: impl IntoIterator<Item = String>,
    coverage_keys: impl IntoIterator<Item = String>,
    difficulty_band: DifficultyBand,
    content: impl Into<String>,
    expected_response: i32,
    correction_cue: impl Into<String>,
) -> GeneratedActivityItem {
    GeneratedActivityItem {
        item_id: String::new(),
        fact_key: fact_key.into(),
        family_keys: sorted_unique(family_keys),
        coverage_keys: sorted_unique(coverage_keys),
        difficulty_band,
        content: content.into(),
        response_kind: RESPONSE_KIND_INTEGER.to_string(),
        expected_response,
        correction_cue: correction_cue.into(),
    }
}

pub(super) fn addition_fact_key(left: i32, right: i32) -> String {
    let (first, second) = if left <= right { (left, right) } else { (right, left) };
    format!("addition:{first}+{second}")
}

pub(super) fn multiplication_fact_key(left: i32, right: i32) -> String {
    let (first, second) = if left <= right { (left, right) } else { (right, left) };
    format!("multiplication:{first}x{second}")
}

pub(super) fn build_generated_activity(
    runtime: &MaterialRuntime,
    context: &GenerationContext,
    runtime_id: &str,
    instructions: String,
    question_count: usize,
    candidates: Vec<GeneratedActivityItem>,
    required_family_keys: Vec<String>,
) -> anyhow::Result<GeneratedActivity> {
    validate_candidate_capacity(question_count, &candidates)?;
    let (items, coverage) = select_items(
        candidates,
        question_count,
        &sorted_unique(required_family_keys),
        context,
    )?;

    Ok(GeneratedActivity {
        generation_context: context.clone(),
        runtime_id: runtime_id.to_string(),
        engine_id: runtime.engine_id.clone(),
        template_id: runtime.template_id.clone(),
        instructions,
        items,
        coverage,
        target_accuracy: runtime
            .scoring
            .as_ref()
            .and_then(|scoring| scoring.target_accuracy)
            .context("runtime scoring.target_accuracy is required")?,
        max_duration_seconds: runtime
            .scoring
            .as_ref()
            .and_then(|scoring| scoring.max_duration_seconds),
    })
}

fn select_items(
    mut candidates: Vec<GeneratedActivityItem>,
    configured_item_count: usize,
    required_family_keys: &[String],
    context: &GenerationContext,
) -> anyhow::Result<(Vec<GeneratedActivityItem>, ActivityCoverage)> {
    candidates.sort_by(|left, right| {
        left.fact_key
            .cmp(&right.fact_key)
            .then_with(|| left.content.cmp(&right.content))
    });
    let mut rng = ActivityRng::new(context.seed);
    rng.shuffle(&mut candidates);

    let focus_fact_keys = context
        .focus_fact_keys
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let weak_fact_keys = context
        .weak_fact_keys
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let seen_fact_keys = context
        .seen_fact_keys
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let exact_requested = focus_fact_keys
        .iter()
        .chain(weak_fact_keys.iter())
        .copied()
        .collect::<BTreeSet<_>>();
    let matching_requested_count = candidates
        .iter()
        .filter(|candidate| exact_requested.contains(candidate.fact_key.as_str()))
        .map(|candidate| candidate.fact_key.as_str())
        .collect::<BTreeSet<_>>()
        .len();
    let item_count = if context.run_mode == RunMode::Retry {
        let retry_count = if matching_requested_count == 0 {
            5
        } else {
            matching_requested_count.clamp(3, 5)
        };
        configured_item_count.min(retry_count)
    } else {
        configured_item_count
    };

    let available_bands = candidates
        .iter()
        .map(|candidate| candidate.difficulty_band)
        .collect::<BTreeSet<_>>();
    let required_difficulty_bands = [
        DifficultyBand::Foundation,
        DifficultyBand::Core,
        DifficultyBand::Challenge,
    ]
    .into_iter()
    .filter(|band| available_bands.contains(band) && item_count >= available_bands.len())
    .collect::<Vec<_>>();
    let foundation_item_cap = if available_bands.contains(&DifficultyBand::Foundation) {
        let pedagogical_cap = (item_count / 7).max(1);
        let non_foundation_semantic_capacity = candidates
            .iter()
            .filter(|candidate| candidate.difficulty_band != DifficultyBand::Foundation)
            .map(|candidate| candidate.fact_key.as_str())
            .collect::<BTreeSet<_>>()
            .len();
        let forced_foundation_count = item_count.saturating_sub(non_foundation_semantic_capacity);
        pedagogical_cap.max(forced_foundation_count)
    } else {
        0
    };
    let adaptive_item_cap = match context.run_mode {
        RunMode::Check => 0,
        RunMode::Practice => (item_count * 2).div_ceil(5),
        RunMode::Review => (item_count * 7).div_ceil(10),
        RunMode::Retry => item_count,
    };
    let mut minimum_by_band = BTreeMap::new();
    for band in &required_difficulty_bands {
        let minimum = if *band == DifficultyBand::Challenge {
            (item_count / 3).max(1)
        } else {
            1
        };
        minimum_by_band.insert(*band, minimum);
    }

    let explicit_families = context
        .focus_family_keys
        .iter()
        .chain(context.weak_family_keys.iter())
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let pool_fact_count = candidates
        .iter()
        .map(|candidate| candidate.fact_key.as_str())
        .collect::<BTreeSet<_>>()
        .len();
    let related_families = explicit_families
        .into_iter()
        .filter(|family_key| {
            candidates
                .iter()
                .filter(|candidate| candidate.family_keys.iter().any(|key| key == *family_key))
                .map(|candidate| candidate.fact_key.as_str())
                .collect::<BTreeSet<_>>()
                .len()
                < pool_fact_count
        })
        .collect::<BTreeSet<_>>();
    if context.run_mode == RunMode::Retry && matching_requested_count == 0 && related_families.is_empty() {
        bail!("retry generation requires at least one matching focus or weak fact/family key");
    }

    let enforce_balance = matches!(context.run_mode, RunMode::Practice | RunMode::Check | RunMode::Review);
    let mut selected = Vec::with_capacity(item_count);
    let mut selected_fact_keys = BTreeSet::new();
    let mut covered = BTreeSet::new();
    let mut difficulty_counts = BTreeMap::<DifficultyBand, usize>::new();
    let mut adaptive_item_count = 0usize;

    while selected.len() < item_count {
        let mut best: Option<(usize, i64, bool)> = None;
        for (index, candidate) in candidates.iter().enumerate() {
            if selected_fact_keys.contains(candidate.fact_key.as_str()) {
                continue;
            }

            let coverage_gain = if enforce_balance {
                candidate
                    .coverage_keys
                    .iter()
                    .filter(|key| required_family_keys.contains(key) && !covered.contains(key.as_str()))
                    .count() as i64
            } else {
                0
            };
            let current_band_count = difficulty_counts.get(&candidate.difficulty_band).copied().unwrap_or(0);
            let band_deficit = minimum_by_band
                .get(&candidate.difficulty_band)
                .is_some_and(|minimum| current_band_count < *minimum);
            let over_foundation_cap = enforce_balance
                && candidate.difficulty_band == DifficultyBand::Foundation
                && current_band_count >= foundation_item_cap;
            let exact_focus = focus_fact_keys.contains(candidate.fact_key.as_str());
            let exact_weak = weak_fact_keys.contains(candidate.fact_key.as_str());
            let unseen_practice_fact =
                context.run_mode == RunMode::Practice && !seen_fact_keys.contains(candidate.fact_key.as_str());
            let related = candidate
                .family_keys
                .iter()
                .any(|key| related_families.contains(key.as_str()));
            let adaptive_match = exact_focus || exact_weak || related;
            let over_adaptive_cap = matches!(context.run_mode, RunMode::Practice | RunMode::Review)
                && adaptive_match
                && adaptive_item_count >= adaptive_item_cap;
            let allocate_adaptive = adaptive_match && !over_adaptive_cap;

            let mode_priority = match context.run_mode {
                RunMode::Check => 0,
                RunMode::Practice if allocate_adaptive && exact_focus => 30_000,
                RunMode::Practice if allocate_adaptive && exact_weak => 25_000,
                RunMode::Practice if allocate_adaptive && related => 8_000,
                RunMode::Practice => 0,
                RunMode::Review if allocate_adaptive && exact_focus => 80_000,
                RunMode::Review if allocate_adaptive && exact_weak => 70_000,
                RunMode::Review if allocate_adaptive && related => 40_000,
                RunMode::Review => 0,
                RunMode::Retry if exact_focus => 300_000,
                RunMode::Retry if exact_weak => 250_000,
                RunMode::Retry if related => 120_000,
                RunMode::Retry => 0,
            };
            let score = coverage_gain * 100_000
                + i64::from(band_deficit) * 20_000
                + i64::from(unseen_practice_fact) * 12_000
                + mode_priority
                - i64::from(over_foundation_cap) * 200_000
                - i64::from(over_adaptive_cap) * 300_000;
            if best.is_none_or(|(_, best_score, _)| score > best_score) {
                best = Some((index, score, allocate_adaptive));
            }
        }

        let Some((index, _, allocate_adaptive)) = best else {
            bail!("unable to select {item_count} unique semantic facts");
        };
        let candidate = candidates[index].clone();
        selected_fact_keys.insert(candidate.fact_key.clone());
        covered.extend(candidate.coverage_keys.iter().cloned());
        *difficulty_counts.entry(candidate.difficulty_band).or_insert(0) += 1;
        adaptive_item_count += usize::from(allocate_adaptive);
        selected.push(candidate);
    }

    let covered_required = required_family_keys
        .iter()
        .all(|required| covered.contains(required.as_str()));
    let difficulty_requirements_met = minimum_by_band
        .iter()
        .all(|(band, minimum)| difficulty_counts.get(band).copied().unwrap_or(0) >= *minimum);
    let foundation_cap_met =
        difficulty_counts.get(&DifficultyBand::Foundation).copied().unwrap_or(0) <= foundation_item_cap;
    let requirements_met = covered_required && difficulty_requirements_met && foundation_cap_met;
    if enforce_balance && !requirements_met {
        bail!(
            "unable to satisfy balanced coverage for mode {:?}; increase question_count or broaden the candidate ranges",
            context.run_mode
        );
    }

    rng.shuffle(&mut selected);
    for (index, item) in selected.iter_mut().enumerate() {
        item.item_id = format!("item_{index}");
    }
    let difficulty_counts = [
        DifficultyBand::Foundation,
        DifficultyBand::Core,
        DifficultyBand::Challenge,
    ]
    .into_iter()
    .map(|difficulty_band| DifficultyCoverage {
        difficulty_band,
        item_count: difficulty_counts.get(&difficulty_band).copied().unwrap_or(0),
    })
    .collect();
    let covered_family_keys = covered.into_iter().collect();
    let coverage = ActivityCoverage {
        required_family_keys: required_family_keys.to_vec(),
        covered_family_keys,
        required_difficulty_bands,
        difficulty_counts,
        foundation_item_cap,
        adaptive_item_cap,
        adaptive_item_count,
        requirements_met,
        representative: context.run_mode == RunMode::Check && requirements_met,
    };
    Ok((selected, coverage))
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
    let mut weak_family_counts = BTreeMap::<String, usize>::new();
    let mut facts = BTreeMap::<String, FactAccumulator>::new();
    let mut families = BTreeMap::<String, CountAccumulator>::new();
    let mut corrections = Vec::new();

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
        }

        let fact = facts.entry(item.fact_key.clone()).or_insert_with(|| FactAccumulator {
            family_keys: item.family_keys.clone(),
            difficulty_band: item.difficulty_band,
            counts: CountAccumulator::default(),
        });
        fact.counts.record(is_attempted, is_correct);
        for family_key in &item.family_keys {
            families
                .entry(family_key.clone())
                .or_default()
                .record(is_attempted, is_correct);
            if !is_correct {
                *weak_family_counts.entry(family_key.clone()).or_insert(0) += 1;
            }
        }

        if !is_correct {
            corrections.push(ActivityCorrection {
                item_id: item.item_id.clone(),
                content: item.content.clone(),
                submitted_response: submitted.to_string(),
                expected_response: item.expected_response,
                fact_key: item.fact_key.clone(),
                family_keys: item.family_keys.clone(),
                correction_cue: item.correction_cue.clone(),
            });
        }
    }

    let item_count = generated.items.len();
    let accuracy = if item_count == 0 {
        0.0
    } else {
        correct_count as f64 / item_count as f64
    };
    let target_met = attempted_count == item_count && accuracy >= generated.target_accuracy;
    let completion_reason = if attempted_count < item_count {
        "partial_submission".to_string()
    } else if target_met {
        "target_met".to_string()
    } else {
        "completed_below_target".to_string()
    };
    let mut weak_families = weak_family_counts.into_iter().collect::<Vec<_>>();
    weak_families.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(&right.0)));
    let fact_results = facts
        .into_iter()
        .map(|(fact_key, fact)| FactResult {
            fact_key,
            family_keys: fact.family_keys,
            difficulty_band: fact.difficulty_band,
            attempted_count: fact.counts.attempted_count,
            correct_count: fact.counts.correct_count,
        })
        .collect();
    let family_results = families
        .into_iter()
        .map(|(family_key, counts)| FamilyResult {
            family_key,
            attempted_count: counts.attempted_count,
            correct_count: counts.correct_count,
        })
        .collect();

    ScoredActivity {
        attempted_count,
        correct_count,
        item_count,
        accuracy,
        target_met,
        completion_reason,
        weak_family_keys: weak_families.into_iter().map(|(family, _)| family).collect(),
        fact_results,
        family_results,
        corrections,
    }
}

#[derive(Debug, Clone, Default)]
struct CountAccumulator {
    attempted_count: usize,
    correct_count: usize,
}

impl CountAccumulator {
    fn record(&mut self, attempted: bool, correct: bool) {
        self.attempted_count += usize::from(attempted);
        self.correct_count += usize::from(correct);
    }
}

struct FactAccumulator {
    family_keys: Vec<String>,
    difficulty_band: DifficultyBand,
    counts: CountAccumulator,
}

fn sorted_unique(values: impl IntoIterator<Item = String>) -> Vec<String> {
    values.into_iter().collect::<BTreeSet<_>>().into_iter().collect()
}
