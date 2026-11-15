part of '../../../main.dart';

class _LearningPathwayMap extends StatelessWidget {
  const _LearningPathwayMap({
    required this.pathways,
    required this.onOpenAssignment,
  });
  final List<LearnerPathwayMap> pathways;
  final ValueChanged<String> onOpenAssignment;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final pathway in pathways)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 16) / columns,
                child: Material(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.route_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pathway.title,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pathway.progressLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < pathway.playbooks.length; i++)
                          _PathwayPlaybookStep(
                            number: i + 1,
                            playbook: pathway.playbooks[i],
                            last: i == pathway.playbooks.length - 1,
                            onOpenAssignment: onOpenAssignment,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PathwayPlaybookStep extends StatelessWidget {
  const _PathwayPlaybookStep({
    required this.number,
    required this.playbook,
    required this.last,
    required this.onOpenAssignment,
  });
  final int number;
  final LearnerPathwayPlaybook playbook;
  final bool last;
  final ValueChanged<String> onOpenAssignment;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = playbook.canOpen;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        key: ValueKey('pathway-playbook-${playbook.playlistId}'),
        borderRadius: BorderRadius.circular(8),
        onTap: enabled && playbook.assignmentId != null
            ? () => onOpenAssignment(playbook.assignmentId!)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerLow,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: playbook.status == 'completed'
                            ? Icon(Icons.check, size: 16, color: scheme.primary)
                            : Text(
                                '$number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: enabled
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playbook.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: enabled
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: .65,
                                      ),
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          playbook.progressLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: enabled ? 1 : .65,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      enabled ? Icons.chevron_right : Icons.lock_outline,
                      size: 16,
                      color: enabled
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: .45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
