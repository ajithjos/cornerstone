part of '../../../main.dart';

String _humanizeLabel(String value) {
  final parts = value
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return value;
  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ExecutableActivityDialog extends StatefulWidget {
  const _ExecutableActivityDialog({
    required this.activity,
    required this.onComplete,
  });

  final ActivityInstance activity;
  final Future<CompleteActivityResponse> Function(
    List<String> answers,
    int durationSeconds,
    String notes,
  )
  onComplete;

  @override
  State<_ExecutableActivityDialog> createState() =>
      _ExecutableActivityDialogState();
}

class _ExecutableActivityDialogState extends State<_ExecutableActivityDialog> {
  late final List<TextEditingController> _answerControllers;
  final TextEditingController _notesController = TextEditingController();
  late final DateTime _startedAt;
  bool _submitting = false;
  String? _errorMessage;
  CompleteActivityResponse? _result;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _answerControllers = widget.activity.items
        .map((_) => TextEditingController())
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      final response = await widget.onComplete(
        _answerControllers
            .map((controller) => controller.text.trim())
            .toList(growable: false),
        elapsedSeconds <= 0 ? 1 : elapsedSeconds,
        _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = response;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: result != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.materialTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed with ${result.activitySummary.correctCount}/${result.activitySummary.itemCount} correct (${(result.activitySummary.accuracy * 100).round()}%).',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PillBadge(
                          text: result.activitySummary.passed
                              ? 'Pass threshold met'
                              : 'More review needed',
                          color: result.activitySummary.passed
                              ? theme.colorScheme.secondaryContainer
                              : theme.colorScheme.errorContainer,
                          textColor: result.activitySummary.passed
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onErrorContainer,
                        ),
                        ...result.activitySummary.weakGroups.map(
                          (group) => _PillBadge(
                            text: _humanizeLabel(group),
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            textColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.activity.materialTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.activity.instructions,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PillBadge(
                          text: '${widget.activity.items.length} items',
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          textColor: theme.colorScheme.primary,
                        ),
                        _PillBadge(
                          text: '${widget.activity.estimatedMinutes} min',
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          textColor: theme.colorScheme.primary,
                        ),
                        if (widget.activity.scoring.passAccuracy != null)
                          _PillBadge(
                            text:
                                '${(widget.activity.scoring.passAccuracy! * 100).round()}% pass',
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.activity.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = widget.activity.items[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Item ${index + 1}',
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.content,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _answerControllers[index],
                                  keyboardType: TextInputType.number,
                                  enabled: !_submitting,
                                  decoration: const InputDecoration(
                                    labelText: 'Response',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      enabled: !_submitting,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes for this run',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                CornerstoneIcons.activity,
                                size: 18,
                              ),
                        label: const Text('Submit activity'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
