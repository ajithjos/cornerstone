import 'dart:convert';

import 'package:cornerstone/main.dart';
import 'package:cornerstone/services/api_service.dart';
import 'package:cornerstone/ui/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _owner = {
  'user_id': 'owner',
  'username': 'owner',
  'display_name': 'Owner Test',
  'role': 'owner',
  'can_manage_team': true,
  'can_read_library': true,
  'can_view_all_learners': true,
  'can_open_developer_docs': false,
};

Map<String, Object> _learner(String id, String name) => {
  'learner_id': id,
  'display_name': name,
  'current_age': 8,
  'current_level': 'Foundation',
  'notes': '',
  'attention_state': 'needs_assignment',
  'attention_label': 'Ready to begin',
  'next_action_label': 'Choose a playbook',
  'review_due_count': 0,
  'progress_status_counts': <String, int>{},
  'stage_progress': <Object>[],
};

Map<String, Object> _learnerDetail(Map<String, Object> learner) => {
  'status': 'ok',
  'workspace_view': 'owner_support',
  'viewer_role': 'owner',
  'includes_adult_materials': true,
  'learner': learner,
  'assigned_journeys': <Object>[],
  'assigned_pathways': <Object>[],
  'sessions': <Object>[],
  'progress': <Object>[],
  'review_items': <Object>[],
  'practice_mastery': <Object>[],
  'workspace': {
    'attention_label': 'Ready to begin',
    'practice_lane': <Object>[],
    'recent_wins': <Object>[],
    'progress_snapshot': {
      'confirmed_count': 0,
      'ready_for_check_count': 0,
      'needs_practice_count': 0,
      'not_started_count': 0,
      'review_due_count': 0,
      'completed_session_count': 0,
      'pending_session_count': 0,
    },
  },
};

void main() {
  testWidgets(
    'owner inspects another learner without switching active identity',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final john = _learner('john', 'John Test');
      final christopher = _learner('christopher', 'Christopher Test');
      final requests = <http.Request>[];
      final session = {
        'status': 'ok',
        'authenticated': true,
        'authenticated_user': _owner,
        'active_user': _owner,
        'available_users': [_owner],
        'available_teams': <Object>[],
        'team': {
          'team_id': 'family',
          'display_name': 'Test Family',
          'description': '',
        },
      };
      final client = CornerstoneApiClient(
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          final Object body;
          if (path == '/api/v1/session' ||
              path == '/api/v1/session/active-user') {
            // Respond if the regression calls this endpoint, so the assertion
            // catches the identity mutation itself, not an incidental HTTP error.
            body = session;
          } else if (path == '/api/v1/dashboard') {
            body = {
              'learners': [john, christopher],
            };
          } else if (path == '/api/v1/library/workspace') {
            body = {
              'status': 'ok',
              'pathways': <Object>[],
              'materials': <Object>[],
            };
          } else if (path == '/api/v1/library/documents') {
            body = {'status': 'ok', 'documents': <Object>[]};
          } else if (path.startsWith('/api/v1/learners/john')) {
            body = _learnerDetail(john);
          } else if (path.startsWith('/api/v1/learners/christopher')) {
            body = _learnerDetail(christopher);
          } else {
            return http.Response('{"message":"Unexpected request"}', 404);
          }
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CornerstoneHomePage(
            apiClient: client,
            themeController: CornerstoneThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Learners').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('view-learner-christopher')),
        findsOneWidget,
      );
      final beforeSelection = requests.length;
      await tester.tap(find.byKey(const ValueKey('view-learner-christopher')));
      await tester.pumpAndSettle();
      final selectionRequests = requests.skip(beforeSelection).toList();
      expect(
        selectionRequests.map((request) => request.url.path),
        containsAll([
          '/api/v1/learners/christopher',
          '/api/v1/learners/christopher/workspace',
        ]),
      );
      expect(
        selectionRequests.every((request) => request.method == 'GET'),
        isTrue,
      );
      expect(
        requests.where(
          (request) => request.url.path == '/api/v1/session/active-user',
        ),
        isEmpty,
      );
      expect(find.byTooltip('Owner Test'), findsOneWidget);
      expect(find.text('Christopher Test'), findsNWidgets(2));
      expect(find.text('Assign a playbook'), findsOneWidget);

      await tester.tap(find.text('Open learning'));
      await tester.pumpAndSettle();
      expect(find.text('Viewing work for'), findsOneWidget);
      expect(find.text('Christopher Test'), findsWidgets);
      expect(find.byTooltip('Owner Test'), findsOneWidget);
      expect(requests.where((request) => request.method == 'POST'), isEmpty);
    },
  );
}
