import 'dart:async';
import 'package:cornerstone/models/activity_presentation.dart';
import 'package:cornerstone/ui/widgets/activity_package/activity_package_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  ActivityPresentation presentation(String entry, {int protocol = 1}) =>
      ActivityPresentation(
        packageId: 'written-arithmetic',
        version: '1.0.0',
        entryUrl: entry,
        protocolVersion: protocol,
        payload: const {},
      );
  const path = '/api/v1/activity-packages/written-arithmetic/1.0.0/index.html';
  test('package URL must match the API origin, registered path and pinned digest', () {
    expect(
      presentation(
        '$path?integrity=$hash',
      ).validatedEntryUri('https://school.test').toString(),
      'https://school.test$path?integrity=$hash',
    );
    expect(
      presentation(
        '/api/v1/activity-packages/written-arithmetic/1.0.0/views/practice.html?integrity=$hash',
      ).validatedEntryUri('https://school.test').path,
      '/api/v1/activity-packages/written-arithmetic/1.0.0/views/practice.html',
    );
    for (final url in [
      'https://other.test$path?integrity=$hash',
      '/unrelated?integrity=$hash',
      path,
      '$path?integrity=$hash&next=x',
      '$path?integrity=no',
      '$path?integrity=$hash#fragment',
      '$path?integrity=$hash&integrity=$hash',
      '/api/v1/activity-packages/written-arithmetic/1.0.0/../1.0.0/index.html?integrity=$hash',
      '/api/v1/activity-packages/written-arithmetic/1.0.0/%2e%2e/index.html?integrity=$hash',
      '/api/v1/activity-packages/written-arithmetic/1.0.0/code.js?integrity=$hash',
    ]) {
      expect(
        () => presentation(url).validatedEntryUri('https://school.test'),
        throwsFormatException,
      );
    }
    expect(
      () => presentation(
        '$path?integrity=$hash',
        protocol: 2,
      ).validatedEntryUri('https://school.test'),
      throwsFormatException,
    );
  });
  test(
    'only authenticated channel, supported actions and valid responses reach callbacks',
    () async {
      var calls = 0;
      Future<Map<String, dynamic>> callback(
        List<Map<String, String>> responses,
        int duration,
      ) async {
        calls++;
        return {'received': responses, 'duration': duration};
      }

      final protocol = ActivityPackageProtocol(
        onCheck: callback,
        onComplete: callback,
      );
      final message = <String, dynamic>{
        'protocol': ActivityPackageProtocol.name,
        'version': 1,
        'type': 'request',
        'channel': protocol.channel,
        'request_id': 'one',
        'action': 'check',
        'responses': [
          {'item_id': 'cell', 'value': '3'},
        ],
        'duration_seconds': 8,
      };
      expect(await protocol.handle({...message, 'channel': 'wrong'}), isNull);
      expect(await protocol.handle({...message, 'version': 2}), isNull);
      expect(
        (await protocol.handle({
          ...message,
          'request_id': 'fetch',
          'action': 'fetch',
        }))!['ok'],
        false,
      );
      expect(
        (await protocol.handle({
          ...message,
          'request_id': 'bad',
          'responses': [
            {'item_id': 'x', 'value': '1'},
            {'item_id': 'x', 'value': '2'},
          ],
        }))!['ok'],
        false,
      );
      final result = await protocol.handle(message);
      expect(result!['ok'], true);
      expect((result['result'] as Map)['received'], [
        {'item_id': 'cell', 'value': '3'},
      ]);
      expect(await protocol.handle(message), isNull);
      expect(calls, 1);
      expect(protocol.initialize({'opaque': true})['payload'], {
        'opaque': true,
      });
      expect(protocol.channel.length, 48);
    },
  );
  test(
    'pending requests cannot race completion and successful completion locks the run',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      var calls = 0;
      final protocol = ActivityPackageProtocol(
        onCheck: (_, _) async {
          calls++;
          return {};
        },
        onComplete: (_, _) {
          calls++;
          return gate.future;
        },
      );
      Map<String, dynamic> request(String id, String action) => {
        'protocol': ActivityPackageProtocol.name,
        'version': 1,
        'type': 'request',
        'channel': protocol.channel,
        'request_id': id,
        'action': action,
        'responses': <dynamic>[],
      };
      final completing = protocol.handle(request('finish', 'complete'));
      expect((await protocol.handle(request('racing', 'check')))!['ok'], false);
      gate.complete({'done': true});
      expect((await completing)!['ok'], true);
      expect(
        (await protocol.handle(request('after', 'complete')))!['ok'],
        false,
      );
      expect(calls, 1);
    },
  );
}
