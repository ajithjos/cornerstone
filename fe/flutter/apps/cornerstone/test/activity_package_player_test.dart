import 'package:cornerstone/models/activity_presentation.dart';
import 'package:cornerstone/ui/widgets/activity_package/activity_package_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'packaged completion retains readiness and retries with the new instance',
    (tester) async {
      const descriptor = ActivityPresentation(
        packageId: 'numeric-questions',
        version: '1.0.0',
        entryUrl:
            '/api/v1/activity-packages/numeric-questions/1.0.0/index.html?integrity=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        protocolVersion: 1,
        payload: {},
      );
      var retries = 0;
      final retry = ActivityPackageRun(
        id: 'retry-instance',
        title: 'Missed items',
        presentation: descriptor,
        onCheck: (_, _) async => {},
        onComplete: (_, _) async => {},
      );
      final run = ActivityPackageRun(
        id: 'first-instance',
        title: 'Number facts',
        presentation: descriptor,
        onCheck: (_, _) async => {},
        onComplete: (_, _) async => {
          'run_outcome_label': 'Keep practising',
          'retry_available': true,
          'activity_summary': {
            'correct_count': 3,
            'item_count': 4,
            'duration_seconds': 12,
          },
          'readiness': {
            'status_label': 'Needs practice',
            'detail_label': 'Review the missed facts.',
          },
        },
        onRetry: () async {
          retries++;
          return retry;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityPackagePage(
            run: run,
            apiBaseUrl: 'https://school.test',
          ),
        ),
      );
      var player = tester.widget<ActivityPackagePlayer>(
        find.byType(ActivityPackagePlayer),
      );
      await player.onComplete([], 12);
      player.onCompleted!();
      await tester.pumpAndSettle();
      expect(find.textContaining('3/4 correct'), findsOneWidget);
      expect(
        find.text('Needs practice: Review the missed facts.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Practise missed items'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(find.text('Missed items'), findsOneWidget);
      expect(find.byKey(const ValueKey('retry-instance')), findsOneWidget);
      expect(find.text('Practise missed items'), findsNothing);
    },
  );
}
