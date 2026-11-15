//! Small, deterministic written-methods practice. The server owns every cell and correction.
//! These worksheets are extra practice and never produce stored mastery evidence.

use std::collections::{BTreeMap, BTreeSet};

use anyhow::{Result, anyhow, ensure};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PracticeMode {
    Assisted,
    Assessment,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorksheetRequest {
    pub level_id: String,
    pub seed: Option<u64>,
    pub question_count: usize,
    pub mode: PracticeMode,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WrittenLevel {
    pub id: String,
    pub title: String,
    pub operation: String,
    pub instructions: String,
    pub prerequisite: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Worksheet {
    pub request: WorksheetRequest,
    pub level: WrittenLevel,
    pub problems: Vec<WrittenProblem>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WrittenProblem {
    pub id: String,
    pub prompt: String,
    pub columns: usize,
    pub rows: Vec<WrittenRow>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WrittenRow {
    pub label: String,
    pub kind: String,
    pub cells: Vec<WrittenCell>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WrittenCell {
    pub id: Option<String>,
    pub text: String,
    pub max_digits: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CellResponse {
    pub cell_id: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CheckRequest {
    pub worksheet: WorksheetRequest,
    pub responses: Vec<CellResponse>,
    pub finish: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CheckResult {
    /// Required working cells answered correctly; optional blank/zero places never earn marks.
    pub correct_count: usize,
    /// Required cells checked, plus any incorrect entries in otherwise optional places.
    pub total_count: usize,
    pub complete: bool,
    pub feedback: Vec<CellFeedback>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CellFeedback {
    pub cell_id: String,
    pub correct: bool,
    pub expected: Option<String>,
    pub explanation: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Operation {
    Addition,
    Subtraction,
    Multiplication,
    Division,
}

#[derive(Clone, Copy)]
enum Cases {
    WithoutExchange,
    WithExchange,
    Mixed,
    AcrossZeros,
    Exact,
    Remainder,
}

#[derive(Clone, Copy)]
struct LevelSpec {
    id: &'static str,
    title: &'static str,
    operation: Operation,
    top_digits: u32,
    bottom_digits: u32,
    cases: Cases,
}

const LEVELS: &[LevelSpec] = &[
    LevelSpec {
        id: "addition_2_by_1",
        title: "Addition: two digits + one digit",
        operation: Operation::Addition,
        top_digits: 2,
        bottom_digits: 1,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "addition_2_no_carry",
        title: "Addition: two digits, no carrying",
        operation: Operation::Addition,
        top_digits: 2,
        bottom_digits: 2,
        cases: Cases::WithoutExchange,
    },
    LevelSpec {
        id: "addition_2_carry",
        title: "Addition: two digits with carrying",
        operation: Operation::Addition,
        top_digits: 2,
        bottom_digits: 2,
        cases: Cases::WithExchange,
    },
    LevelSpec {
        id: "addition_3_by_2",
        title: "Addition: three digits + two digits",
        operation: Operation::Addition,
        top_digits: 3,
        bottom_digits: 2,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "addition_3",
        title: "Addition: three digits",
        operation: Operation::Addition,
        top_digits: 3,
        bottom_digits: 3,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "addition_4",
        title: "Addition: four digits",
        operation: Operation::Addition,
        top_digits: 4,
        bottom_digits: 4,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "subtraction_2_by_1",
        title: "Subtraction: two digits − one digit",
        operation: Operation::Subtraction,
        top_digits: 2,
        bottom_digits: 1,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "subtraction_2_no_exchange",
        title: "Subtraction: two digits, no exchanging",
        operation: Operation::Subtraction,
        top_digits: 2,
        bottom_digits: 2,
        cases: Cases::WithoutExchange,
    },
    LevelSpec {
        id: "subtraction_2_exchange",
        title: "Subtraction: two digits with exchanging",
        operation: Operation::Subtraction,
        top_digits: 2,
        bottom_digits: 2,
        cases: Cases::WithExchange,
    },
    LevelSpec {
        id: "subtraction_3_by_2",
        title: "Subtraction: three digits − two digits",
        operation: Operation::Subtraction,
        top_digits: 3,
        bottom_digits: 2,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "subtraction_3",
        title: "Subtraction: three digits",
        operation: Operation::Subtraction,
        top_digits: 3,
        bottom_digits: 3,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "subtraction_across_zeros",
        title: "Subtraction: exchange across zeros",
        operation: Operation::Subtraction,
        top_digits: 4,
        bottom_digits: 3,
        cases: Cases::AcrossZeros,
    },
    LevelSpec {
        id: "multiplication_2_by_1",
        title: "Short multiplication: two digits × one digit",
        operation: Operation::Multiplication,
        top_digits: 2,
        bottom_digits: 1,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "multiplication_3_by_1",
        title: "Short multiplication: three digits × one digit",
        operation: Operation::Multiplication,
        top_digits: 3,
        bottom_digits: 1,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "multiplication_2_by_2",
        title: "Long multiplication: two digits × two digits",
        operation: Operation::Multiplication,
        top_digits: 2,
        bottom_digits: 2,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "multiplication_3_by_2",
        title: "Long multiplication: three digits × two digits",
        operation: Operation::Multiplication,
        top_digits: 3,
        bottom_digits: 2,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "multiplication_4_by_2",
        title: "Long multiplication: four digits × two digits",
        operation: Operation::Multiplication,
        top_digits: 4,
        bottom_digits: 2,
        cases: Cases::Mixed,
    },
    LevelSpec {
        id: "division_2_exact",
        title: "Short division: two digits, exact answers",
        operation: Operation::Division,
        top_digits: 2,
        bottom_digits: 1,
        cases: Cases::Exact,
    },
    LevelSpec {
        id: "division_3_exact",
        title: "Short division: three digits, exact answers",
        operation: Operation::Division,
        top_digits: 3,
        bottom_digits: 1,
        cases: Cases::Exact,
    },
    LevelSpec {
        id: "division_3_remainders",
        title: "Short division: three digits with remainders",
        operation: Operation::Division,
        top_digits: 3,
        bottom_digits: 1,
        cases: Cases::Remainder,
    },
    LevelSpec {
        id: "division_3_by_2_exact",
        title: "Long division: three digits ÷ two digits, exact",
        operation: Operation::Division,
        top_digits: 3,
        bottom_digits: 2,
        cases: Cases::Exact,
    },
    LevelSpec {
        id: "division_4_by_2_exact",
        title: "Long division: four digits ÷ two digits, exact",
        operation: Operation::Division,
        top_digits: 4,
        bottom_digits: 2,
        cases: Cases::Exact,
    },
    LevelSpec {
        id: "division_4_by_2",
        title: "Long division: four digits ÷ two digits",
        operation: Operation::Division,
        top_digits: 4,
        bottom_digits: 2,
        cases: Cases::Remainder,
    },
];

impl LevelSpec {
    fn public(self) -> WrittenLevel {
        let (operation, instructions, prerequisite) = match self.operation {
            Operation::Addition => (
                "addition",
                "Align the place values. Work from ones to the left. Exchange ten units of a place for one unit of the next place. Write the carry above that next column. Leave unused leading places and no-carry boxes blank.",
                "Read tens and ones and recall addition facts to 20. Start without carrying, then add carrying before increasing the digits.",
            ),
            Operation::Subtraction => (
                "subtraction",
                "Align the place values and work from ones to the left. When needed, exchange one unit from the next place for ten. Write changed top digits in the After exchange row; leave unchanged places blank.",
                "Understand place value and subtraction facts. Explain that one ten is ten ones. Practise one exchange before exchanging across zeros.",
            ),
            Operation::Multiplication => (
                "multiplication",
                "Work from ones to the left. Write the carry and each product digit. For a tens multiplier, include the zero in the ones place. Add partial products to finish. Leave unused leading places and no-carry boxes blank.",
                "Recall the needed multiplication facts and add in columns. Become accurate with a one-digit multiplier before using two digits.",
            ),
            Operation::Division => (
                "division",
                "Work from left to right. Divide the current amount, write the quotient digit, and carry the remainder into the next place. In long division, show subtract, remainder, and bring-down rows. The final remainder box holds the whole remainder (up to two digits). Check: divisor × quotient + remainder = dividend.",
                "Recall multiplication and division facts and understand place value. Practise exact short division before remainders and a two-digit divisor.",
            ),
        };
        WrittenLevel {
            id: self.id.into(),
            title: self.title.into(),
            operation: operation.into(),
            instructions: instructions.into(),
            prerequisite: prerequisite.into(),
        }
    }
}

pub fn levels() -> Vec<WrittenLevel> {
    LEVELS.iter().map(|level| level.public()).collect()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
struct Answer {
    expected: String,
    explanation: String,
    allow_blank: bool,
    max_digits: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StoredWorksheet {
    pub worksheet: Worksheet,
    answers: BTreeMap<String, Answer>,
}

/// Generate a blank grid. Neither answers nor solution cues are sent to the learner.
pub fn generate(request: WorksheetRequest) -> Result<Worksheet> {
    Ok(build(request)?.worksheet)
}

/// Generate the same grid with working filled in for an adult answer sheet.
pub fn generate_solved(request: WorksheetRequest) -> Result<Worksheet> {
    let mut plan = build(request)?;
    for problem in &mut plan.worksheet.problems {
        for row in &mut problem.rows {
            for cell in &mut row.cells {
                if let Some(id) = &cell.id {
                    cell.text = plan.answers[id].expected.clone();
                }
            }
        }
    }
    Ok(plan.worksheet)
}

pub fn generate_stored(request: WorksheetRequest) -> Result<StoredWorksheet> {
    build(request)
}

pub fn check(request: CheckRequest) -> Result<CheckResult> {
    ensure!(
        request.worksheet.seed.is_some(),
        "checking requires the worksheet's generated seed"
    );
    let plan = build(request.worksheet)?;
    check_stored(&plan, &request.responses, request.finish)
}

/// Grade the immutable snapshot. Never regenerate a persisted run from its seed.
pub fn check_stored(plan: &StoredWorksheet, responses: &[CellResponse], finish: bool) -> Result<CheckResult> {
    ensure!(
        finish || plan.worksheet.request.mode == PracticeMode::Assisted,
        "assessment feedback is available only after submission"
    );
    ensure!(responses.len() <= plan.answers.len(), "too many cell responses");
    let mut submitted = BTreeMap::new();
    for response in responses {
        let answer = plan
            .answers
            .get(&response.cell_id)
            .ok_or_else(|| anyhow!("unknown cell_id '{}'", response.cell_id))?;
        ensure!(
            !submitted.contains_key(&response.cell_id),
            "duplicate cell_id '{}'",
            response.cell_id
        );
        let value = response.value.trim().to_string();
        ensure!(
            value.len() <= answer.max_digits && value.bytes().all(|byte| byte.is_ascii_digit()),
            "cell '{}' must contain at most {} digits",
            response.cell_id,
            answer.max_digits
        );
        submitted.insert(response.cell_id.clone(), value);
    }
    let mut feedback = Vec::new();
    let mut correct_count = 0;
    let mut total_count = 0;
    for (cell_id, answer) in &plan.answers {
        let value = submitted.get(cell_id);
        if !finish && value.is_none() {
            continue;
        }
        let value = value.map(String::as_str).unwrap_or("");
        let correct = if answer.allow_blank {
            value.is_empty() || value.bytes().all(|digit| digit == b'0')
        } else {
            value.parse::<u32>().ok() == answer.expected.parse::<u32>().ok() && !value.is_empty()
        };
        // Empty optional places do not earn marks. A wrong entry there still counts as an error.
        if !answer.allow_blank || !correct {
            total_count += 1;
            if correct {
                correct_count += 1;
            }
        }
        feedback.push(CellFeedback {
            cell_id: cell_id.clone(),
            correct,
            expected: (!correct || finish).then(|| answer.expected.clone()),
            explanation: if correct && !finish {
                "Correct.".into()
            } else {
                answer.explanation.clone()
            },
        });
    }
    Ok(CheckResult {
        correct_count,
        total_count,
        complete: finish,
        feedback,
    })
}

// SplitMix64 keeps worksheets stable without tying the contract to a random-library release.
struct Generator(u64);
impl Generator {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut value = self.0;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
        value ^ (value >> 31)
    }
    fn between(&mut self, min: u32, max: u32) -> u32 {
        min + (self.next() % u64::from(max - min + 1)) as u32
    }
    fn number(&mut self, digits: u32) -> u32 {
        self.between(10_u32.pow(digits - 1), 10_u32.pow(digits) - 1)
    }
}

fn build(mut request: WorksheetRequest) -> Result<StoredWorksheet> {
    ensure!(
        (1..=24).contains(&request.question_count),
        "question_count must be between 1 and 24"
    );
    let spec = LEVELS
        .iter()
        .find(|level| level.id == request.level_id)
        .ok_or_else(|| anyhow!("unknown written-arithmetic level '{}'", request.level_id))?;
    let seed = request
        .seed
        .unwrap_or_else(|| crate::activity_seed() & u64::from(u32::MAX));
    ensure!(
        seed <= u64::from(u32::MAX),
        "seed must be an integer from 0 to 4294967295"
    );
    request.seed = Some(seed);
    let mut random = Generator(seed);
    let mut pairs = BTreeSet::new();
    let mut answers = BTreeMap::new();
    let mut problems = Vec::new();
    for _ in 0..50_000 {
        let (mut a, mut b) = (random.number(spec.top_digits), random.number(spec.bottom_digits));
        if matches!(spec.operation, Operation::Multiplication | Operation::Division) && spec.bottom_digits == 1 {
            b = random.between(2, 9);
        }
        if spec.operation == Operation::Subtraction {
            if matches!(spec.cases, Cases::AcrossZeros) {
                a = random.between(1, 9) * 1000;
            }
            if a < b {
                std::mem::swap(&mut a, &mut b);
            }
        }
        let exchange = has_exchange(spec.operation, a, b);
        let acceptable = match spec.cases {
            Cases::WithoutExchange => !exchange,
            Cases::WithExchange => exchange,
            Cases::Exact => a % b == 0,
            Cases::Remainder => a % b != 0,
            Cases::Mixed | Cases::AcrossZeros => true,
        };
        // Commuted addition or multiplication is the same practice fact.
        let key = if matches!(spec.operation, Operation::Addition | Operation::Multiplication) && a > b {
            (b, a)
        } else {
            (a, b)
        };
        if !acceptable || !pairs.insert(key) {
            continue;
        }
        problems.push(problem(spec.operation, a, b, problems.len() + 1, &mut answers));
        if problems.len() == request.question_count {
            break;
        }
    }
    ensure!(
        problems.len() == request.question_count,
        "could not generate the requested distinct practice set"
    );
    Ok(StoredWorksheet {
        worksheet: Worksheet {
            request,
            level: spec.public(),
            problems,
        },
        answers,
    })
}

fn has_exchange(operation: Operation, mut a: u32, mut b: u32) -> bool {
    while a > 0 || b > 0 {
        if (operation == Operation::Addition && a % 10 + b % 10 >= 10)
            || (operation == Operation::Subtraction && a % 10 < b % 10)
        {
            return true;
        }
        a /= 10;
        b /= 10;
    }
    false
}

fn digits(value: u32) -> usize {
    value.to_string().len()
}
fn digit(value: u32, place: usize) -> u32 {
    value / 10_u32.pow(place as u32) % 10
}
fn place_name(place: usize) -> &'static str {
    match place {
        0 => "ones",
        1 => "tens",
        2 => "hundreds",
        3 => "thousands",
        4 => "ten-thousands",
        _ => "hundred-thousands",
    }
}

struct Builder<'a> {
    problem: WrittenProblem,
    answers: &'a mut BTreeMap<String, Answer>,
}
impl<'a> Builder<'a> {
    fn new(
        operation: Operation,
        a: u32,
        b: u32,
        index: usize,
        columns: usize,
        answers: &'a mut BTreeMap<String, Answer>,
    ) -> Self {
        let sign = match operation {
            Operation::Addition => "+",
            Operation::Subtraction => "−",
            Operation::Multiplication => "×",
            Operation::Division => "÷",
        };
        Self {
            problem: WrittenProblem {
                id: format!("q{index}"),
                prompt: format!("{a} {sign} {b}"),
                columns,
                rows: Vec::new(),
            },
            answers,
        }
    }
    fn blank_row(&self, label: &str, kind: &str) -> WrittenRow {
        WrittenRow {
            label: label.into(),
            kind: kind.into(),
            cells: vec![
                WrittenCell {
                    id: None,
                    text: String::new(),
                    max_digits: 1
                };
                self.problem.columns
            ],
        }
    }
    fn fixed_number(&mut self, label: &str, number: u32) {
        let mut row = self.blank_row(label, "operand");
        for (offset, byte) in number.to_string().bytes().rev().enumerate() {
            row.cells[self.problem.columns - offset - 1].text = char::from(byte).to_string();
        }
        self.problem.rows.push(row);
    }
    fn input(
        &mut self,
        row: &mut WrittenRow,
        col: usize,
        expected: String,
        allow_blank: bool,
        explanation: String,
        max_digits: usize,
    ) {
        let id = format!("{}.r{}.c{}", self.problem.id, self.problem.rows.len(), col);
        row.cells[col] = WrittenCell {
            id: Some(id.clone()),
            text: String::new(),
            max_digits,
        };
        self.answers.insert(
            id,
            Answer {
                expected,
                explanation,
                allow_blank,
                max_digits,
            },
        );
    }
    fn number_row(&mut self, label: &str, kind: &str, number: u32, end: usize, explanation: &str) {
        let mut row = self.blank_row(label, kind);
        let width = digits(number);
        for col in 0..=end {
            let place = end - col;
            let leading = place >= width;
            let expected = if leading {
                String::new()
            } else {
                digit(number, place).to_string()
            };
            let cue = if leading {
                format!("{explanation} Leave this unused leading place blank (or write 0).")
            } else {
                format!(
                    "{explanation} Write {} in the {} place of this row.",
                    digit(number, place),
                    place_name(place)
                )
            };
            self.input(&mut row, col, expected, leading, cue, 1);
        }
        self.problem.rows.push(row);
    }
}

fn problem(
    operation: Operation,
    a: u32,
    b: u32,
    index: usize,
    answers: &mut BTreeMap<String, Answer>,
) -> WrittenProblem {
    match operation {
        Operation::Addition => addition(a, b, index, answers),
        Operation::Subtraction => subtraction(a, b, index, answers),
        Operation::Multiplication => multiplication(a, b, index, answers),
        Operation::Division => division(a, b, index, answers),
    }
}

fn addition(a: u32, b: u32, index: usize, answers: &mut BTreeMap<String, Answer>) -> WrittenProblem {
    let n = digits(a).max(digits(b));
    let mut grid = Builder::new(Operation::Addition, a, b, index, n + 1, answers);
    add_carry_row(&mut grid, a, b, n, "Carry");
    grid.fixed_number("", a);
    grid.fixed_number("+", b);
    let mut row = grid.blank_row("Answer", "answer");
    let mut carry = 0;
    for place in 0..=n {
        let total = digit(a, place) + digit(b, place) + carry;
        let leading = place == n && total == 0;
        let cue = format!(
            "{} column: {} + {} + {} carried = {}. Write {} and carry {} into the next place.",
            place_name(place),
            digit(a, place),
            digit(b, place),
            carry,
            total,
            total % 10,
            total / 10
        );
        grid.input(
            &mut row,
            n - place,
            if leading {
                String::new()
            } else {
                (total % 10).to_string()
            },
            leading,
            cue,
            1,
        );
        carry = total / 10;
    }
    grid.problem.rows.push(row);
    grid.problem
}

fn add_carry_row(grid: &mut Builder<'_>, a: u32, b: u32, n: usize, label: &str) {
    let mut row = grid.blank_row(label, "annotation");
    let mut carry = 0;
    for place in 0..n {
        let total = digit(a, place) + digit(b, place) + carry;
        let next = total / 10;
        let cue = format!(
            "{} + {} + {} carried = {} in the {} column. Carry {} into the {} column; write {} in the {} column.",
            digit(a, place),
            digit(b, place),
            carry,
            total,
            place_name(place),
            next,
            place_name(place + 1),
            total % 10,
            place_name(place)
        );
        grid.input(
            &mut row,
            grid.problem.columns - place - 2,
            if next == 0 { String::new() } else { next.to_string() },
            next == 0,
            cue,
            1,
        );
        carry = next;
    }
    grid.problem.rows.push(row);
}

fn subtraction(a: u32, b: u32, index: usize, answers: &mut BTreeMap<String, Answer>) -> WrittenProblem {
    let n = digits(a);
    let mut grid = Builder::new(Operation::Subtraction, a, b, index, n, answers);
    let mut top = (0..n).map(|place| digit(a, place)).collect::<Vec<_>>();
    for place in 0..n {
        if top[place] < digit(b, place) {
            let mut source = place + 1;
            while top[source] == 0 {
                source += 1;
            }
            top[source] -= 1;
            for value in &mut top[place + 1..source] {
                *value = 9;
            }
            top[place] += 10;
        }
    }
    let mut exchange = grid.blank_row("After exchange", "annotation");
    for (place, &value) in top.iter().enumerate() {
        let changed = value != digit(a, place);
        let cue = if changed {
            format!(
                "Rewrite the {} digit as {} after exchanging. One unit of a place is ten of the next smaller place; when an exchange passes through a zero, nine remain there.",
                place_name(place),
                value
            )
        } else {
            format!(
                "The {} digit did not change. Leave its exchange box blank.",
                place_name(place)
            )
        };
        grid.input(
            &mut exchange,
            n - place - 1,
            if changed { value.to_string() } else { String::new() },
            !changed,
            cue,
            2,
        );
    }
    grid.problem.rows.push(exchange);
    grid.fixed_number("", a);
    grid.fixed_number("−", b);
    let mut row = grid.blank_row("Answer", "answer");
    let result_width = digits(a - b);
    for (place, &value) in top.iter().enumerate() {
        let answer = value - digit(b, place);
        let leading = place >= result_width;
        let cue = format!(
            "{} column after exchange: {} − {} = {}. Subtract the bottom digit from the rewritten top digit.",
            place_name(place),
            value,
            digit(b, place),
            answer
        );
        grid.input(
            &mut row,
            n - place - 1,
            if leading { String::new() } else { answer.to_string() },
            leading,
            cue,
            1,
        );
    }
    grid.problem.rows.push(row);
    grid.problem
}

fn multiplication(a: u32, b: u32, index: usize, answers: &mut BTreeMap<String, Answer>) -> WrittenProblem {
    let n = digits(a);
    let m = digits(b);
    let width = n + m;
    let mut grid = Builder::new(Operation::Multiplication, a, b, index, width, answers);
    if m > 1 {
        grid.fixed_number("", a);
        grid.fixed_number("×", b);
    }
    for multiplier_place in 0..m {
        let multiplier = digit(b, multiplier_place);
        let mut carries = grid.blank_row(&format!("Carry ×{multiplier}"), "annotation");
        let mut carry = 0;
        for place in 0..n {
            let total = digit(a, place) * multiplier + carry;
            let next = total / 10;
            let cue = format!(
                "{} × {} + {} carried = {}. Write {} in this partial product and carry {} to the next place.",
                digit(a, place),
                multiplier,
                carry,
                total,
                total % 10,
                next
            );
            grid.input(
                &mut carries,
                width - place - multiplier_place - 2,
                if next == 0 { String::new() } else { next.to_string() },
                next == 0,
                cue,
                1,
            );
            carry = next;
        }
        grid.problem.rows.push(carries);
        if m == 1 {
            grid.fixed_number("", a);
            grid.fixed_number("×", b);
        }
        let partial = a * multiplier * 10_u32.pow(multiplier_place as u32);
        let label = if m == 1 {
            "Answer".into()
        } else {
            format!("×{multiplier} {}", place_name(multiplier_place))
        };
        let explanation = if multiplier_place == 0 {
            format!("Multiply {a} by {multiplier} from right to left: {partial}.")
        } else {
            format!(
                "This multiplier is {} {}, worth {}. {a} × {} = {partial}. Include the ones-place zero because this row multiplies by tens.",
                multiplier,
                place_name(multiplier_place),
                multiplier * 10_u32.pow(multiplier_place as u32),
                multiplier * 10_u32.pow(multiplier_place as u32)
            )
        };
        let mut row = grid.blank_row(&label, if m == 1 { "answer" } else { "working" });
        let mut incoming_carry = 0;
        for place in 0..width {
            let leading = place >= digits(partial);
            let expected = if leading {
                String::new()
            } else {
                digit(partial, place).to_string()
            };
            let cue = if place < multiplier_place {
                "Write 0 in the ones place: multiplying by tens shifts every product digit one place to the left."
                    .into()
            } else if place < n + multiplier_place {
                let source_place = place - multiplier_place;
                let total = digit(a, source_place) * multiplier + incoming_carry;
                let cue = format!(
                    "{} × {} + {} carried = {}. Write {} and carry {} into the next place of this partial product.",
                    digit(a, source_place),
                    multiplier,
                    incoming_carry,
                    total,
                    total % 10,
                    total / 10
                );
                incoming_carry = total / 10;
                cue
            } else if incoming_carry != 0 {
                let cue = format!(
                    "Write the final carried {} in this place. {explanation}",
                    incoming_carry
                );
                incoming_carry = 0;
                cue
            } else {
                format!("Leave this unused leading place blank (or write 0). {explanation}")
            };
            grid.input(&mut row, width - place - 1, expected, leading, cue, 1);
        }
        grid.problem.rows.push(row);
    }
    if m > 1 {
        let first = a * (b % 10);
        let second = a * (b / 10) * 10;
        add_carry_row(&mut grid, first, second, width - 1, "Addition carry");
        grid.number_row(
            "Answer",
            "answer",
            a * b,
            width - 1,
            &format!("Add the aligned partial products: {first} + {second} = {}.", a * b),
        );
    }
    grid.problem
}

fn division(a: u32, b: u32, index: usize, answers: &mut BTreeMap<String, Answer>) -> WrittenProblem {
    let n = digits(a);
    let mut grid = Builder::new(Operation::Division, a, b, index, n, answers);
    let mut quotient = grid.blank_row("Quotient", "quotient");
    let mut remainder = 0;
    let mut started = false;
    let mut stages = Vec::new();
    for col in 0..n {
        let current = remainder * 10 + digit(a, n - col - 1);
        let q = current / b;
        let next_remainder = current % b;
        let leading = !started && q == 0;
        let cue = format!(
            "At this place, divide {current} by {b}: {q}, remainder {next_remainder}, because {b} × {q} = {}. Once the quotient has started, write every quotient digit, including zero at the end.",
            b * q
        );
        grid.input(
            &mut quotient,
            col,
            if leading { String::new() } else { q.to_string() },
            leading,
            cue,
            1,
        );
        if q != 0 {
            started = true;
        }
        stages.push((col, current, q, next_remainder, started));
        remainder = next_remainder;
    }
    grid.problem.rows.push(quotient);
    if b < 10 {
        let mut carry = grid.blank_row("Carry remainder", "annotation");
        for col in 1..n {
            let previous = stages[col - 1].3;
            let cue = format!(
                "The preceding division leaves remainder {previous}. Carry it into this place: {previous} × 10 + {} = {}.",
                digit(a, n - col - 1),
                stages[col].1
            );
            grid.input(
                &mut carry,
                col,
                if previous == 0 {
                    String::new()
                } else {
                    previous.to_string()
                },
                previous == 0,
                cue,
                1,
            );
        }
        grid.problem.rows.push(carry);
    }
    grid.fixed_number(&format!("{b} ⟌"), a);
    grid.problem.rows.last_mut().expect("dividend row").kind = "dividend".into();
    if b >= 10 {
        let mut first = true;
        for (col, current, q, rest, active) in stages {
            if !active {
                continue;
            }
            if !first {
                grid.number_row(
                    "Bring down",
                    "working",
                    current,
                    col,
                    &format!("Bring the next dividend digit beside the preceding remainder to make {current}."),
                );
            }
            let product = b * q;
            grid.number_row(
                "Subtract −",
                "working",
                product,
                col,
                &format!("Multiply this quotient digit by the divisor: {q} × {b} = {product}."),
            );
            grid.number_row(
                "Remainder",
                "working",
                rest,
                col,
                &format!("Subtract {current} − {product} = {rest}. The remainder must be less than {b}."),
            );
            first = false;
        }
    }
    let mut last = grid.blank_row("Remainder (whole number)", "answer");
    grid.input(
        &mut last,
        n - 1,
        remainder.to_string(),
        false,
        format!(
            "The final remainder is {remainder}, less than {b}. Check: {b} × {} + {remainder} = {a}.",
            a / b
        ),
        digits(b),
    );
    grid.problem.rows.push(last);
    grid.problem
}

pub const ENGINE_ID: &str = "written_arithmetic.v1";

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RuntimeParameters {
    question_count: usize,
}

pub fn validate_runtime(runtime: &catalog::MaterialRuntime) -> Result<()> {
    ensure!(
        runtime.engine_id == ENGINE_ID && runtime.spec_version == 1,
        "unsupported written arithmetic runtime"
    );
    ensure!(
        LEVELS.iter().any(|level| level.id == runtime.template_id),
        "unknown written arithmetic level"
    );
    let parameters: RuntimeParameters = serde_json::from_value(runtime.parameters.clone())?;
    ensure!(
        (1..=24).contains(&parameters.question_count),
        "question_count must be between 1 and 24"
    );
    let target = runtime
        .scoring
        .as_ref()
        .and_then(|scoring| scoring.target_accuracy)
        .ok_or_else(|| anyhow!("target_accuracy is required"))?;
    ensure!(
        target > 0.0 && target <= 1.0,
        "target_accuracy must be greater than 0 and at most 1"
    );
    ensure!(
        runtime.readiness.is_none() && runtime.gate.is_none(),
        "written worksheets record practice evidence; readiness and mastery gates are not supported yet"
    );
    Ok(())
}

pub fn generate_activity(
    runtime: &catalog::MaterialRuntime,
    context: &crate::GenerationContext,
) -> Result<crate::GeneratedActivity> {
    validate_runtime(runtime)?;
    let parameters: RuntimeParameters = serde_json::from_value(runtime.parameters.clone())?;
    let request = WorksheetRequest {
        level_id: runtime.template_id.clone(),
        seed: Some(context.seed & u64::from(u32::MAX)),
        question_count: parameters.question_count,
        mode: if context.run_mode == crate::RunMode::Check {
            PracticeMode::Assessment
        } else {
            PracticeMode::Assisted
        },
    };
    let mut stored = build(request)?;
    let spec = LEVELS
        .iter()
        .find(|level| level.id == runtime.template_id)
        .expect("validated level");
    // Retry the same semantic problems, using a fresh immutable instance. Review keeps a mixed component.
    let focus = if matches!(context.run_mode, crate::RunMode::Retry | crate::RunMode::Review)
        && !context.focus_fact_keys.is_empty()
    {
        &context.focus_fact_keys
    } else {
        &context.weak_fact_keys
    };
    if !focus.is_empty() && context.run_mode != crate::RunMode::Check {
        let limit = if context.run_mode == crate::RunMode::Retry {
            parameters.question_count
        } else {
            parameters.question_count.saturating_sub(1).min(3)
        };
        let mut selected = Vec::new();
        let mut seen = BTreeSet::new();
        for key in focus {
            if let Some((a, b)) = parse_fact_key(key, spec) {
                if seen.insert((a, b)) {
                    selected.push((a, b));
                }
                if selected.len() == limit {
                    break;
                }
            }
        }
        if context.run_mode != crate::RunMode::Retry || selected.is_empty() {
            for problem in &stored.worksheet.problems {
                let (a, b) = operands(problem);
                if selected.len() < parameters.question_count && seen.insert((a, b)) {
                    selected.push((a, b));
                }
            }
        }
        stored.answers.clear();
        stored.worksheet.problems = selected
            .into_iter()
            .enumerate()
            .map(|(index, (a, b))| problem(spec.operation, a, b, index + 1, &mut stored.answers))
            .collect();
        stored.worksheet.request.question_count = stored.worksheet.problems.len();
    }
    let family = format!("written-level:{}", spec.id);
    let items = stored
        .worksheet
        .problems
        .iter()
        .map(|problem| {
            let (a, b) = operands(problem);
            let expected = match spec.operation {
                Operation::Addition => a + b,
                Operation::Subtraction => a - b,
                Operation::Multiplication => a * b,
                Operation::Division => a / b,
            };
            crate::GeneratedActivityItem {
                item_id: problem.id.clone(),
                fact_key: fact_key(spec, a, b),
                family_keys: vec![family.clone()],
                coverage_keys: vec![family.clone()],
                difficulty_band: crate::DifficultyBand::Core,
                content: problem.prompt.clone(),
                response_kind: "written_grid".into(),
                expected_response: expected as i32,
                correction_cue: stored.worksheet.level.instructions.clone(),
            }
        })
        .collect::<Vec<_>>();
    Ok(crate::GeneratedActivity {
        generation_context: context.clone(),
        runtime_id: crate::build_runtime_id(ENGINE_ID, spec.id),
        engine_id: ENGINE_ID.into(),
        template_id: spec.id.into(),
        instructions: stored.worksheet.level.instructions.clone(),
        coverage: crate::ActivityCoverage {
            required_family_keys: vec![family.clone()],
            covered_family_keys: vec![family],
            required_difficulty_bands: vec![crate::DifficultyBand::Core],
            difficulty_counts: vec![crate::DifficultyCoverage {
                difficulty_band: crate::DifficultyBand::Core,
                item_count: items.len(),
            }],
            foundation_item_cap: 0,
            adaptive_item_cap: parameters.question_count,
            adaptive_item_count: 0,
            requirements_met: true,
            // A selected level is an assessment of that exercise, not proof of an unrestricted written-method skill.
            representative: false,
        },
        items,
        target_accuracy: runtime
            .scoring
            .as_ref()
            .and_then(|scoring| scoring.target_accuracy)
            .expect("validated target"),
        max_duration_seconds: runtime
            .scoring
            .as_ref()
            .and_then(|scoring| scoring.max_duration_seconds),
        written_plan: Some(stored),
        package_descriptor: None,
    })
}

fn operands(problem: &WrittenProblem) -> (u32, u32) {
    let parts = problem.prompt.split_whitespace().collect::<Vec<_>>();
    (
        parts[0].parse().expect("generated operand"),
        parts[2].parse().expect("generated operand"),
    )
}
fn fact_key(spec: &LevelSpec, mut a: u32, mut b: u32) -> String {
    if matches!(spec.operation, Operation::Addition | Operation::Multiplication)
        && a < b
        && spec.top_digits == spec.bottom_digits
    {
        std::mem::swap(&mut a, &mut b);
    }
    format!("written:{}:{a}:{b}", spec.id)
}
fn parse_fact_key(key: &str, spec: &LevelSpec) -> Option<(u32, u32)> {
    let parts = key.split(':').collect::<Vec<_>>();
    if parts.len() != 4 || parts[0] != "written" || parts[1] != spec.id {
        return None;
    }
    let (a, b) = (parts[2].parse::<u32>().ok()?, parts[3].parse::<u32>().ok()?);
    if digits(a) != spec.top_digits as usize
        || digits(b) != spec.bottom_digits as usize
        || b == 0
        || (spec.operation == Operation::Subtraction && a < b)
    {
        return None;
    }
    Some((a, b))
}

pub fn score_activity(
    generated: &crate::GeneratedActivity,
    responses: &[crate::ActivityResponseInput],
) -> Result<crate::ScoredActivity> {
    let plan = generated
        .written_plan
        .as_ref()
        .ok_or_else(|| anyhow!("written activity has no stored grading plan"))?;
    let cells = responses
        .iter()
        .map(|response| CellResponse {
            cell_id: response.item_id.clone(),
            value: response.value.clone(),
        })
        .collect::<Vec<_>>();
    let result = check_stored(plan, &cells, true)?;
    let mut fact_results = Vec::new();
    let mut corrections = Vec::new();
    let mut attempted_count = 0;
    let mut correct_count = 0;
    for item in &generated.items {
        let prefix = format!("{}.", item.item_id);
        let attempted = cells
            .iter()
            .any(|cell| cell.cell_id.starts_with(&prefix) && !cell.value.trim().is_empty());
        let incorrect = result
            .feedback
            .iter()
            .find(|cell| cell.cell_id.starts_with(&prefix) && !cell.correct);
        let correct = incorrect.is_none();
        attempted_count += usize::from(attempted);
        correct_count += usize::from(correct);
        fact_results.push(crate::FactResult {
            fact_key: item.fact_key.clone(),
            family_keys: item.family_keys.clone(),
            difficulty_band: item.difficulty_band,
            attempted_count: usize::from(attempted),
            correct_count: usize::from(correct),
        });
        if let Some(error) = incorrect {
            corrections.push(crate::ActivityCorrection {
                item_id: item.item_id.clone(),
                content: item.content.clone(),
                submitted_response: "Working needs correction".into(),
                expected_response: item.expected_response,
                fact_key: item.fact_key.clone(),
                family_keys: item.family_keys.clone(),
                correction_cue: error.explanation.clone(),
            });
        }
    }
    let item_count = generated.items.len();
    let accuracy = correct_count as f64 / item_count.max(1) as f64;
    let family = format!("written-level:{}", generated.template_id);
    Ok(crate::ScoredActivity {
        attempted_count,
        correct_count,
        item_count,
        accuracy,
        target_met: accuracy >= generated.target_accuracy,
        completion_reason: "submitted".into(),
        weak_family_keys: if correct_count < item_count {
            vec![family.clone()]
        } else {
            vec![]
        },
        fact_results,
        family_results: vec![crate::FamilyResult {
            family_key: family,
            attempted_count,
            correct_count,
        }],
        corrections,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(id: &str, seed: u64, count: usize) -> WorksheetRequest {
        WorksheetRequest {
            level_id: id.into(),
            seed: Some(seed),
            question_count: count,
            mode: PracticeMode::Assisted,
        }
    }
    fn values(plan: &StoredWorksheet) -> Vec<CellResponse> {
        plan.answers
            .iter()
            .map(|(cell_id, answer)| CellResponse {
                cell_id: cell_id.clone(),
                value: answer.expected.clone(),
            })
            .collect()
    }
    fn worked(operation: Operation, a: u32, b: u32) -> (WrittenProblem, BTreeMap<String, Answer>) {
        let mut answers = BTreeMap::new();
        let problem = problem(operation, a, b, 1, &mut answers);
        (problem, answers)
    }
    fn row_value(problem: &WrittenProblem, answers: &BTreeMap<String, Answer>, label: &str) -> String {
        problem
            .rows
            .iter()
            .find(|row| row.label == label)
            .unwrap()
            .cells
            .iter()
            .map(|cell| {
                cell.id
                    .as_ref()
                    .map(|id| answers[id].expected.as_str())
                    .unwrap_or(&cell.text)
            })
            .collect::<String>()
    }

    fn registered_runtime(level: &str) -> catalog::MaterialRuntime {
        catalog::MaterialRuntime {
            engine_id: ENGINE_ID.into(),
            spec_version: 1,
            template_id: level.into(),
            parameters: serde_json::json!({"question_count": 6}),
            scoring: Some(catalog::MaterialRuntimeScoring {
                target_accuracy: Some(0.9),
                max_duration_seconds: None,
            }),
            readiness: None,
            gate: None,
            presentation: None,
        }
    }

    #[test]
    fn persisted_snapshot_grades_its_cells_without_regenerating() {
        let mut stored = build(request("addition_2_carry", 31, 2)).unwrap();
        let responses = values(&stored);
        stored.worksheet.request.seed = Some(9999);
        let serialized = serde_json::to_value(&stored).unwrap();
        assert!(serialized.get("answers").is_some());
        let restored: StoredWorksheet = serde_json::from_value(serialized).unwrap();
        let scored = check_stored(&restored, &responses, true).unwrap();
        assert_eq!(scored.correct_count, scored.total_count);
        let public = serde_json::to_value(&restored.worksheet).unwrap();
        assert!(public.get("answers").is_none());
    }

    #[test]
    fn assigned_runtime_scores_problems_and_retries_exact_missed_facts() {
        let runtime = registered_runtime("division_3_remainders");
        let generated = generate_activity(&runtime, &crate::GenerationContext::practice(52)).unwrap();
        let stored = generated.written_plan.as_ref().unwrap();
        let responses = values(stored)
            .into_iter()
            .map(|cell| crate::ActivityResponseInput {
                item_id: cell.cell_id,
                value: cell.value,
            })
            .collect::<Vec<_>>();
        let score = score_activity(&generated, &responses).unwrap();
        assert_eq!(score.correct_count, 6);
        assert_eq!(score.item_count, 6);
        assert_eq!(score.fact_results.len(), 6);
        assert!(score.target_met);
        let check = generate_activity(&runtime, &crate::GenerationContext::check(52)).unwrap();
        assert!(!check.coverage.representative);
        assert!(check_stored(check.written_plan.as_ref().unwrap(), &[], false).is_err());
        let missed = generated
            .items
            .iter()
            .take(2)
            .map(|item| item.fact_key.clone())
            .collect::<Vec<_>>();
        let retry = generate_activity(
            &runtime,
            &crate::GenerationContext::retry(900).with_focus_facts(missed.clone()),
        )
        .unwrap();
        assert_eq!(
            retry.items.iter().map(|item| &item.fact_key).collect::<BTreeSet<_>>(),
            missed.iter().collect()
        );
        assert_eq!(retry.items.len(), 2);
        let empty = score_activity(&generated, &[]).unwrap();
        assert_eq!(empty.correct_count, 0);
        assert_eq!(empty.attempted_count, 0);
        assert_eq!(empty.corrections.len(), 6);
    }

    #[test]
    fn all_levels_are_reproducible_unique_and_solved_submissions_pass() {
        for level in LEVELS {
            for seed in 0..32 {
                let req = request(level.id, seed, 24);
                let plan = build(req.clone()).unwrap();
                assert_eq!(plan.worksheet, generate(req.clone()).unwrap());
                assert_eq!(
                    plan.worksheet
                        .problems
                        .iter()
                        .map(|p| &p.prompt)
                        .collect::<BTreeSet<_>>()
                        .len(),
                    24
                );
                for problem in &plan.worksheet.problems {
                    assert!(problem.rows.iter().all(|row| row.cells.len() == problem.columns));
                    assert!(
                        problem
                            .rows
                            .iter()
                            .flat_map(|row| &row.cells)
                            .filter(|cell| cell.id.is_some())
                            .all(|cell| cell.text.is_empty())
                    );
                }
                let result = check(CheckRequest {
                    worksheet: req,
                    responses: values(&plan),
                    finish: true,
                })
                .unwrap();
                assert_eq!(result.correct_count, result.total_count, "{} seed {seed}", level.id);
                assert!(result.complete);
            }
        }
    }

    #[test]
    fn carrying_and_exchange_across_zeros_are_explicit() {
        let (sum, sum_answers) = worked(Operation::Addition, 55, 68);
        assert_eq!(row_value(&sum, &sum_answers, "Answer"), "123");
        assert_eq!(row_value(&sum, &sum_answers, "Carry"), "11");
        let (sub, sub_answers) = worked(Operation::Subtraction, 1000, 1);
        assert_eq!(row_value(&sub, &sub_answers, "After exchange"), "09910");
        assert_eq!(row_value(&sub, &sub_answers, "Answer"), "999");
        let (sub, sub_answers) = worked(Operation::Subtraction, 302, 178);
        assert_eq!(row_value(&sub, &sub_answers, "After exchange"), "2912");
        assert_eq!(row_value(&sub, &sub_answers, "Answer"), "124");
    }

    #[test]
    fn long_multiplication_places_partial_products_and_carries() {
        let (problem, answers) = worked(Operation::Multiplication, 305, 24);
        assert_eq!(row_value(&problem, &answers, "×4 ones"), "1220");
        assert_eq!(row_value(&problem, &answers, "×2 tens"), "6100");
        assert_eq!(row_value(&problem, &answers, "Answer"), "7320");
        let (problem, answers) = worked(Operation::Multiplication, 502, 30);
        assert_eq!(row_value(&problem, &answers, "×0 ones"), "0");
        assert_eq!(row_value(&problem, &answers, "×3 tens"), "15060");
        assert_eq!(row_value(&problem, &answers, "Answer"), "15060");
    }

    #[test]
    fn division_preserves_internal_zero_and_remainders() {
        for (a, b) in [(816, 4), (1005, 5), (1000, 12), (4056, 12), (1234, 24), (1001, 99)] {
            let (problem, answers) = worked(Operation::Division, a, b);
            assert_eq!(row_value(&problem, &answers, "Quotient"), (a / b).to_string());
            assert_eq!(
                row_value(&problem, &answers, "Remainder (whole number)"),
                (a % b).to_string()
            );
            assert!(a % b < b);
        }
        let (problem, answers) = worked(Operation::Division, 1000, 12);
        let remainders = problem
            .rows
            .iter()
            .filter(|row| row.label == "Remainder")
            .map(|row| {
                row.cells
                    .iter()
                    .filter_map(|cell| cell.id.as_ref())
                    .map(|id| answers[id].expected.as_str())
                    .collect::<String>()
            })
            .collect::<Vec<_>>();
        assert_eq!(remainders, ["4", "4"]);
    }

    #[test]
    fn generated_cases_match_level_promises_and_arithmetic_invariants() {
        for spec in LEVELS {
            for seed in 0..16 {
                let plan = build(request(spec.id, seed, 24)).unwrap();
                for problem in &plan.worksheet.problems {
                    let parts = problem.prompt.split_whitespace().collect::<Vec<_>>();
                    let a: u32 = parts[0].parse().unwrap();
                    let b: u32 = parts[2].parse().unwrap();
                    assert_eq!(digits(a), spec.top_digits as usize);
                    assert_eq!(digits(b), spec.bottom_digits as usize);
                    match spec.cases {
                        Cases::WithoutExchange => assert!(!has_exchange(spec.operation, a, b)),
                        Cases::WithExchange => assert!(has_exchange(spec.operation, a, b)),
                        Cases::AcrossZeros => assert_eq!(a % 1000, 0),
                        Cases::Exact => assert_eq!(a % b, 0),
                        Cases::Remainder => assert_ne!(a % b, 0),
                        Cases::Mixed => {}
                    }
                    let expected = match spec.operation {
                        Operation::Addition => a + b,
                        Operation::Subtraction => a - b,
                        Operation::Multiplication => a * b,
                        Operation::Division => a / b,
                    };
                    let label = if spec.operation == Operation::Division {
                        "Quotient"
                    } else {
                        "Answer"
                    };
                    assert_eq!(row_value(problem, &plan.answers, label), expected.to_string());
                }
            }
        }
    }

    #[test]
    fn assessment_cannot_request_early_feedback_and_checks_missing_cells() {
        let mut req = request("addition_2_carry", 55, 1);
        req.mode = PracticeMode::Assessment;
        assert!(
            check(CheckRequest {
                worksheet: req.clone(),
                responses: vec![],
                finish: false
            })
            .is_err()
        );
        let result = check(CheckRequest {
            worksheet: req,
            responses: vec![],
            finish: true,
        })
        .unwrap();
        assert!(result.complete);
        assert_eq!(result.correct_count, 0);
        assert!(result.total_count > 0);
        assert!(
            result
                .feedback
                .iter()
                .any(|cell| !cell.correct && !cell.explanation.is_empty())
        );
    }

    #[test]
    fn optional_places_never_award_marks_and_wrong_entries_count_as_errors() {
        for level in LEVELS {
            let req = request(level.id, 47, 1);
            let plan = build(req.clone()).unwrap();
            let empty = check(CheckRequest {
                worksheet: req.clone(),
                responses: vec![],
                finish: true,
            })
            .unwrap();
            assert_eq!(empty.correct_count, 0, "{}", level.id);
            assert_eq!(
                empty.total_count,
                plan.answers.values().filter(|answer| !answer.allow_blank).count()
            );
            if let Some((cell_id, _)) = plan.answers.iter().find(|(_, answer)| answer.allow_blank) {
                let mut responses = values(&plan);
                responses
                    .iter_mut()
                    .find(|response| response.cell_id == *cell_id)
                    .unwrap()
                    .value = "1".into();
                let result = check(CheckRequest {
                    worksheet: req,
                    responses,
                    finish: true,
                })
                .unwrap();
                assert_eq!(result.total_count, empty.total_count + 1);
                assert_eq!(result.correct_count, empty.total_count);
            }
        }
    }

    #[test]
    fn malformed_requests_and_unknown_or_duplicate_cells_are_rejected() {
        assert!(generate(request("missing", 1, 1)).is_err());
        assert!(generate(request("addition_2_carry", 1, 0)).is_err());
        assert!(generate(request("addition_2_carry", 1, 25)).is_err());
        assert!(generate(request("addition_2_carry", u64::MAX, 1)).is_err());
        let req = request("addition_2_carry", 1, 1);
        let plan = build(req.clone()).unwrap();
        let response = values(&plan)[0].clone();
        assert!(
            check(CheckRequest {
                worksheet: req.clone(),
                responses: vec![response.clone(), response],
                finish: false
            })
            .is_err()
        );
        assert!(
            check(CheckRequest {
                worksheet: req.clone(),
                responses: vec![CellResponse {
                    cell_id: "missing".into(),
                    value: "1".into()
                }],
                finish: false
            })
            .is_err()
        );
        let cell_id = plan.answers.keys().next().unwrap().clone();
        for value in ["-1", "1.0", "x", "111"] {
            assert!(
                check(CheckRequest {
                    worksheet: req.clone(),
                    responses: vec![CellResponse {
                        cell_id: cell_id.clone(),
                        value: value.into()
                    }],
                    finish: false
                })
                .is_err()
            );
        }
    }

    #[test]
    fn blank_optional_annotations_but_not_exchanged_zero_are_accepted() {
        let (problem, answers) = worked(Operation::Subtraction, 100, 1);
        let exchange = &problem.rows[0];
        let id = exchange.cells[0].id.as_ref().unwrap();
        assert_eq!(answers[id].expected, "0");
        assert!(!answers[id].allow_blank);
        let (problem, answers) = worked(Operation::Addition, 12, 13);
        assert!(
            problem.rows[0]
                .cells
                .iter()
                .filter_map(|cell| cell.id.as_ref())
                .all(|id| answers[id].allow_blank)
        );
    }
}
