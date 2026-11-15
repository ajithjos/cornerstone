# Activity packages

An activity package is an independently served HTML, JavaScript, and CSS
presentation for a backend-owned activity. The main Flutter app provides one
shared host. Adding a package that uses the existing host protocol does not
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
| `written-arithmetic/1.0.0` | Column grids for the four operations | Assisted `check`; `complete` in either mode |
| `numeric-questions/1.0.0` | One integer input per fact-fluency question | `complete` only; corrections after submission |

Each package is self-contained:

```text
content/activity_packages/
  registry.json
  written-arithmetic/1.0.0/
    manifest.json
    index.html
    styles.css
    bridge.js
    activity.js
  numeric-questions/1.0.0/
    manifest.json
    index.html
    styles.css
    bridge.js
    activity.js
```

`bridge.js` implements the common message protocol. Each package has its own
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
      "version": "1.0.0",
      "path": "written-arithmetic/1.0.0"
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

## Version pinning

An authored executable material can select its presentation:

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

A written material must select a package. New fact-fluency attempts without an
explicit presentation use `numeric-questions/1.0.0`. Static materials do not need
a package.

When an assigned activity starts, the control plane resolves the package and
stores its descriptor beside the immutable activity plan. The descriptor contains
`package_id`, `version`, `protocol_version`, the SHA256 of the manifest bytes as
`integrity`, and an entry URL of this form:

```text
/api/v1/activity-packages/written-arithmetic/1.0.0/index.html?integrity=<manifest-sha256>
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

The Flutter host opens the descriptor's API-origin entry URL in an iframe with
`sandbox="allow-scripts"`. The package has an opaque origin. The host binds all
actions to the activity represented by its callbacks, retains authentication,
and sends the result back to that iframe.

Every message uses `protocol: "cornerstone.activity"` and `version: 1`.

1. The child sends `{protocol, version, type: "ready"}` to its parent. It retries
   until initialized. This message carries no learner data.
2. The parent sends `{protocol, version, type: "initialize", channel, payload}`.
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
  "responses": [{"item_id": "q1.r3.c2", "value": "3"}],
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

Rows have `label`, `kind`, and `cells`. Each cell has `id` (null for fixed
content), `text`, and `max_digits`. The package renders those explicit rows and
sends the editable cell ID as `item_id`; it does not reconstruct the arithmetic
method. An assisted check sends entered cells for the chosen exercise. Completion
sends all editable cells, including blanks.

For numeric questions:

```text
{
  instructions,
  items: [{ item_id, content, response_kind: "integer" }],
  mode: "assisted" | "assessment",
  capabilities: { check: false }
}
```

The numeric package submits all answers together and displays no early feedback.
This preserves the existing fact-fluency checking policy.

A written check returns `correct_count`, `total_count`, `complete`, and
`feedback` entries with `cell_id`, `correct`, `expected`, and `explanation`.
Assigned completion returns the existing `CompleteActivityResponse`, including
`run_outcome_label`, `activity_summary`, and current-run corrections. Written
completion additionally includes `check_result` with cell-level feedback. Free
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
5. Test the protocol, package integrity, launch, checking where supported,
   completion, and an in-progress attempt pinned to the earlier version.

The current package checks run with:

```bash
node --test tests/activity_packages/*.test.cjs
cargo test --manifest-path rust/Cargo.toml -p control_plane activity_packages
```

See [Written arithmetic practice](./written-arithmetic-practice.md) for authoring
levels, assignments, guided and compact printing, and the distinction between
stored attempts and free worksheets.
