# Written arithmetic practice

The **Written arithmetic** screen provides extra practice alongside the existing
**Arithmetic Written Methods** pathway. It uses column addition and subtraction,
short and long multiplication, and short and long division. Start with the
pathway's lesson note, demonstrate one example, then choose a small practice set.

## A short teaching session

1. Check the prerequisite shown for the selected level. Age is entry guidance,
   not a reason to skip place value or multiplication facts.
2. Teach one worked example. Name the value of every carry or exchange.
3. Use **Assisted** mode for a few examples. Enter digits in the paper-style grid
   and check the work. The server explains incorrect entries; correct the same
   example before moving on.
4. Use a fresh **Assessment** sheet for independent work. Corrections appear only
   after submission. This is an informal self-check, not a secure examination.
5. Print a short set for handwriting, then revisit two earlier examples next time.

For a child starting around seven, begin with place-value alignment and small
addition/subtraction. A child around nine who can already explain exchanges can
start with a brief check of those methods and move to short multiplication and
division when the relevant table facts are secure. Long multiplication follows
short multiplication; two-digit long division follows short division. Choose
the starting point from demonstrated readiness, not age alone.

Generated practice currently uses whole numbers up to four digits, multipliers
up to two digits, and divisors up to two digits. The authored lessons explain
how the same methods extend to more columns. Decimal and fraction algorithms
are outside this first version.

## Printing

The screen prints the current generated questions, with blank working boxes.
Parents can include a separate answer key containing the completed grids. The
sheet number identifies the seed so a worksheet and its key always match.

Printing also works without the server, Postgres, or sign-in:

```bash
cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- worksheet-levels
cargo run --manifest-path rust/apps/control_plane/Cargo.toml -- worksheet-print \
  --level addition_2_carry --count 6 --seed 55 --answers --output /tmp/arithmetic.html
```

Choose another level ID from the first command as needed. Open the HTML file in a
browser and print or save as PDF. Omit `--seed` for a fresh set. Omit `--answers`
to create only the child's worksheet. The default is six questions; the engine
accepts 1–24. New sets are reproducible, and questions do not repeat within a set.
The bounded number ranges mean the supply is large, rather than literally infinite.

## Implementation boundary

The Rust `learning_activity_runtime::written_arithmetic` module owns levels,
generation, grid geometry, valid answers, and explanations. The control-plane
authenticates API requests and renders printable HTML from those same grids.
Flutter renders the supplied cells and reports entries back to Rust. It does not
calculate the answers or infer arithmetic progression from content documents.

The authenticated endpoints are:

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/written-arithmetic/levels` | Read the level catalog and prerequisites |
| POST | `/api/v1/written-arithmetic/generate` | Generate a seeded grid without answers |
| POST | `/api/v1/written-arithmetic/check` | Check assisted entries or a complete assessment |
| POST | `/api/v1/written-arithmetic/print` | Render A4 questions and an optional parent answer key |

The first version is stateless extra practice. It does not save responses, update
skill confirmation, or contribute evidence to the existing immutable activity
instances. Refreshing or leaving the screen discards the current work. Assisted
feedback is available during practice; assessment feedback is returned only when
`finish` is true. A score counts editable boxes, including the method's working,
rather than counting only final answers. Optional blank places earn no marks;
an incorrect entry there still counts as an error. An empty optional carry box means no
carry; mandatory answer and working boxes must be filled.

Integrating this into assignments later should use the existing immutable
activity/evidence contract, distinguish assisted work from independent checks,
and version the generated plans before recording mastery. Do not infer mastery
from these temporary extra-practice scores.
