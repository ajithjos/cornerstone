part of '../../../main.dart';

Color _materialKindBackgroundColor(ThemeData theme, String kind) {
  switch (kind) {
    case 'lesson_note':
      return theme.colorScheme.secondaryContainer;
    case 'teaching_note':
      return theme.colorScheme.tertiaryContainer;
    case 'worksheet':
      return theme.colorScheme.primary.withValues(alpha: 0.12);
    case 'drill':
      return theme.colorScheme.tertiaryContainer;
    case 'quick_check':
      return theme.colorScheme.secondaryContainer.withValues(alpha: 0.7);
    default:
      return theme.colorScheme.surfaceContainerHighest;
  }
}

Color _materialKindForegroundColor(ThemeData theme, String kind) {
  switch (kind) {
    case 'lesson_note':
      return theme.colorScheme.onSecondaryContainer;
    case 'teaching_note':
      return theme.colorScheme.onTertiaryContainer;
    case 'worksheet':
      return theme.colorScheme.primary;
    case 'drill':
      return theme.colorScheme.onTertiaryContainer;
    case 'quick_check':
      return theme.colorScheme.onSecondaryContainer;
    default:
      return theme.colorScheme.onSurfaceVariant;
  }
}

IconData _materialKindIcon(String kind) => CornerstoneIcons.materialKind(kind);

String _materialKindLabel(String kind) {
  switch (kind) {
    case 'lesson_note':
      return 'Lesson note';
    case 'teaching_note':
      return 'Teaching note';
    case 'worksheet':
      return 'Practice sheet';
    case 'drill':
      return 'Drill';
    case 'quick_check':
      return 'Assessment';
    default:
      return _contractTermLabel(kind);
  }
}

String _materialActionLabel(String kind, {bool repeat = false}) {
  switch (kind) {
    case 'lesson_note':
      return 'Read lesson';
    case 'teaching_note':
      return 'Open teaching note';
    case 'worksheet':
      return 'Open practice sheet';
    case 'drill':
      return repeat ? 'Practice again' : 'Start drill';
    case 'quick_check':
      return repeat ? 'Retake assessment' : 'Start assessment';
    default:
      return 'Open material';
  }
}

String _materialDocumentActionLabel(String kind) {
  switch (kind) {
    case 'lesson_note':
      return 'Read lesson';
    case 'teaching_note':
      return 'Open teaching note';
    case 'worksheet':
      return 'Open practice sheet';
    case 'drill':
      return 'Open drill notes';
    case 'quick_check':
      return 'Open assessment notes';
    default:
      return 'Open material';
  }
}

Color _proficiencyBackgroundColor(
  ThemeData theme,
  SessionMaterialProficiencySummary proficiency,
) {
  return switch (proficiency.verdict) {
    'ready_to_move_on' => theme.colorScheme.secondaryContainer,
    'nearly_secure' => theme.colorScheme.tertiaryContainer,
    _ => theme.colorScheme.primary.withValues(alpha: 0.12),
  };
}

Color _proficiencyForegroundColor(
  ThemeData theme,
  SessionMaterialProficiencySummary proficiency,
) {
  return switch (proficiency.verdict) {
    'ready_to_move_on' => theme.colorScheme.onSecondaryContainer,
    'nearly_secure' => theme.colorScheme.onTertiaryContainer,
    _ => theme.colorScheme.primary,
  };
}

Color _markdownCodeForegroundColor(ThemeData theme) {
  return theme.colorScheme.onSurface;
}

Color _markdownCodeBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92);
}

double _desktopStudioHeight(
  BuildContext context, {
  double subtract = 240,
  double minHeight = 680,
  double maxHeight = 960,
}) {
  final height = MediaQuery.sizeOf(context).height - subtract;
  if (height < minHeight) {
    return minHeight;
  }
  if (height > maxHeight) {
    return maxHeight;
  }
  return height;
}

MarkdownStyleSheet _workspaceMarkdownStyle(ThemeData theme) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
    h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'SF Mono',
      color: _markdownCodeForegroundColor(theme),
      backgroundColor: _markdownCodeBackgroundColor(theme),
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: _markdownCodeBackgroundColor(theme),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.82),
      ),
    ),
  );
}

class _SessionMaterialGroupPanel extends StatelessWidget {
  const _SessionMaterialGroupPanel({
    required this.group,
    required this.showDocumentBodies,
    this.session,
    this.viewerCanReadLibrary = false,
    this.onOpenLibraryRoute,
    this.onStartActivity,
  });

  final SessionMaterialKindGroup group;
  final SessionDetail? session;
  final bool viewerCanReadLibrary;
  final bool showDocumentBodies;
  final ValueChanged<String>? onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)?
  onStartActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = _materialKindBackgroundColor(theme, group.kind);
    final foregroundColor = _materialKindForegroundColor(theme, group.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _materialKindIcon(group.kind),
                  size: 20,
                  color: foregroundColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _materialKindLabel(group.kind),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    _ContractChipRow(
                      children: [
                        _ContractChip(
                          domain: 'material_kind',
                          value: group.kind,
                        ),
                        _ContractChip(
                          domain: 'audience',
                          value: group.audience,
                        ),
                        _PillBadge(
                          text: 'count:${group.materialCount}',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.materials.map((material) {
            final hasDocumentBody = (material.documentBody ?? '')
                .trim()
                .isNotEmpty;
            final canOpenDocument =
                viewerCanReadLibrary &&
                onOpenLibraryRoute != null &&
                material.documentRoutePath != null;
            final canStart =
                session != null &&
                onStartActivity != null &&
                material.canStartActivity;
            final isRepeatableRun =
                canStart &&
                (material.status == 'completed' ||
                    session?.status == 'completed');
            final gate = material.gate;
            final proficiency = material.proficiency;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  _ContractChipRow(
                    children: [
                      _ContractChip(
                        domain: 'entity',
                        value: 'session_material',
                      ),
                      _ContractChip(
                        domain: 'material_kind',
                        value: material.kind,
                      ),
                      _PillBadge(
                        text: '${material.estimatedMinutes} min',
                        color: backgroundColor,
                        textColor: foregroundColor,
                      ),
                      if (material.isExecutable)
                        _ContractChip(domain: 'status', value: 'live'),
                      if (proficiency != null)
                        _PillBadge(
                          text: proficiency.verdictLabel,
                          color: _proficiencyBackgroundColor(
                            theme,
                            proficiency,
                          ),
                          textColor: _proficiencyForegroundColor(
                            theme,
                            proficiency,
                          ),
                        ),
                      if (gate != null && !gate.enabled)
                        _PillBadge(
                          text: 'locked',
                          color: theme.colorScheme.errorContainer,
                          textColor: theme.colorScheme.onErrorContainer,
                        ),
                      if (isRepeatableRun)
                        _PillBadge(
                          text: 'repeat any time',
                          color: theme.colorScheme.secondaryContainer,
                          textColor: theme.colorScheme.onSecondaryContainer,
                        ),
                    ],
                  ),
                  if (showDocumentBodies && hasDocumentBody) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectionArea(
                        child: MarkdownBody(
                          data: gate != null && !gate.enabled
                              ? gate.reasonLabel
                              : material.documentBody!,
                          selectable: true,
                          styleSheet: _workspaceMarkdownStyle(theme),
                        ),
                      ),
                    ),
                  ],
                  if (proficiency != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      proficiency.detailLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (gate != null && !gate.enabled) ...[
                    const SizedBox(height: 10),
                    Text(
                      gate.reasonLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (canStart || canOpenDocument) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (canStart)
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                onStartActivity!(session!, material),
                            icon: Icon(
                              CornerstoneIcons.materialKind(material.kind),
                              size: 18,
                            ),
                            label: Text(
                              _materialActionLabel(
                                material.kind,
                                repeat: isRepeatableRun,
                              ),
                            ),
                          ),
                        if (canOpenDocument)
                          TextButton.icon(
                            onPressed: () => onOpenLibraryRoute!(
                              material.documentRoutePath!,
                            ),
                            icon: const Icon(
                              CornerstoneIcons.document,
                              size: 18,
                            ),
                            label: Text(
                              _materialDocumentActionLabel(material.kind),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WorkspaceMaterialGroupPanel extends StatelessWidget {
  const _WorkspaceMaterialGroupPanel({
    required this.group,
    required this.onOpenLibraryRoute,
  });

  final WorkspaceMaterialKindGroup group;
  final ValueChanged<String> onOpenLibraryRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContractChipRow(
            children: [
              _ContractChip(domain: 'material_kind', value: group.kind),
              _PillBadge(
                text: 'count:${group.materialCount}',
                color: theme.colorScheme.surfaceContainerHighest,
                textColor: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group.materials.map(
            (material) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(material.title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        _ContractChipRow(
                          children: [
                            _ContractChip(
                              domain: 'entity',
                              value: 'session_material',
                            ),
                            _ContractChip(
                              domain: 'material_kind',
                              value: material.kind,
                            ),
                            _PillBadge(
                              text: '${material.estimatedMinutes} min',
                              color: theme.colorScheme.surfaceContainerHighest,
                              textColor: theme.colorScheme.onSurfaceVariant,
                            ),
                            if (material.executable)
                              _ContractChip(domain: 'status', value: 'live'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (material.routePath != null)
                    TextButton(
                      onPressed: () => onOpenLibraryRoute(material.routePath!),
                      child: const Text('Open'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionWorkspaceAudiencePanel extends StatelessWidget {
  const _SessionWorkspaceAudiencePanel({
    required this.title,
    required this.description,
    required this.emptyState,
    required this.icon,
    required this.groups,
    required this.session,
    required this.viewerCanReadLibrary,
    required this.showDocumentBodies,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
  });

  final String title;
  final String description;
  final String emptyState;
  final IconData icon;
  final List<SessionMaterialKindGroup> groups;
  final SessionDetail session;
  final bool viewerCanReadLibrary;
  final bool showDocumentBodies;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            Text(
              emptyState,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...groups.map(
              (group) => _SessionMaterialGroupPanel(
                group: group,
                session: session,
                viewerCanReadLibrary: viewerCanReadLibrary,
                showDocumentBodies: showDocumentBodies,
                onOpenLibraryRoute: onOpenLibraryRoute,
                onStartActivity: onStartActivity,
              ),
            ),
        ],
      ),
    );
  }
}

class _MissingLearnerContentNotice extends StatelessWidget {
  const _MissingLearnerContentNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This session is missing learner content.',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask your parent or teacher to add learner-facing material for this step before you continue.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebarButton extends StatelessWidget {
  const _DesktopSidebarButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.level = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = switch (level) {
      0 => theme.colorScheme.secondary,
      1 => theme.colorScheme.primary,
      2 => theme.colorScheme.tertiary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final baseColor = switch (level) {
      0 =>
        isDark
            ? Color.alphaBlend(
                theme.colorScheme.secondary.withValues(alpha: 0.08),
                theme.colorScheme.surfaceContainerHigh,
              )
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.82),
      1 => Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.10),
        isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
      ),
      2 => Color.alphaBlend(
        theme.colorScheme.tertiary.withValues(alpha: isDark ? 0.08 : 0.10),
        isDark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
      ),
      _ =>
        isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.74)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
    };
    final baseTextColor = switch (level) {
      0 => theme.colorScheme.onSurface,
      1 => theme.colorScheme.primary,
      2 => theme.colorScheme.tertiary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: 14 - (level > 2 ? 2 : 0),
          vertical: level >= 2 ? 11 : 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? baseColor.withValues(alpha: 0.88)
              : baseColor.withValues(alpha: level == 0 ? 0.42 : 0.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? baseTextColor.withValues(alpha: 0.22)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: level >= 2 ? 20 : 26,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: selected ? 0.92 : 0.36),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: level >= 2 ? 24 : 28,
              height: level >= 2 ? 24 : 28,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: isDark ? 0.16 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: level >= 2 ? 14 : 16,
                color: selected
                    ? baseTextColor
                    : accentColor.withValues(alpha: 0.84),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style:
                    (level >= 2
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.titleSmall)
                        ?.copyWith(
                          color: selected ? baseTextColor : null,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
