part of '../../main.dart';

String _contractTermLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'unknown';
  }
  return normalized
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
}

class _ContractChip extends StatelessWidget {
  const _ContractChip({required this.domain, required this.value});

  final String domain;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedDomain = domain.trim().toLowerCase();
    final normalizedValue = value.trim().toLowerCase();

    final backgroundColor = _contractChipBackgroundColor(
      theme,
      domain: normalizedDomain,
      value: normalizedValue,
    );
    final foregroundColor = _contractChipForegroundColor(
      theme,
      domain: normalizedDomain,
      value: normalizedValue,
    );

    return _PillBadge(
      text:
          '${_contractTermLabel(normalizedDomain)}:${_contractTermLabel(normalizedValue)}',
      color: backgroundColor,
      textColor: foregroundColor,
    );
  }
}

class _ContractChipRow extends StatelessWidget {
  const _ContractChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            children[index],
          ],
        ],
      ),
    );
  }
}

Color _contractChipBackgroundColor(
  ThemeData theme, {
  required String domain,
  required String value,
}) {
  if (domain == 'material_kind') {
    return _materialKindBackgroundColor(theme, value);
  }

  switch (domain) {
    case 'entity':
      switch (value) {
        case 'pathway':
          return theme.colorScheme.secondaryContainer;
        case 'playlist':
          return theme.colorScheme.primary.withValues(alpha: 0.12);
        case 'session':
          return theme.colorScheme.tertiaryContainer;
        case 'session_material':
          return theme.colorScheme.surfaceContainerHighest;
        default:
          return theme.colorScheme.surfaceContainerHighest;
      }
    case 'audience':
      switch (value) {
        case 'learner':
          return theme.colorScheme.secondaryContainer;
        case 'adult':
          return theme.colorScheme.tertiaryContainer;
        default:
          return theme.colorScheme.surfaceContainerHighest;
      }
    case 'status':
      switch (value) {
        case 'live':
          return theme.colorScheme.tertiaryContainer;
        case 'adult_guided':
          return theme.colorScheme.tertiaryContainer;
        case 'learner_ready':
          return theme.colorScheme.secondaryContainer;
        case 'completed':
          return theme.colorScheme.secondaryContainer;
        case 'pending':
          return theme.colorScheme.primary.withValues(alpha: 0.12);
        case 'not_started':
          return theme.colorScheme.surfaceContainerHighest;
        default:
          return theme.colorScheme.surfaceContainerHighest;
      }
    default:
      return theme.colorScheme.surfaceContainerHighest;
  }
}

Color _contractChipForegroundColor(
  ThemeData theme, {
  required String domain,
  required String value,
}) {
  if (domain == 'material_kind') {
    return _materialKindForegroundColor(theme, value);
  }

  switch (domain) {
    case 'entity':
      switch (value) {
        case 'pathway':
          return theme.colorScheme.onSecondaryContainer;
        case 'playlist':
          return theme.colorScheme.primary;
        case 'session':
          return theme.colorScheme.onTertiaryContainer;
        case 'session_material':
          return theme.colorScheme.onSurfaceVariant;
        default:
          return theme.colorScheme.onSurfaceVariant;
      }
    case 'audience':
      switch (value) {
        case 'learner':
          return theme.colorScheme.onSecondaryContainer;
        case 'adult':
          return theme.colorScheme.onTertiaryContainer;
        default:
          return theme.colorScheme.onSurfaceVariant;
      }
    case 'status':
      switch (value) {
        case 'live':
          return theme.colorScheme.onTertiaryContainer;
        case 'adult_guided':
          return theme.colorScheme.onTertiaryContainer;
        case 'learner_ready':
          return theme.colorScheme.onSecondaryContainer;
        case 'completed':
          return theme.colorScheme.onSecondaryContainer;
        case 'pending':
          return theme.colorScheme.primary;
        case 'not_started':
          return theme.colorScheme.onSurfaceVariant;
        default:
          return theme.colorScheme.onSurfaceVariant;
      }
    default:
      return theme.colorScheme.onSurfaceVariant;
  }
}

String _materialKindFromDocument(LibraryDocumentData document) {
  final kind = document.kind.trim().toLowerCase();
  if (kind != 'material') {
    return kind;
  }

  final combined =
      '${document.sourcePath} ${document.routePath} ${document.documentId}'
          .toLowerCase();
  if (combined.contains('teaching-note') ||
      combined.contains('teaching_note')) {
    return 'teaching_note';
  }
  if (combined.contains('lesson-note') || combined.contains('lesson_note')) {
    return 'lesson_note';
  }
  if (combined.contains('-drill') || combined.contains('_drill')) {
    return 'drill';
  }
  if (combined.contains('-check') || combined.contains('_check')) {
    return 'quick_check';
  }
  if (combined.contains('-practice') || combined.contains('_practice')) {
    return 'worksheet';
  }

  return kind;
}
