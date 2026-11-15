import 'dart:convert';

import 'package:cornerstone/services/api_service.dart';
import 'package:cornerstone/ui/screens/written_arithmetic/written_arithmetic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _level = <String, dynamic>{
  'id': 'addition_2_carry',
  'title': 'Two-digit addition with carrying',
  'operation': 'addition',
  'instructions': 'Work from the ones. Write the carry above the next column.',
  'prerequisite': 'Know tens, ones, and addition facts.',
};

Map<String, dynamic> _cell({String? id, String text = '', int digits = 1}) => {
  'id': id,
  'text': text,
  'max_digits': digits,
};

Map<String, dynamic> _worksheet(Map<String, dynamic> request) => {
  'request': {...request, 'seed': 123456},
  'level': _level,
  'problems': <Map<String, dynamic>>[
    {
      'id': 'problem-1',
      'prompt': '55 + 68',
      'columns': 3,
      'rows': [
        {
          'label': 'Carry',
          'kind': 'annotation',
          'cells': [_cell(), _cell(id: 'carry', digits: 2), _cell()],
        },
        {
          'label': 'First number',
          'kind': 'operand',
          'cells': [_cell(), _cell(text: '5'), _cell(text: '5')],
        },
        {
          'label': '+',
          'kind': 'operand',
          'cells': [_cell(), _cell(text: '6'), _cell(text: '8')],
        },
        {
          'label': 'Answer',
          'kind': 'answer',
          'cells': [
            _cell(id: 'hundreds'),
            _cell(id: 'tens'),
            _cell(id: 'ones'),
          ],
        },
      ],
    },
  ],
};

class _Backend {
  _Backend({this.twoProblems = false});
  final bool twoProblems;
  final checks = <Map<String, dynamic>>[];
  int generated = 0;

  late final client = CornerstoneApiClient(
    baseUrl: 'https://cornerstone.test',
    client: MockClient((request) async {
      Object result;
      switch (request.url.path) {
        case '/api/v1/written-arithmetic/levels':
          result = {
            'levels': [_level],
          };
        case '/api/v1/written-arithmetic/generate':
          generated++;
          final sheet = _worksheet(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          if (twoProblems) {
            final problems = sheet['problems'] as List;
            final second =
                jsonDecode(jsonEncode(problems.first)) as Map<String, dynamic>;
            second['id'] = 'problem-2';
            for (final row in second['rows'] as List) {
              for (final cell in row['cells'] as List) {
                if (cell['id'] != null) cell['id'] = 'second-${cell['id']}';
              }
            }
            problems.add(second);
          }
          result = sheet;
        case '/api/v1/written-arithmetic/check':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          checks.add(body);
          result = {
            'correct_count': 0,
            'total_count': 4,
            'complete': body['finish'],
            'feedback': [
              {
                'cell_id':
                    (body['responses'] as List).any(
                      (response) => response['cell_id'] == 'second-ones',
                    )
                    ? 'second-ones'
                    : 'ones',
                'correct': false,
                'expected': '3',
                'explanation':
                    '5 + 8 = 13. Write 3 in the ones and carry 1 ten.',
              },
            ],
          };
        default:
          return http.Response(
            jsonEncode({'message': 'Unexpected route'}),
            404,
          );
      }
      return http.Response(jsonEncode(result), 200);
    }),
  );
}

Future<void> _mount(WidgetTester tester, _Backend backend) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WrittenArithmeticScreen(
          apiClient: backend.client,
          canPrintAnswers: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _show(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  double delta = 250,
}) async {
  await _show(tester, finder, delta: delta);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'assisted checking sends entered cells and renders backend correction',
    (tester) async {
      final backend = _Backend();
      await _mount(tester, backend);
      await _tap(tester, find.text('Create practice'));
      await _show(tester, find.byKey(const ValueKey('ones')));
      await tester.enterText(find.byKey(const ValueKey('ones')), '9');
      await _tap(tester, find.text('Check entered boxes'));

      expect(backend.checks.single['finish'], false);
      expect(backend.checks.single['responses'], [
        {'cell_id': 'ones', 'value': '9'},
      ]);
      expect((backend.checks.single['worksheet'] as Map)['seed'], 123456);
      expect(find.textContaining('5 + 8 = 13. Write 3'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('Submit assessment'), findsNothing);

      await _show(tester, find.byKey(const ValueKey('ones')), delta: -250);
      await tester.enterText(find.byKey(const ValueKey('ones')), '3');
      await tester.pump();
      expect(find.textContaining('5 + 8 = 13. Write 3'), findsNothing);
    },
  );

  testWidgets(
    'assessment only reveals corrections on submission and locks the attempt',
    (tester) async {
      final backend = _Backend();
      await _mount(tester, backend);
      await _tap(tester, find.text('Assisted practice').first);
      await _tap(tester, find.text('Assessment').last);
      await _tap(tester, find.text('Create practice'));
      expect(find.text('Check entered boxes'), findsNothing);
      expect(find.text('Check this exercise'), findsNothing);
      expect(find.textContaining('5 + 8 = 13.'), findsNothing);
      await _tap(tester, find.text('Submit assessment'));

      expect(backend.checks.single['finish'], true);
      expect((backend.checks.single['worksheet'] as Map)['mode'], 'assessment');
      expect((backend.checks.single['responses'] as List).length, 4);
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('ones'))).enabled,
        false,
      );
      expect(find.textContaining('0 of 4 boxes correct'), findsOneWidget);
      await _tap(tester, find.text('Create new practice'), delta: -250);
      expect(backend.generated, 2);
      await _show(tester, find.byKey(const ValueKey('ones')));
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('ones'))).enabled,
        true,
      );
      expect(find.textContaining('5 + 8 = 13.'), findsNothing);
    },
  );

  testWidgets(
    'per-exercise checking sends only its cells and keeps other feedback',
    (tester) async {
      final backend = _Backend(twoProblems: true);
      await _mount(tester, backend);
      await _tap(tester, find.text('Create practice'));
      await _show(tester, find.byKey(const ValueKey('ones')));
      await tester.enterText(find.byKey(const ValueKey('ones')), '9');
      await _show(tester, find.byKey(const ValueKey('second-ones')));
      await tester.enterText(find.byKey(const ValueKey('second-ones')), '8');
      await _tap(
        tester,
        find.byKey(const ValueKey('check-problem-1')),
        delta: -250,
      );
      expect(backend.checks.single['finish'], false);
      expect(backend.checks.single['responses'], [
        {'cell_id': 'ones', 'value': '9'},
      ]);
      await _tap(tester, find.byKey(const ValueKey('check-problem-2')));
      expect(backend.checks.last['responses'], [
        {'cell_id': 'second-ones', 'value': '8'},
      ]);
      await _show(
        tester,
        find.byKey(const ValueKey('check-problem-1')),
        delta: -250,
      );
      expect(find.textContaining('Answer, box 3: 5 + 8 = 13.'), findsWidgets);
      expect(find.byIcon(Icons.cancel), findsWidgets);
      final firstGrid = find.ancestor(
        of: find.byKey(const ValueKey('check-problem-1')),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: firstGrid, matching: find.byIcon(Icons.cancel)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'paper grid scrolls at narrow widths and accepts backend cell digit limits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = _Backend();
      await _mount(tester, backend);
      await _tap(tester, find.text('Create practice'));
      await _show(tester, find.byKey(const ValueKey('carry')));
      await tester.enterText(find.byKey(const ValueKey('carry')), '12');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('carry')))
            .controller!
            .text,
        '12',
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
