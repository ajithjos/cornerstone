# Written arithmetic practice

Written arithmetic is available both as assignable curriculum materials and as a
fresh worksheet generator. Both use the same Rust arithmetic engine and the same
versioned on-screen activity package. Start with the **Arithmetic Written Methods**
lesson notes, demonstrate one example, then select a small practice set.

## Choose how to use it

| Need | Route | What is recorded |
| --- | --- | --- |
| Give one learner a particular arithmetic level | Open **Library**, browse **Arithmetic Written Methods → Extra practice**, choose the level, and assign it to the learner | A scheduled session, a stored activity attempt, and completion evidence |
| Teach an ordered sequence of lessons and practice | Assign a playlist | Its scheduled sessions and their evidence |
| Print fresh practice or try an extra on-screen set | Choose **Create a worksheet** | No learner progress or completion evidence |

A material can be assigned on its own without adding it to a playlist. Written
materials offer **Assisted practice** and **Assessment** assignment modes.
Assisted practice is the default. The assignment owns the selected mode; the
learner cannot switch an assessment into assisted practice while completing it.

In assisted practice, **Check this exercise** checks the entered boxes in one
calculation and explains mistakes. The learner can correct the working before
finishing. In assessment mode, explanations appear only after submission. Both
modes lock the submitted attempt when completion succeeds.

## A short teaching session

1. Check the prerequisite shown for the selected level. Confirm place value and
   the addition or multiplication facts needed for the method.
2. Teach one worked example. Name the value of every carry or exchange.
3. Work one example together, then use assisted practice for a small set.
4. Correct the first mistaken step. After a worked correction, give a fresh
   question so copying is not mistaken for independent success.
5. Use a fresh assessment for independent work. Print a short set for handwriting
   and include two earlier calculations in the next session.

For a child starting around seven, begin with place-value alignment and small
addition/subtraction. A child around nine who can explain exchanges can begin
with a short baseline and move to short multiplication and division when the
relevant table facts are secure. Teach short multiplication before long
multiplication, and one-digit division before a two-digit divisor. Readiness,
not age alone, determines the starting point.

The current levels cover whole numbers up to four digits, multipliers up to two
digits, and divisors up to two digits. They include two-digit with one-digit and
three-digit with two-digit foundations, carrying, exchange across zeros, shifted
partial products, quotient zeros, and remainders. The lesson notes explain how
the methods extend to more columns. Decimal and fraction algorithms come later.

## Create and print fresh worksheets

In **Create a worksheet**, select a skill and level, mode, question count, and
print format. Generate a set, then print it or open it for on-screen practice.
The generator uses a seeded set of distinct calculations within the selected
level. Changing the print format preserves those calculations.

- **Guided — working boxes** shows the carry, exchange, partial-product, or
  division rows. Its answer key contains completed working grids.
- **Compact — more practice** uses a denser paper layout with space for the
  learner to write the method. Its separate answer key lists final answers.

Parents and team managers can include the answer key. The sheet number identifies
the seed; questions and answers are generated together from that same seed.
Repeated sets provide a large supply of practice within the selected number
range. A bounded range is not literally infinite.

Printing also works without a running server, Postgres, or sign-in:

```bash
cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- worksheet-levels
cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- worksheet-print \
  --level addition_2_carry --count 6 --seed 55 --layout guided \
  --answers --output /tmp/arithmetic-guided.html
cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- worksheet-print \
  --level multiplication_2_by_2 --count 12 --layout compact \
  --answers --output /tmp/arithmetic-compact.html
```

Open the HTML file in a browser and print or save as PDF. Omit `--seed` for a
fresh set and omit `--answers` for questions only. The default is six questions;
the engine accepts 1–24. The default layout is `guided`.

## Author an assignable written material

Each level is an ordinary `worksheet` material inside the owning pathway. Its
runtime block selects a Rust level and a presentation package:

```yaml
runtime:
  engine_id: written_arithmetic.v1
  spec_version: 1
  template_id: addition_2_carry
  presentation:
    package_id: written-arithmetic
    version: 1.0.0
  parameters:
    question_count: 6
  scoring:
    target_accuracy: 0.9
```

Keep the material's skill and stage links, prerequisite, and teaching instructions
clear. The lesson note teaches the method; the interactive worksheet supplies
practice. A standalone material remains visible and directly assignable from
the learning library even when no playlist references it. The pathway's **Extra
practice** groups preserve the operation and level progression alongside the
authored playlists and sessions.

The exact grid, grading plan, mode, and package descriptor are stored when an
assigned attempt starts. Reopening an in-progress attempt resumes that plan.
Completion scores the stored plan rather than regenerating from current content.
Unsubmitted entries are not saved: reopening restores the questions, not unfinished
typing.

## Understand the result

Cell feedback counts required working boxes. Unused leading places, unchanged
exchange boxes, and no-carry boxes may remain blank and earn no marks. An
incorrect value entered in one of those optional boxes still needs correction.
An exchange box or final remainder box can hold a whole number such as `13`.

For an assigned attempt, the stored result counts complete calculations: a
calculation is correct only when its required working is correct and it has no
incorrect optional entries. The control plane records compact run, calculation,
and level-family evidence. Assisted checks do not finish the activity, and a
corrected assisted result remains practice evidence.

A selected-level written assessment is not representative evidence of the whole
written-method skill. These attempts do not confirm or overwrite the broader
skill state. The free worksheet generator records no evidence at all. Typed
working stays local to the open activity until checking or submission; individual
keystrokes are not retained.

## Implementation boundary

Rust owns the level catalog, generation, grid geometry, answers, explanations,
assignment modes, scoring, and evidence. The `written-arithmetic` HTML/JS/CSS
package renders the supplied rows and sends entered values through the shared
Flutter host. It does not calculate answers. Packages can be added or replaced
with a new version without compiling the main Flutter application; see
[Activity packages](./activity-packages.md).

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/written-arithmetic/levels` | Read levels and prerequisites |
| POST | `/api/v1/written-arithmetic/generate` | Generate a free worksheet and presentation descriptor |
| POST | `/api/v1/written-arithmetic/check` | Check a free worksheet |
| POST | `/api/v1/written-arithmetic/print` | Render guided or compact A4 questions and optional key |
| POST | `/api/v1/assignments` | Assign a playlist or one material |
| POST | `/api/v1/sessions/{session_id}/materials/{session_material_id}/start` | Start or resume an assigned activity |
| POST | `/api/v1/activity-instances/{activity_instance_id}/check` | Check entered cells in an assisted assigned attempt |
| POST | `/api/v1/activity-instances/{activity_instance_id}/complete` | Score and finish the stored attempt |

All operations in this table require an authenticated session. Assignment and
answer-key permissions are enforced by the control plane.
