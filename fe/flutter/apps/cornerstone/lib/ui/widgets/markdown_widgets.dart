part of '../../main.dart';

class _LibraryDocumentReader extends StatelessWidget {
  const _LibraryDocumentReader({
    required this.document,
    required this.busy,
    required this.routeBySourcePath,
    required this.onOpenLibraryRoute,
  });

  final LibraryDocumentData? document;
  final bool busy;
  final Map<String, String> routeBySourcePath;
  final ValueChanged<String> onOpenLibraryRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (busy && document == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (document == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CornerstoneIcons.document,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a pathway, playlist, or material to read it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final activeDocument = document!;
    final resolvedMaterialKind = _materialKindFromDocument(activeDocument);
    final canPrintDocument =
        learningMaterialPrintingSupported &&
        activeDocument.kind == 'material' &&
        (resolvedMaterialKind == 'lesson_note' ||
            resolvedMaterialKind == 'worksheet') &&
        activeDocument.body.trim().isNotEmpty;

    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
      h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      h2: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'SF Mono',
        color: _markdownCodeForegroundColor(theme),
        backgroundColor: _markdownCodeBackgroundColor(theme),
      ),
      blockquote: theme.textTheme.bodyLarge?.copyWith(
        height: 1.7,
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: _markdownCodeBackgroundColor(theme),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: theme.colorScheme.tertiary, width: 4),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeDocument.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'entity:${_contractTermLabel(activeDocument.kind)} · material_kind:${_contractTermLabel(resolvedMaterialKind)} · ${activeDocument.routePath}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContractChipRow(
                    children: [
                      _ContractChip(
                        domain: 'entity',
                        value: activeDocument.kind,
                      ),
                      if (activeDocument.kind == 'material')
                        const _ContractChip(
                          domain: 'entity',
                          value: 'session_material',
                        ),
                      _ContractChip(
                        domain: 'material_kind',
                        value: resolvedMaterialKind,
                      ),
                      _PillBadge(
                        text: 'pathway_id:${activeDocument.pathwayId}',
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        textColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (canPrintDocument) ...[
              OutlinedButton.icon(
                onPressed: () => _runPrintAction(
                  context,
                  () => printLearningMaterial(
                    LearningMaterialPrintPayload(
                      sessionTitle: 'Library',
                      materialTitle: activeDocument.title,
                      kindLabel: _materialKindLabel(resolvedMaterialKind),
                      estimatedMinutes: 0,
                      body: activeDocument.body,
                    ),
                  ),
                ),
                icon: const Icon(CornerstoneIcons.print, size: 18),
                label: const Text('Print'),
              ),
              const SizedBox(width: 10),
            ],
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: activeDocument.body),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Markdown copied to clipboard.'),
                  ),
                );
              },
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        SelectionArea(
          child: MarkdownBody(
            data: activeDocument.body,
            selectable: true,
            styleSheet: markdownStyle,
            onTapLink: (text, href, title) async {
              final routePath = _resolveLibraryRouteFromHref(
                currentSourcePath: activeDocument.sourcePath,
                href: href,
                routeBySourcePath: routeBySourcePath,
              );
              if (routePath != null) {
                onOpenLibraryRoute(routePath);
                return;
              }

              final externalHref = href?.trim();
              if (externalHref != null &&
                  (externalHref.startsWith('http://') ||
                      externalHref.startsWith('https://'))) {
                await launchUrl(Uri.parse(externalHref));
                return;
              }

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'That link is not available inside the in-app library reader.',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String? _resolveLibraryRouteFromHref({
  required String currentSourcePath,
  required String? href,
  required Map<String, String> routeBySourcePath,
}) {
  final rawHref = href?.trim();
  if (rawHref == null || rawHref.isEmpty || rawHref.startsWith('#')) {
    return null;
  }
  if (rawHref.startsWith('http://') ||
      rawHref.startsWith('https://') ||
      rawHref.startsWith('mailto:')) {
    return null;
  }

  final withoutFragment = rawHref.split('#').first.split('?').first.trim();
  if (!withoutFragment.endsWith('.md')) {
    return null;
  }

  final currentParts = currentSourcePath
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList(growable: true);
  if (currentParts.isNotEmpty) {
    currentParts.removeLast();
  }
  for (final segment in withoutFragment.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (currentParts.isNotEmpty) {
        currentParts.removeLast();
      }
      continue;
    }
    currentParts.add(segment);
  }

  final resolvedSourcePath = currentParts.join('/');
  return routeBySourcePath[resolvedSourcePath];
}
