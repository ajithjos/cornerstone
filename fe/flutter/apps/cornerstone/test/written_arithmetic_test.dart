import 'dart:convert';
import 'package:cornerstone/models/written_arithmetic.dart';
import 'package:cornerstone/services/api_service.dart';
import 'package:cornerstone/ui/screens/written_arithmetic/written_arithmetic_screen.dart';
import 'package:cornerstone/ui/widgets/activity_package/activity_package_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const level = {
  'id': 'addition_2_carry',
  'title': 'Column addition',
  'operation': 'addition',
  'instructions': 'Work from the ones.',
  'prerequisite': 'Know tens and ones.',
};
const digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets(
    'worksheet tool uses backend package descriptor and scopes free checks to generated sheet',
    (tester) async {
      final checks = <Map<String, dynamic>>[];
      final client = CornerstoneApiClient(
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/levels')) {
            return http.Response(
              jsonEncode({
                'levels': [level],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/generate')) {
            final config = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'request': {...config, 'seed': 42},
                'level': level,
                'presentation': {
                  'package_id': 'written-arithmetic',
                  'version': '7.2.0',
                  'entry_url':
                      '/api/v1/activity-packages/written-arithmetic/7.2.0/index.html?integrity=$digest',
                  'protocol_version': 1,
                  'payload': {
                    'worksheet': {'opaque': 'content'},
                    'mode': config['mode'],
                  },
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/check')) {
            checks.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode({
                'correct_count': 1,
                'total_count': 1,
                'complete': checks.last['finish'],
                'feedback': [],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WrittenArithmeticScreen(
            apiClient: client,
            canPrintAnswers: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create worksheet'));
      await tester.tap(find.text('Create worksheet'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Open practice'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open practice'));
      await tester.pumpAndSettle();
      final player = tester.widget<ActivityPackagePlayer>(
        find.byType(ActivityPackagePlayer),
      );
      expect(player.presentation.version, '7.2.0');
      expect(player.presentation.payload, {
        'worksheet': {'opaque': 'content'},
        'mode': 'assisted',
      });
      await player.onCheck([
        {'item_id': 'opaque-cell', 'value': '3'},
      ], 8);
      await player.onComplete([
        {'item_id': 'opaque-cell', 'value': '3'},
      ], 9);
      expect(checks.first['responses'], [
        {'cell_id': 'opaque-cell', 'value': '3'},
      ]);
      expect((checks.first['worksheet'] as Map)['seed'], 42);
      expect(checks.first['finish'], false);
      expect(checks.last['finish'], true);
      expect(find.textContaining('web browser'), findsOneWidget);
    },
  );

  test(
    'compact print format reaches backend without changing the worksheet',
    () async {
      Map<String, dynamic>? body;
      final client = CornerstoneApiClient(
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'html': '<html></html>'}), 200);
        }),
      );
      // Typed request models contain setup only; Flutter does not render arithmetic.
      final generatedClient = CornerstoneApiClient(
        baseUrl: 'https://school.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'request': {
                'level_id': 'a',
                'seed': 123,
                'question_count': 24,
                'mode': 'assisted',
              },
              'level': level,
              'presentation': {
                'package_id': 'written-arithmetic',
                'version': '1.0.0',
                'entry_url':
                    '/api/v1/activity-packages/written-arithmetic/1.0.0/index.html?integrity=$digest',
                'protocol_version': 1,
                'payload': {},
              },
            }),
            200,
          ),
        ),
      );
      final sheet = await generatedClient.generateWrittenWorksheet(
        const WrittenWorksheetRequest(
          levelId: 'a',
          questionCount: 24,
          mode: 'assisted',
        ),
      );
      await client.writtenWorksheetHtml(
        worksheet: sheet.request,
        includeAnswers: true,
        layout: 'compact',
      );
      expect(body!['layout'], 'compact');
      expect((body!['worksheet'] as Map)['seed'], 123);
      expect(body!['include_answers'], true);
    },
  );
}
