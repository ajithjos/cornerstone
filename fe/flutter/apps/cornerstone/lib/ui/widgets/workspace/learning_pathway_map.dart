part of '../../../main.dart';

/// A bounded catalogue, not every pathway's complete sequence on the home page.
class _LearnerPathwayBrowser extends StatelessWidget {
  const _LearnerPathwayBrowser({
    required this.catalog,
    required this.search,
    required this.busy,
    required this.error,
    required this.onSearch,
    required this.onScope,
    required this.onPage,
    required this.onOpen,
  });
  final LearnerPathwayCatalog catalog;
  final TextEditingController search;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSearch, onScope, onOpen;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your pathways', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'See the whole journey. Open a pathway to find your place and what comes next.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final filters = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('pathways-assigned'),
                  label: Text('My pathways · ${catalog.assignedCount}'),
                  selected: catalog.scope == 'assigned',
                  onSelected: (_) => onScope('assigned'),
                ),
                ChoiceChip(
                  key: const ValueKey('pathways-all'),
                  label: Text('All pathways · ${catalog.allCount}'),
                  selected: catalog.scope == 'all',
                  onSelected: (_) => onScope('all'),
                ),
              ],
            );
            final field = TextField(
              controller: search,
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: 'Search pathways or playbooks',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          search.clear();
                          onSearch('');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [filters, const SizedBox(height: 12), field],
              );
            }
            return Row(
              children: [
                Expanded(child: filters),
                const SizedBox(width: 20),
                SizedBox(width: 330, child: field),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 3,
          child: busy ? const LinearProgressIndicator() : null,
        ),
        const SizedBox(height: 12),
        if (error != null)
          _InlineBrowseError(
            message: error!,
            onRetry: () => onPage(catalog.page),
          )
        else if (catalog.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(
                  Icons.route_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  catalog.query.isNotEmpty
                      ? 'No pathways match “${catalog.query}”.'
                      : 'Your teacher will choose your first playbook.',
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    search.clear();
                    onScope('all');
                  },
                  child: const Text('Explore all pathways'),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final pathway in catalog.items)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 16) / columns,
                      child: _LearnerPathwayCard(
                        pathway: pathway,
                        onOpen: () => onOpen(pathway.pathwayId),
                      ),
                    ),
                ],
              );
            },
          ),
        if (catalog.totalCount > catalog.pageSize) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous pathways',
                onPressed: !busy && catalog.page > 1
                    ? () => onPage(catalog.page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${catalog.page} of ${(catalog.totalCount / catalog.pageSize).ceil()} · ${catalog.totalCount} pathways',
              ),
              IconButton(
                tooltip: 'Next pathways',
                onPressed:
                    !busy &&
                        catalog.page * catalog.pageSize < catalog.totalCount
                    ? () => onPage(catalog.page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LearnerPathwayCard extends StatelessWidget {
  const _LearnerPathwayCard({required this.pathway, required this.onOpen});
  final LearnerPathwaySummary pathway;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pathway-${pathway.pathwayId}'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route_outlined, color: colors.primary, size: 22),
                    const Spacer(),
                    Text(
                      pathway.statusLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 58,
                  child: Text(
                    pathway.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: Text(
                    pathway.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: pathway.completionPercent / 100,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pathway.assignedPlaybookCount == 0
                            ? '${pathway.playbookCount} playbooks to explore'
                            : pathway.progressLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: colors.primary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningPathwayMap extends StatelessWidget {
  const _LearningPathwayMap({
    required this.pathway,
    required this.onOpenAssignment,
    this.selectedPlaylistId,
    this.compact = false,
  });
  final LearnerPathwayMap pathway;
  final ValueChanged<String> onOpenAssignment;
  final String? selectedPlaylistId;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < pathway.playbooks.length; i++)
        _PathwayPlaybookStep(
          number: i + 1,
          playbook: pathway.playbooks[i],
          last: i == pathway.playbooks.length - 1,
          selected: pathway.playbooks[i].playlistId == selectedPlaylistId,
          compact: compact,
          onOpenAssignment: onOpenAssignment,
        ),
    ],
  );
}

class _PathwayPlaybookStep extends StatelessWidget {
  const _PathwayPlaybookStep({
    required this.number,
    required this.playbook,
    required this.last,
    required this.onOpenAssignment,
    required this.selected,
    required this.compact,
  });
  final int number;
  final LearnerPathwayPlaybook playbook;
  final bool last, selected, compact;
  final ValueChanged<String> onOpenAssignment;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = playbook.canOpen;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? scheme.primary
                          : enabled
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
                              color: selected
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        color: scheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: .45)
                      : compact
                      ? Colors.transparent
                      : scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? scheme.primary
                          : compact
                          ? Colors.transparent
                          : scheme.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('pathway-playbook-${playbook.playlistId}'),
                    onTap: enabled && playbook.assignmentId != null
                        ? () => onOpenAssignment(playbook.assignmentId!)
                        : null,
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 10 : 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playbook.title,
                                  style:
                                      (compact
                                              ? theme.textTheme.titleSmall
                                              : theme.textTheme.titleMedium)
                                          ?.copyWith(
                                            color: enabled
                                                ? scheme.onSurface
                                                : scheme.onSurfaceVariant
                                                      .withValues(alpha: .65),
                                          ),
                                ),
                                if (!compact &&
                                    playbook.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    playbook.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: enabled ? 1 : .65,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  selected
                                      ? 'You are here · ${playbook.progressLabel}'
                                      : playbook.progressLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: enabled ? 1 : .65,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            enabled ? Icons.chevron_right : Icons.lock_outline,
                            size: 16,
                            color: enabled
                                ? scheme.primary
                                : scheme.onSurfaceVariant.withValues(
                                    alpha: .45,
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
        ),
      ),
    );
  }
}

class _InlineBrowseError extends StatelessWidget {
  const _InlineBrowseError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
