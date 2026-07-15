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

String _runModeLabel(RunMode mode) => switch (mode) {
  RunMode.practice => 'Practice',
  RunMode.check => 'Check',
  RunMode.review => 'Review',
  RunMode.retry => 'Missed-fact retry',
};

class ExecutableActivityPage extends StatefulWidget {
  const ExecutableActivityPage({
    required this.activity,
    required this.onComplete,
    required this.onRetry,
    super.key,
  });

  final ActivityInstance activity;
  final Future<CompleteActivityResponse> Function(
    ActivityInstance activity,
    List<String> answers,
    int durationSeconds,
    String notes,
  )
  onComplete;
  final Future<ActivityInstance> Function(ActivityInstance activity) onRetry;

  @override
  State<ExecutableActivityPage> createState() => ExecutableActivityPageState();
}

class ExecutableActivityPageState extends State<ExecutableActivityPage> {
  late ActivityInstance _activity;
  late List<TextEditingController> _answerControllers;
  final TextEditingController _notesController = TextEditingController();
  late DateTime _startedAt;
  Timer? _timer;
  late int _elapsedSeconds;
  bool _submitting = false;
  bool _allowPop = false;
  String? _errorMessage;
  CompleteActivityResponse? _result;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _startedAt = _activity.startedAt.toLocal();
    _elapsedSeconds = _elapsedFromStart();
    _startTimer();
    _answerControllers = _newAnswerControllers(_activity);
  }

  List<TextEditingController> _newAnswerControllers(
    ActivityInstance activity,
  ) => activity.items
      .map((_) => TextEditingController())
      .toList(growable: false);

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _result != null) return;
      setState(() {
        _elapsedSeconds = _elapsedFromStart();
      });
    });
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

  int? get _targetSeconds => _activity.scoring.maxDurationSeconds;

  bool get _hasHardTimeLimit => _activity.scoring.maxDurationSeconds != null;

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
        _activity,
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

  Future<void> _retryMissedFacts() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final nextActivity = await widget.onRetry(_activity);
      if (!mounted) return;
      final nextControllers = _newAnswerControllers(nextActivity);
      for (final controller in _answerControllers) {
        controller.dispose();
      }
      _notesController.clear();
      setState(() {
        _activity = nextActivity;
        _answerControllers = nextControllers;
        _startedAt = nextActivity.startedAt.toLocal();
        _elapsedSeconds = _elapsedFromStart();
        _result = null;
        _submitting = false;
      });
      _startTimer();
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
          title: Text(_activity.materialTitle),
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
                    ? ListView(
                        children: [
                          Text(
                            _activity.materialTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${result.activitySummary.correctCount}/${result.activitySummary.itemCount} correct (${(result.activitySummary.accuracy * 100).round()}%).',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Time: ${result.activitySummary.durationSeconds}s',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (result.readiness != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${result.readiness!.statusLabel}: ${result.readiness!.detailLabel}',
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
                                text: result.runOutcomeLabel,
                                color: result.runOutcome == RunOutcome.targetMet
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.errorContainer,
                                textColor:
                                    result.runOutcome == RunOutcome.targetMet
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onErrorContainer,
                              ),
                              _PillBadge(
                                text: 'Run finished',
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                textColor: theme.colorScheme.onSurfaceVariant,
                              ),
                              ...result.activitySummary.weakFamilies.map(
                                (family) => _PillBadge(
                                  text: _humanizeLabel(family),
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  textColor: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          if (result
                              .activitySummary
                              .corrections
                              .isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Text(
                              'Corrections',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Review each missed item before trying it again.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...result.activitySummary.corrections.map(
                              (correction) => Container(
                                key: ValueKey(
                                  'correction-${correction.itemId}',
                                ),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer
                                      .withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      correction.content,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your answer: ${correction.submittedResponse.isEmpty ? 'No answer' : correction.submittedResponse}',
                                    ),
                                    Text(
                                      'Correct answer: ${correction.expectedResponse}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (correction
                                        .correctionCue
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        correction.correctionCue,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (result.retryAvailable &&
                                  result.activitySummary.corrections.isNotEmpty)
                                FilledButton.icon(
                                  key: const ValueKey('practise-missed-facts'),
                                  onPressed: _submitting
                                      ? null
                                      : _retryMissedFacts,
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.replay_rounded,
                                          size: 18,
                                        ),
                                  label: const Text('Practise missed facts'),
                                ),
                              OutlinedButton(
                                onPressed: _submitting ? null : _requestClose,
                                child: const Text('Close'),
                              ),
                            ],
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
                                  _activity.materialTitle,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _activity.instructions,
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
                                text: 'Run in progress',
                                color: theme.colorScheme.tertiaryContainer,
                                textColor:
                                    theme.colorScheme.onTertiaryContainer,
                              ),
                              _PillBadge(
                                text: _runModeLabel(_activity.runMode),
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                textColor: theme.colorScheme.onSurfaceVariant,
                              ),
                              _PillBadge(
                                text: '${_activity.items.length} items',
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                textColor: theme.colorScheme.primary,
                              ),
                              _PillBadge(
                                text: '${_activity.estimatedMinutes} min',
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                textColor: theme.colorScheme.primary,
                              ),
                              _PillBadge(
                                text:
                                    '${(_activity.scoring.targetAccuracy * 100).round()}% target',
                                color: theme.colorScheme.secondaryContainer,
                                textColor:
                                    theme.colorScheme.onSecondaryContainer,
                              ),
                              if (_activity.scoring.maxDurationSeconds != null)
                                _PillBadge(
                                  text:
                                      '${_activity.scoring.maxDurationSeconds}s target',
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
                              itemCount: _activity.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _activity.items[index];
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
