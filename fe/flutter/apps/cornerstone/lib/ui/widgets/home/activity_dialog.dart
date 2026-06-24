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

class _ExecutableActivityPage extends StatefulWidget {
  const _ExecutableActivityPage({
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
  State<_ExecutableActivityPage> createState() =>
      _ExecutableActivityPageState();
}

class _ExecutableActivityPageState extends State<_ExecutableActivityPage> {
  late final List<TextEditingController> _answerControllers;
  final TextEditingController _notesController = TextEditingController();
  late final DateTime _startedAt;
  Timer? _timer;
  late int _elapsedSeconds;
  bool _submitting = false;
  bool _allowPop = false;
  String? _errorMessage;
  CompleteActivityResponse? _result;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.activity.startedAt.toLocal();
    _elapsedSeconds = _elapsedFromStart();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _result != null) return;
      setState(() {
        _elapsedSeconds = _elapsedFromStart();
      });
    });
    _answerControllers = widget.activity.items
        .map((_) => TextEditingController())
        .toList(growable: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _answerControllers) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  int _elapsedFromStart() {
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    return elapsed <= 0 ? 1 : elapsed;
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int? get _targetSeconds => widget.activity.scoring.maxDurationSeconds;

  bool get _hasHardTimeLimit =>
      widget.activity.scoring.maxDurationSeconds != null;

  Future<void> _requestClose() async {
    if (_submitting) return;
    if (_result != null) {
      _allowPop = true;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this run?'),
        content: const Text(
          'This generated run has not been submitted. If you leave, start a new run from the session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave run'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return;
    _allowPop = true;
    Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.onComplete(
        _answerControllers
            .map((controller) => controller.text.trim())
            .toList(growable: false),
        _elapsedFromStart(),
        _notesController.text.trim(),
      );
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _submitting = false;
        _result = response;
        _elapsedSeconds = response.activitySummary.durationSeconds;
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
    final targetSeconds = _targetSeconds;
    final elapsedColor =
        targetSeconds != null && _elapsedSeconds > targetSeconds
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _requestClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.activity.materialTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: _PillBadge(
                  text: targetSeconds == null
                      ? 'Time ${_formatSeconds(_elapsedSeconds)}'
                      : 'Time ${_formatSeconds(_elapsedSeconds)} / ${_formatSeconds(targetSeconds)}',
                  color: elapsedColor.withValues(alpha: 0.12),
                  textColor: elapsedColor,
                ),
              ),
            ),
            IconButton(
              onPressed: _requestClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
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
                          const SizedBox(height: 6),
                          Text(
                            'Time: ${result.activitySummary.durationSeconds}s',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (result.proficiency != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${result.proficiency!.verdictLabel}: ${result.proficiency!.detailLabel}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _PillBadge(
                                text: result.activitySummary.passed
                                    ? 'Pass threshold met'
                                    : result.activitySummary.completionReason ==
                                          'completed_over_time_limit'
                                    ? 'Over time'
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
                              onPressed: _requestClose,
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
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
                                  widget.activity.materialTitle,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.activity.instructions,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
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
                                  textColor:
                                      theme.colorScheme.onSecondaryContainer,
                                ),
                              if (widget.activity.scoring.maxDurationSeconds !=
                                  null)
                                _PillBadge(
                                  text:
                                      '${widget.activity.scoring.maxDurationSeconds}s target',
                                  color: theme.colorScheme.tertiaryContainer,
                                  textColor:
                                      theme.colorScheme.onTertiaryContainer,
                                ),
                              _PillBadge(
                                text: _hasHardTimeLimit
                                    ? 'time counts'
                                    : 'time recorded',
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                textColor: theme.colorScheme.onSurfaceVariant,
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
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = widget.activity.items[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
          ),
        ),
      ),
    );
  }
}
