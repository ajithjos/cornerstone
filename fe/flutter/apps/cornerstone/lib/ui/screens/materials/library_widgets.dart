part of '../../../main.dart';

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _LibraryStepRow extends StatelessWidget {
  const _LibraryStepRow({
    super.key,
    required this.number,
    this.icon,
    required this.title,
    required this.description,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
  });
  final String? number;
  final IconData? icon;
  final String title;
  final String description;
  final String detail;
  final String actionLabel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: number != null
                  ? Text(number!, style: Theme.of(context).textTheme.titleSmall)
                  : Icon(icon, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: actionLabel,
              child: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared by the library preview and assigned work. Order and availability are
/// the server's contract; this widget only supplies the visual treatment.
class _PlaybookSectionTabs extends StatelessWidget {
  const _PlaybookSectionTabs({
    required this.sections,
    required this.selectedId,
    required this.onSelected,
  });
  final List<PlaybookSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final section in sections)
          ChoiceChip(
            key: ValueKey('section-${section.sectionId}'),
            selected: section.sectionId == selectedId,
            showCheckmark: false,
            avatar: constraints.maxWidth < 520
                ? null
                : Icon(switch (section.sectionId) {
                    'teach' => Icons.school_outlined,
                    'learn' => Icons.menu_book_outlined,
                    'practice' => Icons.edit_outlined,
                    'checkpoint' => Icons.flag_outlined,
                    _ => Icons.article_outlined,
                  }, size: 18),
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              child: Text(section.title),
            ),
            onSelected: (_) => onSelected(section.sectionId),
          ),
      ],
    ),
  );
}

class _CheckpointConditions extends StatelessWidget {
  const _CheckpointConditions({required this.policy});
  final CheckpointPolicy policy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        Text('${policy.questionCount} questions'),
        Text('${(policy.targetAccuracy * 100).round()}% to pass'),
        Text(
          policy.maxDurationSeconds == null
              ? 'No time limit'
              : 'Within ${policy.maxDurationSeconds} seconds',
        ),
        const Text('Independent work'),
      ],
    ),
  );
}

/// One level selection and one action area, shared by owners and learners.
class _PracticeLevelPicker extends StatelessWidget {
  const _PracticeLevelPicker({
    required this.levels,
    required this.selectedId,
    required this.onSelected,
    required this.detail,
  });
  final List<({String id, String title, String? status})> levels;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Widget detail;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a level', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 860
                ? 3
                : constraints.maxWidth >= 540
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < levels.length; i++)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: levels[i].id == selectedId,
                      child: Material(
                        color: levels[i].id == selectedId
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: levels[i].id == selectedId
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: InkWell(
                          key: ValueKey('level-${levels[i].id}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelected(levels[i].id),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Text(
                                  '${i + 1}'.padLeft(2, '0'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        levels[i].title,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      if (levels[i].status != null)
                                        Text(
                                          levels[i].status!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                if (levels[i].id == selectedId)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        detail,
      ],
    );
  }
}
