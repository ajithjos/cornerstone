import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../models/activity_presentation.dart';
import 'activity_package_protocol.dart';

// Dart equality may inspect a WindowProxy's dispatch properties, which the
// browser forbids across a sandbox boundary. JavaScript identity does not.
@JS('Object.is')
external bool _sameWindow(JSAny? left, JSAny? right);

class ActivityPackagePlayerView extends StatefulWidget {
  const ActivityPackagePlayerView({
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
  State<ActivityPackagePlayerView> createState() =>
      _ActivityPackagePlayerViewState();
}

class _ActivityPackagePlayerViewState extends State<ActivityPackagePlayerView> {
  late final ActivityPackageProtocol _protocol;
  late final web.HTMLIFrameElement _frame;
  late final String _viewType;
  JSFunction? _messageListener;
  Timer? _timeout;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _protocol = ActivityPackageProtocol(
      onCheck: widget.onCheck,
      onComplete: widget.onComplete,
    );
    _viewType = 'activity-package-${_protocol.channel}';
    try {
      final uri = widget.presentation.validatedEntryUri(widget.apiBaseUrl);
      _frame = web.HTMLIFrameElement()
        ..src = uri.toString()
        ..title = 'Interactive learning activity'
        ..setAttribute('sandbox', 'allow-scripts')
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0';
      _messageListener = ((web.MessageEvent event) {
        // The sandbox has an opaque origin. Trust its exact window and the
        // unguessable channel, never an origin string or a claimed package ID.
        if (!_sameWindow(event.source, _frame.contentWindow) ||
            event.origin != 'null') {
          return;
        }
        final raw = event.data.dartify();
        if (raw is! Map) return;
        try {
          final message = Map<String, dynamic>.from(raw);
          if (_protocol.validEnvelope(message, ready: true)) {
            if (!_initialized) {
              _initialized = true;
              _timeout?.cancel();
              _send(_protocol.initialize(widget.presentation.payload));
              if (mounted) setState(() => _error = null);
            }
            return;
          }
          if (_initialized) unawaited(_handle(message));
        } on TypeError {
          // Ignore malformed messages without dispatching an authenticated action.
        }
      }).toJS;
      web.window.addEventListener('message', _messageListener);
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
      _timeout = Timer(const Duration(seconds: 20), () {
        if (mounted && !_initialized) {
          setState(
            () =>
                _error = 'This activity did not load. Close it and try again.',
          );
        }
      });
    } catch (error) {
      _error = error.toString();
    }
  }

  void _send(Map<String, dynamic> message) {
    // '*' is required for a sandboxed opaque target; no credentials are sent.
    _frame.contentWindow?.postMessage(message.jsify(), '*'.toJS);
  }

  Future<void> _handle(Map<String, dynamic> message) async {
    final wasComplete = _protocol.completed;
    final reply = await _protocol.handle(message);
    if (!mounted || reply == null) return;
    _send(reply);
    if (!wasComplete && _protocol.completed) widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error == null
      ? HtmlElementView(viewType: _viewType)
      : Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!),
          ),
        );
}
