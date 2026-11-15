part of '../../../main.dart';

String _contractTermLabel(String value) => value
    .trim()
    .split(RegExp(r'[_\-\s]+'))
    .where((part) => part.isNotEmpty)
    .join(' ');

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

LearningMaterialPrintPayload _learningMaterialPrintPayload({
  required SessionDetail? session,
  required SessionMaterial material,
  required String body,
}) {
  return LearningMaterialPrintPayload(
    sessionTitle: session?.title ?? 'Learning',
    materialTitle: material.title,
    kindLabel: _materialKindLabel(material.kind),
    estimatedMinutes: material.estimatedMinutes,
    body: body,
  );
}

Future<void> _runPrintAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to open print preview: $error')),
    );
  }
}

Color _skillStatusBackgroundColor(ThemeData theme, SkillStatus status) {
  return switch (status) {
    SkillStatus.confirmed => theme.colorScheme.secondaryContainer,
    SkillStatus.readyForCheck => theme.colorScheme.tertiaryContainer,
    SkillStatus.needsPractice => theme.colorScheme.primary.withValues(
      alpha: 0.12,
    ),
    SkillStatus.notStarted => theme.colorScheme.surfaceContainerHighest,
  };
}

Color _skillStatusForegroundColor(ThemeData theme, SkillStatus status) {
  return switch (status) {
    SkillStatus.confirmed => theme.colorScheme.onSecondaryContainer,
    SkillStatus.readyForCheck => theme.colorScheme.onTertiaryContainer,
    SkillStatus.needsPractice => theme.colorScheme.primary,
    SkillStatus.notStarted => theme.colorScheme.onSurfaceVariant,
  };
}

class PracticeMasteryPanel extends StatelessWidget {
  const PracticeMasteryPanel({
    required this.practiceMastery,
    this.compact = false,
    super.key,
  });

  final List<PracticeMastery> practiceMastery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (practiceMastery.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fact progress', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Coverage and accuracy by fact family, based on finished runs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...practiceMastery.map(
          (mastery) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(compact ? 12 : 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.38,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mastery.materialTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PillBadge(
                      text: mastery.statusLabel.isEmpty
                          ? mastery.skillStatus.label
                          : mastery.statusLabel,
                      color: _skillStatusBackgroundColor(
                        theme,
                        mastery.skillStatus,
                      ),
                      textColor: _skillStatusForegroundColor(
                        theme,
                        mastery.skillStatus,
                      ),
                    ),
                    if (mastery.reviewStatus == ReviewStatus.due)
                      _PillBadge(
                        text: mastery.reviewStatus.label,
                        color: theme.colorScheme.errorContainer,
                        textColor: theme.colorScheme.onErrorContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mastery.families
                      .map(
                        (family) => Container(
                          constraints: BoxConstraints(
                            minWidth: compact ? 170 : 190,
                            maxWidth: compact ? 240 : 280,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                family.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${family.correctCount}/${family.attemptedCount} correct · ${(family.accuracy * 100).round()}%',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Last practised ${family.lastSeenAt.substring(0, 10)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ReviewItemActionTile extends StatelessWidget {
  const ReviewItemActionTile({
    required this.item,
    required this.onStartReview,
    super.key,
  });

  final ReviewItem item;
  final Future<void> Function(ReviewItem item) onStartReview;

  @override
  Widget build(BuildContext context) {
    final focusLabel = item.familyFocus.isNotEmpty
        ? item.familyFocus.map(_contractTermLabel).join(', ')
        : item.skillIds.map(_contractTermLabel).join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.reason),
      subtitle: Text('$focusLabel · ${item.reviewStatus.label}'),
      trailing: FilledButton.tonal(
        onPressed: item.reviewStatus == ReviewStatus.due
            ? () => onStartReview(item)
            : null,
        child: Text(item.actionLabel),
      ),
    );
  }
}

Color _markdownCodeForegroundColor(ThemeData theme) {
  return theme.colorScheme.onSurface;
}

Color _markdownCodeBackgroundColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92);
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
