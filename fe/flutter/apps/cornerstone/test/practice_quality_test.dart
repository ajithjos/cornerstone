import 'dart:convert';

import 'package:cornerstone/main.dart';
import 'package:cornerstone/models/models.dart';
import 'package:cornerstone/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _activityJson({
  String id = 'activity-1',
  String instructions = 'Answer each fact.',
  String runMode = 'practice',
}) => <String, dynamic>{
  'activity_instance_id': id,
  'session_id': 'session-1',
  'session_material_id': 'session-material-1',
  'material_id': 'multiplication-drill',
  'material_title': 'Multiplication practice',
  'runtime_id': 'arithmetic-fact-fluency-v1',
  'engine_id': 'deterministic-v1',
  'template_id': 'multiplication-tables-to-10',
  'instructions': instructions,
  'estimated_minutes': 5,
  'started_at': DateTime.now().toUtc().toIso8601String(),
  'run_status': 'in_progress',
  'run_mode': runMode,
  'scoring': <String, dynamic>{'target_accuracy': 0.9},
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'item_id': 'item-1',
      'content': '7 × 8',
      'response_kind': 'integer',
    },
  ],
};

Map<String, dynamic> _completeJson() => <String, dynamic>{
  'run_status': 'finished',
  'run_outcome': 'target_not_met',
  'run_outcome_label': 'Keep practising',
  'retry_available': true,
  'evidence': <String, dynamic>{
    'evidence_id': 'evidence-1',
    'score': 0,
    'max_score': 1,
    'duration_minutes': 1,
    'notes': '',
    'recorded_at': '2026-07-15T10:00:00Z',
  },
  'updated_progress': <Map<String, dynamic>>[
    <String, dynamic>{
      'skill_id': 'multiply-within-100',
      'skill_status': 'needs_practice',
      'score_average': 0,
      'last_score': 0,
      'total_evidence': 1,
      'last_evidence_at': '2026-07-15T10:00:00Z',
    },
  ],
  'activity_summary': <String, dynamic>{
    'attempted_count': 1,
    'correct_count': 0,
    'item_count': 1,
    'accuracy': 0,
    'completion_reason': 'completed_below_target',
    'started_at': '2026-07-15T09:59:50Z',
    'completed_at': '2026-07-15T10:00:00Z',
    'duration_seconds': 10,
    'weak_family_keys': <String>['table_7'],
    'corrections': <Map<String, dynamic>>[
      <String, dynamic>{
        'item_id': 'item-1',
        'content': '7 × 8',
        'submitted_response': '54',
        'expected_response': '56',
        'fact_key': '7x8',
        'family_keys': <String>['table_7', 'core_6_to_9'],
        'correction_cue': 'Seven groups of eight make 56.',
      },
    ],
  },
  'readiness': <String, dynamic>{
    'minimum_runs': 3,
    'recent_run_window': 5,
    'target_accuracy': 0.9,
    'consecutive_target_runs_required': 2,
    'target_correct_count': null,
    'minimum_distinct_items': 12,
    'minimum_family_count': 4,
    'max_duration_seconds': null,
    'override_applied': false,
    'override_reason': '',
    'ready_for_check': false,
    'run_count': 1,
    'recent_run_count': 1,
    'recent_average_accuracy': 0,
    'consecutive_target_run_count': 0,
    'best_correct_count': 0,
    'distinct_item_count': 1,
    'skill_status': 'needs_practice',
    'status_label': 'Needs practice',
    'detail_label': 'Build representative coverage before the check.',
  },
};

void main() {
  group('practice quality contracts', () {
    test('parses only the explicit status vocabularies', () {
      expect(SessionStatus.scheduled.label, 'Scheduled');
      expect(SessionStatus.active.label, 'In progress');
      expect(SessionStatus.completed.label, 'Finished');
      expect(SessionMaterialStatus.active.label, 'In progress');
      expect(
        SkillStatus.fromJson('ready_for_check'),
        SkillStatus.readyForCheck,
      );
      expect(ReviewStatus.fromJson('due'), ReviewStatus.due);
      expect(RunMode.fromJson('check'), RunMode.check);
      expect(RunMode.fromJson('review'), RunMode.review);
      expect(RunMode.fromJson('retry'), RunMode.retry);
      expect(
        () => SkillStatus.fromJson('secure'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SessionStatus.fromJson('pending'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses corrections from the activity summary and readiness', () {
      final response = CompleteActivityResponse.fromJson(_completeJson());

      expect(response.runStatus, RunStatus.finished);
      expect(response.runOutcome, RunOutcome.targetNotMet);
      expect(
        response.activitySummary.completionReason,
        'completed_below_target',
      );
      expect(response.activitySummary.weakFamilies, <String>['table_7']);
      expect(response.activitySummary.corrections.single.factKey, '7x8');
      expect(response.readiness?.skillStatus, SkillStatus.needsPractice);
      expect(response.readiness?.minimumFamilyCount, 4);
    });

    test('parses practice mastery and review actions', () {
      final mastery = PracticeMastery.fromJson(<String, dynamic>{
        'material_id': 'multiplication-drill',
        'material_title': 'Multiplication practice',
        'runtime_id': 'arithmetic-fact-fluency-v1',
        'skill_status': 'needs_practice',
        'review_status': 'due',
        'families': <Map<String, dynamic>>[
          <String, dynamic>{
            'family_key': 'table_7',
            'label': '7 times table',
            'attempted_count': 10,
            'correct_count': 8,
            'accuracy': 0.8,
            'last_seen_at': '2026-07-15T10:00:00Z',
          },
        ],
      });
      final review = ReviewItem.fromJson(<String, dynamic>{
        'review_item_id': 'review-1',
        'skill_ids': <String>['multiply-within-100'],
        'session_id': 'session-1',
        'session_material_id': 'session-material-1',
        'material_id': 'multiplication-drill',
        'evidence_material_id': 'multiplication-drill',
        'reason': 'Revisit the 7 times table.',
        'fact_focus': <String>['7x8'],
        'family_focus': <String>['table_7'],
        'due_date': '2026-07-15',
        'review_status': 'due',
        'action_label': 'Start review',
      });

      expect(mastery.skillStatus, SkillStatus.needsPractice);
      expect(mastery.reviewStatus, ReviewStatus.due);
      expect(mastery.families.single.familyKey, 'table_7');
      expect(review.evidenceMaterialId, 'multiplication-drill');
      expect(review.actionLabel, 'Start review');
    });

    test('uses the explicit retry and review start endpoints', () async {
      final requestedPaths = <String>[];
      final client = CornerstoneApiClient(
        baseUrl: 'https://cornerstone.test',
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          final runMode = request.url.path.contains('/review-items/')
              ? 'review'
              : 'retry';
          return http.Response(
            jsonEncode(<String, dynamic>{
              'activity': _activityJson(runMode: runMode),
            }),
            200,
          );
        }),
      );

      final retry = await client.retryActivity('activity-1');
      final review = await client.startReviewItem('review-1');

      expect(retry.runStatus, RunStatus.inProgress);
      expect(retry.runMode, RunMode.retry);
      expect(review.runMode, RunMode.review);
      expect(requestedPaths, <String>[
        '/api/v1/activity-instances/activity-1/retry',
        '/api/v1/review-items/review-1/start',
      ]);
    });

    test('sends the exact readiness override vocabulary', () async {
      Map<String, dynamic>? requestBody;
      final client = CornerstoneApiClient(
        baseUrl: 'https://cornerstone.test',
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{'status': 'ok'}),
            200,
          );
        }),
      );

      await client.setReadinessOverride(
        learnerId: 'learner-1',
        materialId: 'multiplication-drill',
        minimumRuns: 3,
        recentRunWindow: 5,
        targetAccuracy: 0.9,
        consecutiveTargetRunsRequired: 2,
        minimumDistinctItems: 12,
        minimumFamilyCount: 4,
        reason: 'Use a representative target.',
      );

      expect(requestBody, containsPair('consecutive_target_runs', 2));
      expect(requestBody, containsPair('minimum_distinct_items', 12));
      expect(requestBody, containsPair('minimum_family_count', 4));
      expect(requestBody, isNot(contains('consecutive_passes')));
    });
  });

  testWidgets('shows corrections and starts a missed-fact retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExecutableActivityPage(
          activity: ActivityInstance.fromJson(_activityJson()),
          onComplete: (_, _, _, _) async =>
              CompleteActivityResponse.fromJson(_completeJson()),
          onRetry: (_) async {
            retryCount += 1;
            return ActivityInstance.fromJson(
              _activityJson(
                id: 'activity-retry-1',
                instructions: 'Practise only the missed facts.',
              ),
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '54');
    await tester.tap(find.text('Submit activity'));
    await tester.pumpAndSettle();

    expect(find.text('Keep practising'), findsOneWidget);
    expect(find.text('Your answer: 54'), findsOneWidget);
    expect(find.text('Correct answer: 56'), findsOneWidget);
    expect(find.text('Seven groups of eight make 56.'), findsOneWidget);

    final retryButton = find.byKey(const ValueKey('practise-missed-facts'));
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(retryCount, 1);
    expect(find.text('Practise only the missed facts.'), findsOneWidget);
    expect(find.text('Submit activity'), findsOneWidget);
    expect(find.text('Corrections'), findsNothing);
  });

  testWidgets('renders mastery evidence and actionable review', (tester) async {
    var startedReview = false;
    final mastery = PracticeMastery.fromJson(<String, dynamic>{
      'material_id': 'multiplication-drill',
      'material_title': 'Multiplication practice',
      'runtime_id': 'arithmetic-fact-fluency-v1',
      'skill_status': 'needs_practice',
      'review_status': 'due',
      'families': <Map<String, dynamic>>[
        <String, dynamic>{
          'family_key': 'table_7',
          'label': '7 times table',
          'attempted_count': 10,
          'correct_count': 8,
          'accuracy': 0.8,
          'last_seen_at': '2026-07-15T10:00:00Z',
        },
      ],
    });
    final review = ReviewItem.fromJson(<String, dynamic>{
      'review_item_id': 'review-1',
      'skill_ids': <String>['multiply-within-100'],
      'session_id': 'session-1',
      'session_material_id': 'session-material-1',
      'material_id': 'multiplication-drill',
      'evidence_material_id': 'multiplication-drill',
      'reason': 'Revisit the 7 times table.',
      'fact_focus': <String>['7x8'],
      'family_focus': <String>['table_7'],
      'due_date': '2026-07-15',
      'review_status': 'due',
      'action_label': 'Start review',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PracticeMasteryPanel(
                  practiceMastery: <PracticeMastery>[mastery],
                ),
                ReviewItemActionTile(
                  item: review,
                  onStartReview: (_) async {
                    startedReview = true;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('7 times table'), findsOneWidget);
    expect(find.text('8/10 correct · 80%'), findsOneWidget);
    expect(find.text('Last practised 2026-07-15'), findsOneWidget);
    expect(find.text('Needs practice'), findsOneWidget);
    expect(find.text('Review due'), findsOneWidget);

    await tester.tap(find.text('Start review'));
    await tester.pump();
    expect(startedReview, isTrue);
  });
}
