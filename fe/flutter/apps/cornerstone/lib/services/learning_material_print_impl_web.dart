import 'dart:js_interop';

import 'package:markdown/markdown.dart' as markdown;
import 'package:web/web.dart' as web;

import 'learning_material_print_payload.dart';

bool get learningMaterialPrintingSupported => true;

Future<void> printLearningMaterial(LearningMaterialPrintPayload payload) async {
  await printLearningMaterialSet(
    LearningMaterialPrintSetPayload(
      title: payload.materialTitle,
      materials: [payload],
    ),
  );
}

Future<void> printLearningMaterialSet(
  LearningMaterialPrintSetPayload payload,
) async {
  final printWindow = web.window.open(
    '',
    '_blank',
    'popup,width=900,height=1200',
  );
  if (printWindow == null) {
    throw StateError('The browser blocked the print window.');
  }

  final document = printWindow.document;
  document.write(_buildPrintableDocument(payload).toJS);
  document.close();
  printWindow.focus();
  await Future<void>.delayed(Duration.zero);
  printWindow.print();
}

String _buildPrintableDocument(LearningMaterialPrintSetPayload payload) {
  final title = _escapeText(payload.title);
  final materialSections = payload.materials
      .map(_buildPrintableMaterialSection)
      .join('\n');

  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    @page {
      size: A4;
      margin: 15mm 14mm 17mm;
    }

    :root {
      color-scheme: light;
      --ink: #172033;
      --muted: #5e6a7d;
      --line: #d9e0ea;
      --soft: #f4f7fb;
      --accent: #285d73;
      --accent-soft: #e5f1f5;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: #ffffff;
      color: var(--ink);
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 11pt;
      line-height: 1.52;
    }

    .page {
      max-width: 180mm;
      margin: 0 auto;
    }

    .material {
      break-after: page;
    }

    .material:last-of-type {
      break-after: auto;
    }

    header {
      display: grid;
      gap: 8px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--line);
      margin-bottom: 14px;
    }

    .eyebrow {
      color: var(--accent);
      font-size: 8.5pt;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      font-size: 24pt;
      line-height: 1.08;
      letter-spacing: 0;
    }

    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      color: var(--muted);
      font-size: 9.5pt;
    }

    .meta span {
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 3px 8px;
      background: var(--soft);
    }

    main {
      font-size: 11pt;
    }

    h1, h2, h3, h4 {
      break-after: avoid;
      color: var(--ink);
    }

    main h1 {
      font-size: 18pt;
      margin: 16px 0 8px;
    }

    main h2 {
      font-size: 14.5pt;
      margin: 15px 0 7px;
      padding-top: 4px;
      border-top: 1px solid var(--line);
    }

    main h3 {
      font-size: 12.5pt;
      margin: 13px 0 6px;
    }

    p {
      margin: 0 0 8px;
    }

    ul, ol {
      margin: 0 0 10px 19px;
      padding: 0;
    }

    li {
      margin: 3px 0;
    }

    strong {
      font-weight: 800;
    }

    blockquote {
      margin: 10px 0;
      padding: 8px 12px;
      border-left: 4px solid var(--accent);
      background: var(--accent-soft);
      color: #234450;
      break-inside: avoid;
    }

    code {
      padding: 1px 4px;
      border-radius: 4px;
      background: var(--soft);
      font-family: "SF Mono", ui-monospace, Menlo, Consolas, monospace;
      font-size: 9.5pt;
    }

    pre {
      white-space: pre-wrap;
      margin: 10px 0;
      padding: 10px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--soft);
      break-inside: avoid;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
      break-inside: avoid;
    }

    th, td {
      border: 1px solid var(--line);
      padding: 6px 8px;
      text-align: left;
      vertical-align: top;
    }

    th {
      background: var(--soft);
    }

    img {
      max-width: 100%;
    }

    footer {
      margin-top: 16px;
      padding-top: 8px;
      border-top: 1px solid var(--line);
      color: var(--muted);
      font-size: 8.5pt;
    }

    @media screen {
      body {
        background: #eef2f7;
      }

      .page {
        min-height: 297mm;
        margin: 24px auto;
        padding: 15mm 14mm 17mm;
        background: #ffffff;
        box-shadow: 0 18px 50px rgba(23, 32, 51, 0.14);
      }
    }
  </style>
</head>
<body>
  <article class="page">
    $materialSections
    <footer>A4 print layout</footer>
  </article>
</body>
</html>
''';
}

String _buildPrintableMaterialSection(LearningMaterialPrintPayload payload) {
  final renderedBody = markdown.markdownToHtml(
    payload.body,
    extensionSet: markdown.ExtensionSet.gitHubWeb,
  );
  final title = _escapeText(payload.materialTitle);
  final sessionTitle = _escapeText(payload.sessionTitle);
  final kind = _escapeText(payload.kindLabel);
  final minutes = payload.estimatedMinutes > 0
      ? '<span>${payload.estimatedMinutes} minutes</span>'
      : '';

  return '''
    <section class="material">
      <header>
        <div class="eyebrow">Cornerstone learning material</div>
        <h1>$title</h1>
        <div class="meta">
          <span>$sessionTitle</span>
          <span>$kind</span>
          $minutes
        </div>
      </header>
      <main>$renderedBody</main>
    </section>
''';
}

String _escapeText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
