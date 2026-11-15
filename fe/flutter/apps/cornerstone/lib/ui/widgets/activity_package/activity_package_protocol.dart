import 'dart:math';

typedef ActivityPackageAction =
    Future<Map<String, dynamic>> Function(
      List<Map<String, String>> responses,
      int durationSeconds,
    );

/// Authenticated actions remain in the host. Packages can submit only these
/// bounded messages for the activity instance captured by the callbacks.
class ActivityPackageProtocol {
  ActivityPackageProtocol({required this.onCheck, required this.onComplete})
    : channel = List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  static const name = 'cornerstone.activity';
  final String channel;
  final ActivityPackageAction onCheck;
  final ActivityPackageAction onComplete;
  final Set<String> _requestIds = {};
  bool _busy = false;
  bool completed = false;

  bool validEnvelope(Map<String, dynamic> message, {bool ready = false}) =>
      message['protocol'] == name &&
      message['version'] == 1 &&
      (ready ? message['type'] == 'ready' : message['channel'] == channel);

  Map<String, dynamic> initialize(
    Map<String, dynamic> payload, {
    Map<String, dynamic>? appearance,
  }) => {
    'protocol': name,
    'version': 1,
    'type': 'initialize',
    'channel': channel,
    'payload': payload,
    'appearance': ?appearance,
  };

  Map<String, dynamic> appearance(Map<String, dynamic> appearance) => {
    'protocol': name,
    'version': 1,
    'type': 'appearance',
    'channel': channel,
    'appearance': appearance,
  };

  Future<Map<String, dynamic>?> handle(Map<String, dynamic> message) async {
    if (!validEnvelope(message) || message['type'] != 'request') return null;
    final requestId = message['request_id'];
    if (requestId is! String ||
        requestId.isEmpty ||
        requestId.length > 128 ||
        _requestIds.contains(requestId)) {
      return null;
    }
    _requestIds.add(requestId);
    Map<String, dynamic> reply({Map<String, dynamic>? result, String? error}) =>
        {
          'protocol': name,
          'version': 1,
          'type': 'response',
          'channel': channel,
          'request_id': requestId,
          'ok': error == null,
          if (error == null) 'result': result else 'error': error,
        };
    if (_busy) return reply(error: 'Wait for the current check to finish.');
    if (completed) {
      return reply(error: 'This activity has already been submitted.');
    }
    final action = message['action'];
    if (action != 'check' && action != 'complete') {
      return reply(error: 'Unsupported activity action.');
    }
    final rawResponses = message['responses'];
    final duration = message['duration_seconds'] ?? 0;
    if (rawResponses is! List ||
        rawResponses.length > 5000 ||
        duration is! int ||
        duration < 0 ||
        duration > 86400) {
      return reply(error: 'Invalid activity responses.');
    }
    final responses = <Map<String, String>>[];
    final ids = <String>{};
    for (final raw in rawResponses) {
      if (raw is! Map || raw['item_id'] is! String || raw['value'] is! String) {
        return reply(error: 'Invalid activity response.');
      }
      final id = raw['item_id'] as String;
      final value = raw['value'] as String;
      if (id.isEmpty || id.length > 200 || value.length > 100 || !ids.add(id)) {
        return reply(error: 'Invalid activity response.');
      }
      responses.add({'item_id': id, 'value': value});
    }
    _busy = true;
    try {
      final result = await (action == 'check' ? onCheck : onComplete)(
        responses,
        duration,
      );
      if (action == 'complete') completed = true;
      return reply(result: result);
    } catch (error) {
      return reply(error: error.toString());
    } finally {
      _busy = false;
    }
  }
}
