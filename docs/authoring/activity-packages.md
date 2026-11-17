# Activity packages

An activity package is an independently served HTML, JavaScript, and CSS
presentation for a backend-owned activity. The main Flutter app provides one
shared host, framed inside the current playbook. Adding a package that uses the existing host protocol does not
require a Flutter rebuild.

Rust still owns curriculum rules, question generation, valid answers, scoring,
assignment modes, evidence, and progress. Packages render the supplied payload,
collect local responses, and request an allowed host action. A new backend
algorithm still requires a Rust change; changing a supported interaction's
presentation does not.

## Files and ownership

The packages currently supplied are:

| Package | Presentation | Supported actions |
| --- | --- | --- |
| `written-arithmetic/1.1.0` | Column grids for the four operations | Assisted `check`; `complete` in either mode |
| `numeric-questions/1.1.0` | Fact questions with optional guided working | Assisted `check` where enabled, and `complete` |

Each package is self-contained. Shared authoring sources live in
`content/activity_foundation/bridge.js` and `foundation.css`. Build their package
copies and integrity manifests with:

```bash
python3 scripts/build_activity_packages.py
python3 scripts/build_activity_packages.py --check
```

Do not hand-edit generated copies of the bridge or foundation. Each published
bundle contains its own exact copy; it never imports a mutable shared URL.

Package layout:

```text
content/activity_packages/
  registry.json
  written-arithmetic/1.1.0/
    manifest.json
    index.html
    styles.css
    foundation.css
    bridge.js
    activity.js
  numeric-questions/1.1.0/
    manifest.json
    index.html
    styles.css
    foundation.css
    bridge.js
    activity.js
```

`bridge.js` implements the common message protocol. Each package has a generated
copy so a version does not depend on another package's mutable files. The
activity-specific script renders its payload and displays backend feedback.
Neither script receives authentication credentials or a private answer key.

The static registry is separate from `content/library/registry.yaml`. A registry
entry identifies the exact package directory:

```json
{
  "packages": [
    {
      "package_id": "written-arithmetic",
      "version": "1.1.0",
      "path": "written-arithmetic/1.1.0"
    }
  ]
}
```

Keep all existing entries when registering another version. Every package's
`manifest.json` declares `package_id`, `version`, `protocol_version: 1`,
`entry: "index.html"`, a `files` array, and a `sha256` object containing the
SHA256 of each listed file's exact bytes. The checksum keys must match `files`
exactly. The manifest itself is not a served asset.

Only declared files are served. The resolver checks identities, relative paths,
file types, checksums, and size bounds. Supported asset types include HTML, JS,
CSS, JSON, SVG, PNG, JPEG, and WOFF2. Keep scripts and styles in local external
files; inline scripts, inline styles, external CDNs, and direct network requests
are not part of the package contract.

## Fresh-install cutover

This contract is installed with the clean database schema. Pre-cutover attempts,
native numeric players, old package bytes, and previous workspace contracts are
not migrated or retained as compatibility paths. The reset establishes a single
current implementation. Manifest pinning below protects attempts issued by this
implementation from changing while the child is working.

## Version pinning

An authored executable material can select its presentation:

```yaml
runtime:
  engine_id: written_arithmetic.v1
  spec_version: 1
  template_id: addition_2_carry
  presentation:
    package_id: written-arithmetic
    version: 1.1.0
  parameters:
    question_count: 6
  scoring:
    target_accuracy: 0.9
```

A written material must select a package. New fact-fluency attempts without an
explicit presentation use `numeric-questions/1.1.0`. Static materials do not need
a package.

When an assigned activity starts, the control plane resolves the package and
stores its descriptor beside the immutable activity plan. The descriptor contains
`package_id`, `version`, `protocol_version`, the SHA256 of the manifest bytes as
`integrity`, and an entry URL of this form:

```text
/api/v1/activity-packages/written-arithmetic/1.1.0/index.html?integrity=<manifest-sha256>
```

The server reads assets from the content directory at request time. It verifies
the declared file checksums and rejects an entry request if its pinned manifest
hash no longer matches. An in-progress attempt retains its issued plan and
package descriptor when resumed.

Treat a published version as immutable. Create a new version directory, register
it, and update material presentation references for future attempts. Retain old
registered versions while attempts refer to them. If a pinned package has been
changed or removed, restore that exact version; do not silently substitute a new
presentation for the old attempt.

Distribute the content files to the running server and reload changed curriculum
through the existing library reload operation. Package asset changes do not need
a Flutter rebuild. A container installation still needs its content files
updated through the installation's normal deployment or mount workflow.

## Shared host and message protocol

The Flutter web host embeds the descriptor's API-origin entry URL in an iframe with
`sandbox="allow-scripts"`. The package has an opaque origin. The host binds all
actions to the activity represented by its callbacks, retains authentication,
and sends the result back to that iframe.

Use `type="button"` and a click handler for completion, and send the responses through the bridge. Do not rely on native form submission or the form `submit` event: the script-only sandbox blocks it before that event reaches the package. Enter and Space must activate the same completion button. Qualify completion inside the actual sandboxed host, not only in a standalone page.

Every message uses `protocol: "cornerstone.activity"` and `version: 1`.

1. The child sends `{protocol, version, type: "ready"}` to its parent. It retries
   until initialized. This message carries no learner data.
2. The parent sends `{protocol, version, type: "initialize", channel, payload, appearance}`.
   `channel` is a random per-host token.
3. The child accepts initialization only from `window.parent` with a non-null
   HTTP(S) origin. It pins that parent origin and channel.
4. The child requests an action using the message below.
5. The host validates the iframe source, opaque origin, envelope, channel,
   request identifier, action, response list, and duration. It calls the captured
   authenticated backend action and replies to the same iframe.

```json
{
  "protocol": "cornerstone.activity",
  "version": 1,
  "channel": "<host-issued-channel>",
  "type": "request",
  "request_id": "activity-1",
  "action": "complete",
  "responses": [{"item_id": "q1.v2.r3.c2", "value": "3"}],
  "duration_seconds": 42
}
```

The only actions are `check` and `complete`. Whether `check` is allowed depends
on the backend-owned activity mode and capability. `duration_seconds` is a
nonnegative integer up to 86,400; the server also measures the elapsed time of
assigned attempts. Response identifiers come directly from the supplied payload.

A successful reply is:

```json
{
  "protocol": "cornerstone.activity",
  "version": 1,
  "channel": "<host-issued-channel>",
  "type": "response",
  "request_id": "activity-1",
  "ok": true,
  "result": {}
}
```

For an unsuccessful request, the host sends `ok: false` and `error` instead of
`result`. The package keeps the entered work and allows a retry. Replies are
accepted only from the pinned parent origin and source, with the matching
channel and pending request identifier. The host processes one action at a time
and locks completion after success; the package also disables inputs after a
successful `complete` reply.

The host uses `"*"` as the target origin when sending to its sandboxed opaque
child. The child uses the pinned HTTP(S) parent origin after initialization.
Static assets contain no learner data. The server's content security policy
allows local assets and the configured frontend ancestor, blocks network
connections and form submission, and applies the script-only sandbox. Set
`CORNERSTONE_FRONTEND_PUBLIC_URL` to the frontend URL actually used by the browser
so its origin is allowed to embed the activity.

## Appearance and interaction foundation

The activity has no separate theme switch. The Flutter app owns appearance and
sends the current `ThemeData` colours on initialization. When appearance changes,
it sends an `appearance` message on the same pinned channel:

```json
{
  "protocol": "cornerstone.activity",
  "version": 1,
  "type": "appearance",
  "channel": "<host-issued-channel>",
  "appearance": {
    "mode": "light",
    "colors": { "background": "#f7f7f2", "surface": "#ffffff" }
  }
}
```

The abbreviated example shows two colours; actual messages provide all required
tokens: `background`, `surface`, `surface-muted`, `text`, `muted`, `border`,
`primary`, `on-primary`, `primary-container`, `on-primary-container`, `error`,
`error-container`, `on-error-container`, `success`, `success-container`, `focus`.
Each is a six-digit hexadecimal colour. The shared bridge rejects incomplete or
invalid colour sets, ignores unknown tokens, and accepts updates only from the
pinned host window, origin and channel. Updates set CSS custom properties
`--cs-<token>` without invoking the activity initializer or clearing any answers.

Every package loads `foundation.css` before its own stylesheet. It supplies the
semantic palette, a system font stack, colour-scheme defaults, box sizing,
selection colours and reduced-motion behavior. `activity_package_appearance.dart`
is the single mapping from the live app theme to package colours. App colour
changes therefore reach all compatible activities automatically. Foundation
spacing and typography changes are bundled using the build script.

Authoring rules:

- Use foundation tokens for all colours. Pair foreground/background tokens;
  use `--cs-on-primary` for primary-button labels rather than hard-coded white.
- Keep interactive content within a readable maximum width. Let narrow screens
  stack cards and scroll long written grids within their card.
- Keep native navigation and the playbook visible around the activity. The
  package contains the exercise, not a second navigation system or login flow.
- Use real buttons and labelled inputs, visible keyboard focus, touch targets
  around 44px, and text or symbols as well as colour for correctness.
- Keep activity state intact during appearance updates. Avoid animations when
  reduced motion is requested.
- Use the backend's purpose-built print endpoint for compact or guided sheets;
  printing remains white-paper output independent of the screen theme.
- Preserve the backend's assessment policy. A package must not reveal private
  answers or invent grading rules.

`ActivityPackagePage` supports an `onClose` callback for embedded use. Its public
`requestClose()` guards unsent answers and blocks leaving while submission is in
flight. The host displays recorded results and exact-mistake retries. The native
shell uses this guard before changing destination or identity. The web iframe is
the implemented platform adapter; other Flutter targets need a web-view adapter
before packages can run there.

## Payload and result shapes

The host passes the backend's payload through unchanged.

For written arithmetic:

```text
{
  worksheet: { request, level, problems: [{ id, prompt, columns, rows }] },
  mode: "assisted" | "assessment",
  capabilities: { check: true | false }
}
```

Each problem supplies place names in `column_labels`. Rows have `label`, `kind`, and `cells`. Each cell has `id` (null for fixed
content), `text`, and `max_digits`. An optional row-level `trailing_sign` places the operation sign after the ones digit. The package renders those explicit rows and
sends the editable cell ID as `item_id`; it does not reconstruct the arithmetic
method. An assisted check covers the chosen exercise. Completion asks the learner to fill every editable box.

For numeric questions:

```text
{
  instructions,
  items: [{ item_id, content, response_kind: "integer", steps?: [{ item_id, prompt }], answer_prompt?, equation? }],
  mode: "assisted" | "assessment",
  capabilities: { check: true | false }
}
```

In guided practice the optional equation supplies one square per working field and a final square for the answer. The child fills a row, checks it once, and sees one correction or success message. One fact earns one mark when all of its fields are correct. Recall checkpoints use a single answer field per question and return corrections after submission. Stored attempts keep their original package version, plan and marking rules.

A written check returns `correct_count`, `total_count`, `complete`, and
`feedback` entries with `cell_id`, `correct`, `expected`, and `explanation`.
Assigned completion returns the existing `CompleteActivityResponse`, including
`run_outcome_label`, `activity_summary`, and current-run corrections. Written and guided fact
completion additionally include `check_result` with cell-level feedback. Free
worksheet completion returns the written check result directly. Packages display
these server results; they do not calculate scores or infer mastery.

## Add or replace a presentation

1. Create a new package/version directory using local HTML, CSS, and JavaScript.
2. Implement protocol v1, bounded payload validation, accessible inputs, and
   readable backend feedback. Use `textContent` for supplied text.
3. List the assets in `manifest.json` and calculate their hashes after the files
   are final. Hash the actual bytes; changing whitespace also changes a hash.
4. Add the package/version to `registry.json` and reference it from an executable
   material whose Rust engine supplies the required payload and scoring.
5. Test the protocol, package integrity, theme updates without losing answers,
   embedded launch/exit, checking where supported, completion and retry.

The current package checks run with:

```bash
node --test tests/activity_packages/*.test.cjs
cargo test --manifest-path rust/Cargo.toml -p control_plane activity_packages
```

See [Written arithmetic practice](./written-arithmetic-practice.md) for authoring
levels, assignments, guided and compact printing, and the distinction between
stored attempts and free worksheets.

### Host overlays and compact layouts

The host suspends iframe pointer and keyboard interaction while a modal or profile menu is open, without unmounting the iframe. Closing an overlay must restore the same exercise and input values. Qualify Stay and Leave with real browser pointer clicks, because widget tests cannot reproduce iframe event interception.

Written layouts use three columns for short calculations and wider cards for long working grids. Preserve readable inputs and keyboard navigation; do not shrink complex multiplication or division to fit an arbitrary question count. Owner previews use the same package and appearance contract as assigned learner activities.
