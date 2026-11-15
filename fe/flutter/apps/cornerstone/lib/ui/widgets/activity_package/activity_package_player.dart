import 'package:flutter/material.dart';

import '../../../models/activity_presentation.dart';
import 'activity_package_player_stub.dart'
    if (dart.library.js_interop) 'activity_package_player_web.dart'
    as impl;
import 'activity_package_protocol.dart';

export 'activity_package_protocol.dart' show ActivityPackageAction;

class ActivityPackagePlayer extends StatelessWidget {
  const ActivityPackagePlayer({
    super.key,
    required this.presentation,
    required this.apiBaseUrl,
    required this.onCheck,
    required this.onComplete,
    this.onCompleted,
  });
  final ActivityPresentation presentation;
  final String apiBaseUrl;
  final ActivityPackageAction onCheck;
  final ActivityPackageAction onComplete;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) => impl.ActivityPackagePlayerView(
    presentation: presentation,
    apiBaseUrl: apiBaseUrl,
    onCheck: onCheck,
    onComplete: onComplete,
    onCompleted: onCompleted,
  );
}

class ActivityPackageRun {
  const ActivityPackageRun({
    required this.id,
    required this.title,
    required this.presentation,
    required this.onCheck,
    required this.onComplete,
    this.onRetry,
  });
  final String id;
  final String title;
  final ActivityPresentation presentation;
  final ActivityPackageAction onCheck;
  final ActivityPackageAction onComplete;
  final Future<ActivityPackageRun> Function()? onRetry;
}

class ActivityPackagePage extends StatefulWidget {
  const ActivityPackagePage({
    super.key,
    required this.run,
    required this.apiBaseUrl,
  });
  final ActivityPackageRun run;
  final String apiBaseUrl;
  @override
  State<ActivityPackagePage> createState() => _ActivityPackagePageState();
}

class _ActivityPackagePageState extends State<ActivityPackagePage> {
  late ActivityPackageRun _run;
  bool _completed = false;
  bool _allowPop = false;
  bool _retrying = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _run = widget.run;
  }

  Future<Map<String, dynamic>> _complete(
    List<Map<String, String>> responses,
    int duration,
  ) async {
    final result = await _run.onComplete(responses, duration);
    if (mounted) setState(() => _result = result);
    return result;
  }

  Future<void> _retry() async {
    final retry = _run.onRetry;
    if (retry == null) return;
    setState(() {
      _retrying = true;
      _error = null;
    });
    try {
      final run = await retry();
      if (mounted) {
        setState(() {
          _run = run;
          _completed = false;
          _result = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _close() async {
    if (_retrying) return;
    final leave =
        _completed ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave this activity?'),
                content: const Text('Your unsent answers will be lost.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Leave'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_completed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final readiness = result?['readiness'];
    final summary = result?['activity_summary'];
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_run.title),
          leading: IconButton(
            onPressed: _retrying ? null : _close,
            tooltip: 'Close activity',
            icon: const Icon(Icons.close),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ActivityPackagePlayer(
                key: ValueKey(_run.id),
                presentation: _run.presentation,
                apiBaseUrl: widget.apiBaseUrl,
                onCheck: _run.onCheck,
                onComplete: _complete,
                onCompleted: () => setState(() => _completed = true),
              ),
            ),
            if (result != null && summary is Map)
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result['run_outcome_label'] ?? 'Activity finished'} • ${summary['correct_count']}/${summary['item_count']} correct • ${summary['duration_seconds']}s',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (readiness is Map)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${readiness['status_label'] ?? ''}: ${readiness['detail_label'] ?? ''}',
                          ),
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (result['retry_available'] == true &&
                              _run.onRetry != null)
                            FilledButton.icon(
                              onPressed: _retrying ? null : _retry,
                              icon: const Icon(Icons.replay),
                              label: const Text('Practise missed items'),
                            ),
                          OutlinedButton(
                            onPressed: _retrying ? null : _close,
                            child: const Text('Close'),
                          ),
                          if (_retrying)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
