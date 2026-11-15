//! A print view of the same backend-owned grids used by the interactive practice screen.
use std::fmt::Write;

use learning_activity_runtime::written_arithmetic::{self, Worksheet, WorksheetRequest};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, clap::ValueEnum)]
#[serde(rename_all = "snake_case")]
pub enum PrintLayout {
    #[default]
    Guided,
    Compact,
}

pub fn render_with_layout(
    request: WorksheetRequest,
    include_answers: bool,
    layout: PrintLayout,
) -> anyhow::Result<String> {
    // Normalize the seed once: the key must describe these exact questions.
    let worksheet = written_arithmetic::generate(request)?;
    let mut html = String::from(
        r#"<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cornerstone written arithmetic</title>
<style>
@page { size: A4; margin: 13mm; }
* { box-sizing: border-box; }
body { margin: 0; color: #172033; background: white; font: 11pt system-ui, sans-serif; }
.page { break-after: page; }
.page:last-child { break-after: auto; }
header { border-bottom: 1px solid #667085; padding-bottom: 3mm; margin-bottom: 4mm; }
.eyebrow { font-size: 9pt; letter-spacing: .08em; text-transform: uppercase; }
h1 { font-size: 16pt; line-height: 1.2; margin: 2mm 0; }
p { margin: 2mm 0; }
.details, footer { font-size: 8pt; color: #475467; }
.name { margin-top: 5mm; }
.problems { display: grid; grid-template-columns: repeat(var(--columns), minmax(0,1fr)); gap: 5mm 5mm; }
.problem { break-inside: avoid; min-height: var(--problem-height); }
h2 { font-size: 9pt; margin: 0 0 2mm; }
table { border-collapse: collapse; table-layout: fixed; margin-left: auto; }
th { width: 18mm; font-size: 6.5pt; font-weight: normal; text-align: right; padding-right: 2mm; }
td { width: 6mm; min-width: 6mm; height: 7mm; text-align: center; font: 15pt ui-monospace, monospace; }
td.entry { border: 1px solid #98a2b3; }
.whole-number { width: 8mm; min-width: 8mm; font-size: 11pt; }
tr.annotation td { height: 5mm; font-size: 10pt; }
tr.answer td, tr.dividend td { border-top: 2px solid #172033; }
tr.working td { border-bottom: 1px solid #d0d5dd; }
footer { border-top: 1px solid #d0d5dd; margin-top: 4mm; padding-top: 2mm; }
.compact table { margin: 5mm auto 0; }
.compact th { width: 10mm; white-space: nowrap; font-size: 12pt; }
.compact td { width: 5mm; min-width: 5mm; height: 6mm; }
.compact .rule td { border-top: 1px solid #172033; height: 10mm; }
.answer-list .problem { min-height: 11mm; font-size: 10pt; }
.answer-list h2 { margin-bottom: 1mm; }
@media screen {
 body { background: #e9edf2; padding: 20px; }
 .page { background: white; width: 184mm; min-height: 271mm; padding: 12mm; margin: 0 auto 24px; box-sizing: content-box; }
}
</style></head><body>"#,
    );
    append_pages(&mut html, &worksheet, false, layout);
    if include_answers {
        let solved = written_arithmetic::generate_solved(worksheet.request.clone())?;
        append_pages(&mut html, &solved, true, layout);
    }
    html.push_str("</body></html>");
    Ok(html)
}

fn append_pages(html: &mut String, worksheet: &Worksheet, answers: bool, layout: PrintLayout) {
    // Leave enough handwriting space even for long-division working rows.
    let longest = worksheet
        .problems
        .iter()
        .map(|problem| problem.rows.len())
        .max()
        .unwrap_or(0);
    let (columns, per_page, height) = match layout {
        PrintLayout::Compact if answers => (3, 24, 11),
        PrintLayout::Compact if longest > 10 => (4, 8, 91),
        PrintLayout::Compact if longest > 5 => (4, 12, 59),
        PrintLayout::Compact => (4, 20, 36),
        PrintLayout::Guided if longest > 10 => (2, 4, 96),
        PrintLayout::Guided if longest > 5 => (2, 6, 64),
        PrintLayout::Guided => (3, 12, 44),
    };
    let label = if answers { "Answer key" } else { "Practice worksheet" };
    for (page, problems) in worksheet.problems.chunks(per_page).enumerate() {
        write!(
            html,
            "<section class=\"page\"><header><div class=\"eyebrow\">Cornerstone · {label}</div><h1>{}</h1><p class=\"details\">{}</p><p class=\"details\">Level: {} · Sheet: {} · Page {}</p>",
            escape(&worksheet.level.title),
            escape(if matches!(layout, PrintLayout::Compact) {
                if answers { "Answers match the numbered questions on this sheet." }
                else { "Set out each calculation in columns. Use the space below for carrying, exchanges and working. For division, give the quotient and any remainder." }
            } else { &worksheet.level.instructions }),
            escape(&worksheet.request.level_id),
            worksheet.request.seed.unwrap_or_default(),
            page + 1,
        ).expect("write to String");
        if !answers {
            html.push_str("<p class=\"name\">Name: _____________________ &nbsp; Date: ______________</p>");
        }
        let class = match (layout, answers) {
            (PrintLayout::Compact, true) => "answer-list",
            (PrintLayout::Compact, false) => "compact",
            _ => "guided",
        };
        write!(
            html,
            "</header><main class=\"problems {class}\" style=\"--columns:{columns};--problem-height:{height}mm\">"
        )
        .expect("write to String");
        for (offset, problem) in problems.iter().enumerate() {
            let number = page * per_page + offset + 1;
            if matches!(layout, PrintLayout::Compact) {
                append_compact_problem(html, problem, number, answers);
                continue;
            }
            write!(
                html,
                "<article class=\"problem\"><h2>{}. {}</h2><table aria-label=\"{}\"><tbody>",
                page * per_page + offset + 1,
                escape(&problem.prompt),
                escape(&problem.prompt),
            )
            .expect("write to String");
            for row in &problem.rows {
                write!(
                    html,
                    "<tr class=\"{}\"><th scope=\"row\">{}</th>",
                    escape(&row.kind),
                    escape(&row.label)
                )
                .expect("write to String");
                for cell in &row.cells {
                    let class = if cell.id.is_some() {
                        if cell.max_digits > 1 {
                            "entry whole-number"
                        } else {
                            "entry"
                        }
                    } else {
                        "fixed"
                    };
                    write!(html, "<td class=\"{class}\">{}</td>", escape(&cell.text)).expect("write to String");
                }
                html.push_str("</tr>");
            }
            html.push_str("</tbody></table></article>");
        }
        html.push_str("</main><footer>");
        if matches!(layout, PrintLayout::Compact) {
            html.push_str("Keep answer digits aligned. Show your working, then check with the inverse operation.");
        } else {
            html.push_str("Keep answer digits aligned. Exchange boxes and the final remainder box can hold a whole number. Work carefully, then check with the inverse operation.");
        }
        html.push_str("</footer></section>");
    }
}

fn append_compact_problem(
    html: &mut String,
    problem: &written_arithmetic::WrittenProblem,
    number: usize,
    answers: bool,
) {
    if answers {
        let value = problem
            .rows
            .iter()
            .filter(|row| row.kind == "answer" || row.kind == "quotient")
            .map(|row| row.cells.iter().map(|cell| cell.text.as_str()).collect::<String>())
            .collect::<Vec<_>>()
            .join(" remainder ");
        write!(
            html,
            "<article class=\"problem\"><h2>{number}. {}</h2><div>= {}</div></article>",
            escape(&problem.prompt),
            escape(&value)
        )
        .expect("write to String");
        return;
    }
    write!(
        html,
        "<article class=\"problem\"><h2>{number}.</h2><table aria-label=\"{}\"><tbody>",
        escape(&problem.prompt)
    )
    .expect("write to String");
    for row in problem
        .rows
        .iter()
        .filter(|row| row.kind == "operand" || row.kind == "dividend")
    {
        write!(
            html,
            "<tr class=\"{}\"><th>{}</th>",
            escape(&row.kind),
            escape(&row.label)
        )
        .expect("write to String");
        for cell in &row.cells {
            write!(html, "<td>{}</td>", escape(&cell.text)).expect("write to String");
        }
        html.push_str("</tr>");
    }
    // No pre-drawn working cells: leave the remainder of the card for handwriting.
    html.push_str("<tr class=\"rule\"><th></th>");
    for _ in 0..problem.columns {
        html.push_str("<td></td>");
    }
    html.push_str("</tr></tbody></table></article>");
}

fn escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use learning_activity_runtime::written_arithmetic::PracticeMode;

    fn request() -> WorksheetRequest {
        WorksheetRequest {
            level_id: written_arithmetic::levels()[0].id.clone(),
            seed: Some(55),
            question_count: 6,
            mode: PracticeMode::Assisted,
        }
    }

    #[test]
    fn print_has_blank_grids_and_separate_optional_answer_pages() {
        let blank = render_with_layout(request(), false, PrintLayout::Guided).unwrap();
        assert!(blank.contains("Sheet: 55"));
        assert!(blank.contains("class=\"entry\"></td>"));
        assert!(!blank.contains("Answer key"));
        let keyed = render_with_layout(request(), true, PrintLayout::Guided).unwrap();
        assert_eq!(keyed.matches("Cornerstone · Practice worksheet").count(), 1);
        assert_eq!(keyed.matches("Cornerstone · Answer key").count(), 1);
        let start = keyed.find("Cornerstone · Answer key").unwrap();
        assert!(!keyed[start..].contains("Name: _____________________"));
    }

    #[test]
    fn print_keeps_regenerated_questions_and_answers_matched() {
        let mut unseeded = request();
        unseeded.seed = None;
        let html = render_with_layout(unseeded, true, PrintLayout::Guided).unwrap();
        let first_id = html.split("Sheet: ").nth(1).unwrap().split(" ·").next().unwrap();
        assert_eq!(html.matches(&format!("Sheet: {first_id} ·")).count(), 2);
        assert_eq!(escape("<script>\"&'"), "&lt;script&gt;&quot;&amp;&#39;");
    }

    #[test]
    fn every_compact_level_keeps_numbered_operands_and_arithmetic_answer_keys_matched() {
        for level in written_arithmetic::levels() {
            let request = WorksheetRequest {
                level_id: level.id,
                seed: Some(183),
                question_count: 24,
                mode: PracticeMode::Assisted,
            };
            let worksheet = written_arithmetic::generate(request.clone()).unwrap();
            let html = render_with_layout(request, true, PrintLayout::Compact).unwrap();
            let split = html.find("Cornerstone · Answer key").unwrap();
            let (questions, key) = html.split_at(split);
            assert!(!questions.contains("class=\"entry"));
            for (index, problem) in worksheet.problems.iter().enumerate() {
                let number = index + 1;
                assert_eq!(questions.matches(&format!("<h2>{number}.</h2>")).count(), 1);
                assert_eq!(
                    questions
                        .matches(&format!("aria-label=\"{}\"", escape(&problem.prompt)))
                        .count(),
                    1
                );
                let parts = problem.prompt.split_whitespace().collect::<Vec<_>>();
                let (a, b) = (parts[0].parse::<u32>().unwrap(), parts[2].parse::<u32>().unwrap());
                let expected = match worksheet.level.operation.as_str() {
                    "addition" => (a + b).to_string(),
                    "subtraction" => (a - b).to_string(),
                    "multiplication" => (a * b).to_string(),
                    "division" => format!("{} remainder {}", a / b, a % b),
                    _ => panic!("unknown operation"),
                };
                assert!(
                    key.contains(&format!(
                        "<h2>{number}. {}</h2><div>= {expected}</div>",
                        escape(&problem.prompt)
                    )),
                    "{}: {}",
                    worksheet.level.id,
                    problem.prompt
                );
            }
        }
    }

    #[test]
    fn guided_long_division_keeps_whole_remainders_legible_and_limits_tall_pages() {
        let request = WorksheetRequest {
            level_id: "division_4_by_2".into(),
            seed: Some(55),
            question_count: 24,
            mode: PracticeMode::Assisted,
        };
        let html = render_with_layout(request, true, PrintLayout::Guided).unwrap();
        assert!(html.contains("class=\"entry whole-number\""));
        assert_eq!(html.matches("Cornerstone · Practice worksheet").count(), 6);
        assert_eq!(html.matches("Cornerstone · Answer key").count(), 6);
        assert_eq!(html.matches("Remainder (whole number)").count(), 48);
    }

    #[test]
    fn compact_layout_packs_questions_without_working_boxes_and_has_separate_key() {
        let mut request = request();
        request.question_count = 20;
        let html = render_with_layout(request, true, PrintLayout::Compact).unwrap();
        assert_eq!(html.matches("Cornerstone · Practice worksheet").count(), 1);
        assert_eq!(html.matches("Cornerstone · Answer key").count(), 1);
        assert!(!html.contains("class=\"entry\""));
        assert!(html.contains("problems compact"));
        assert!(html.contains("problems answer-list"));
        assert_eq!(html.matches("<article class=\"problem\">").count(), 40);
    }
}
