//! A print view of the same backend-owned grids used by the interactive practice screen.
use std::fmt::Write;

use learning_activity_runtime::written_arithmetic::{self, Worksheet, WorksheetRequest};

pub fn render(request: WorksheetRequest, include_answers: bool) -> anyhow::Result<String> {
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
header { border-bottom: 1px solid #667085; padding-bottom: 4mm; margin-bottom: 6mm; }
.eyebrow { font-size: 9pt; letter-spacing: .08em; text-transform: uppercase; }
h1 { font-size: 19pt; line-height: 1.2; margin: 2mm 0; }
p { margin: 2mm 0; }
.details, footer { font-size: 8pt; color: #475467; }
.name { margin-top: 5mm; }
.problems { display: grid; grid-template-columns: 1fr 1fr; gap: 8mm 6mm; }
.problem { break-inside: avoid; min-height: 65mm; }
h2 { font-size: 11pt; margin: 0 0 4mm; }
table { border-collapse: collapse; table-layout: fixed; margin-left: auto; }
th { width: 25mm; font-size: 7.5pt; font-weight: normal; text-align: right; padding-right: 2mm; }
td { width: 7mm; min-width: 7mm; height: 8mm; text-align: center; font: 16pt ui-monospace, monospace; }
td.entry { border: 1px solid #98a2b3; }
tr.annotation td { height: 6mm; font-size: 11pt; }
tr.answer td, tr.dividend td { border-top: 2px solid #172033; }
tr.working td { border-bottom: 1px solid #d0d5dd; }
footer { border-top: 1px solid #d0d5dd; margin-top: 6mm; padding-top: 3mm; }
@media screen {
 body { background: #e9edf2; padding: 20px; }
 .page { background: white; width: 184mm; min-height: 271mm; padding: 12mm; margin: 0 auto 24px; box-sizing: content-box; }
}
</style></head><body>"#,
    );
    append_pages(&mut html, &worksheet, false);
    if include_answers {
        let solved = written_arithmetic::generate_solved(worksheet.request.clone())?;
        append_pages(&mut html, &solved, true);
    }
    html.push_str("</body></html>");
    Ok(html)
}

fn append_pages(html: &mut String, worksheet: &Worksheet, answers: bool) {
    // Leave enough handwriting space even for long-division working rows.
    let longest = worksheet
        .problems
        .iter()
        .map(|problem| problem.rows.len())
        .max()
        .unwrap_or(0);
    let per_page = if longest > 10 { 2 } else { 4 };
    let label = if answers { "Answer key" } else { "Practice worksheet" };
    for (page, problems) in worksheet.problems.chunks(per_page).enumerate() {
        write!(
            html,
            "<section class=\"page\"><header><div class=\"eyebrow\">Cornerstone · {label}</div><h1>{}</h1><p>{}</p><p class=\"details\">Level: {} · Sheet: {} · Page {}</p>",
            escape(&worksheet.level.title),
            escape(&worksheet.level.instructions),
            escape(&worksheet.request.level_id),
            worksheet.request.seed.unwrap_or_default(),
            page + 1,
        ).expect("write to String");
        if !answers {
            html.push_str("<p class=\"name\">Name: _____________________ &nbsp; Date: ______________</p>");
        }
        html.push_str("</header><main class=\"problems\">");
        for (offset, problem) in problems.iter().enumerate() {
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
                    let class = if cell.id.is_some() { "entry" } else { "fixed" };
                    write!(html, "<td class=\"{class}\">{}</td>", escape(&cell.text)).expect("write to String");
                }
                html.push_str("</tr>");
            }
            html.push_str("</tbody></table></article>");
        }
        html.push_str("</main><footer>Keep answer digits aligned. Exchange boxes and the final remainder box can hold a whole number. Work carefully, then check with the inverse operation.</footer></section>");
    }
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
        let blank = render(request(), false).unwrap();
        assert!(blank.contains("Sheet: 55"));
        assert!(blank.contains("class=\"entry\"></td>"));
        assert!(!blank.contains("Answer key"));
        let keyed = render(request(), true).unwrap();
        assert_eq!(keyed.matches("Cornerstone · Practice worksheet").count(), 2);
        assert_eq!(keyed.matches("Cornerstone · Answer key").count(), 2);
        let start = keyed.find("Cornerstone · Answer key").unwrap();
        assert!(!keyed[start..].contains("Name: _____________________"));
    }

    #[test]
    fn print_keeps_regenerated_questions_and_answers_matched() {
        let mut unseeded = request();
        unseeded.seed = None;
        let html = render(unseeded, true).unwrap();
        let first_id = html.split("Sheet: ").nth(1).unwrap().split(" ·").next().unwrap();
        assert_eq!(html.matches(&format!("Sheet: {first_id} ·")).count(), 4);
        assert_eq!(escape("<script>\"&'"), "&lt;script&gt;&quot;&amp;&#39;");
    }
}
