import 'package:cornerstone/main.dart';
import 'package:cornerstone/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionMaterial material(String id, {bool live = false, bool adult = false}) =>
    SessionMaterial(
      sessionMaterialId: id,
      title: adult
          ? 'Parent teaching guidance'
          : live
          ? 'Addition practice'
          : 'Place value lesson',
      materialId: id,
      kind: adult
          ? 'teaching_note'
          : live
          ? 'worksheet'
          : 'lesson_note',
      audience: adult ? 'adult' : 'learner',
      estimatedMinutes: 5,
      skillIds: const ['addition'],
      status: SessionMaterialStatus.scheduled,
      printable: true,
      documentBody: adult
          ? 'ADULT ONLY GUIDE'
          : live
          ? 'Activity instructions'
          : 'LESSON BODY: ten ones make one ten.',
      runtime: live
          ? SessionMaterialRuntimeSummary(
              runtimeId: 'test',
              engineId: 'test',
              templateId: 'test',
              executable: true,
            )
          : null,
    );

Map<String, dynamic> pathwayJson({
  String id = 'written',
  String title = 'Written arithmetic',
}) => {
  'pathway_id': id,
  'title': title,
  'description': 'Written methods',
  'progress_label': '0 of 2 playbooks complete',
  'status_label': 'Your learning',
  'playbook_count': 2,
  'assigned_playbook_count': 1,
  'completed_playbook_count': 0,
  'completion_percent': 0,
  'playbooks': [
    {
      'playlist_id': 'column-playlist',
      'title': 'Column addition sequence',
      'description': 'Learn a method that works for any number of digits.',
      'assignment_id': 'assignment',
      'can_open': true,
      'status': 'active',
      'progress_label': '0 of 1 checkpoints complete',
    },
    {
      'playlist_id': 'multiply',
      'title': 'Multiplication next',
      'description': 'Build on your addition skills.',
      'assignment_id': null,
      'can_open': false,
      'status': 'unassigned',
      'progress_label': 'Not assigned yet',
    },
  ],
};
LearnerPathwayCatalog testCatalog({
  String scope = 'assigned',
  String query = '',
  int page = 1,
  int total = 1,
}) => LearnerPathwayCatalog.fromJson({
  'scope': scope,
  'query': query,
  'page': page,
  'page_size': 12,
  'total_count': total,
  'all_count': total,
  'assigned_count': 1,
  'assigned_playbook_count': 1,
  'completed_playbook_count': 0,
  'items': [
    for (var i = (page - 1) * 12; i < page * 12 && i < total; i++)
      pathwayJson(
        id: i == 0 ? 'written' : 'path-$i',
        title: i == 0 ? 'Written arithmetic' : 'Pathway $i',
      ),
  ],
});
Future<LearnerPathwayMap> loadTestPathway(String id) async =>
    LearnerPathwayMap.fromJson(pathwayJson(id: id));
Future<LearnerPathwayCatalog> loadTestCatalog(
  String scope,
  String query,
  int page,
) async => testCatalog(scope: scope, query: query, page: page);

LearnerWorkspacePayload fixture({
  bool support = false,
  bool startActivity = false,
  bool nextEnabled = true,
  int catalogTotal = 1,
}) {
  final lesson = material('lesson');
  final practice = material('practice', live: true);
  final check = material('check', live: true);
  final teaching = material('teaching', adult: true);
  final current = SessionDetail(
    sessionId: 'current',
    title: 'Learn column addition',
    scheduledDate: '2026-11-15',
    status: SessionStatus.scheduled,
    dayOffset: 0,
    sequenceNumber: 1,
    dominantKind: 'lesson_note',
    requiresAdultSupport: support,
    estimatedMinutes: 10,
    liveMaterialCount: 1,
    learnerMaterialCount: 2,
    adultMaterialCount: support ? 1 : 0,
    notes: '',
    materialsByKind: const [],
    materials: [lesson, practice, check, if (support) teaching],
    primaryActivityMaterialId: practice.sessionMaterialId,
    nextStep: SessionNextStep(
      sessionMaterialId: startActivity
          ? practice.sessionMaterialId
          : lesson.sessionMaterialId,
      title: startActivity ? practice.title : lesson.title,
      instruction: startActivity
          ? 'Start your assigned calculation.'
          : 'Read the lesson before beginning practice.',
      actionLabel: startActivity
          ? 'Begin assigned practice'
          : 'Open assigned lesson',
      actionKind: startActivity ? 'start_activity' : 'open_material',
      enabled: nextEnabled,
    ),
  );
  final later = SessionDetail(
    sessionId: 'later',
    title: 'Next-day review',
    scheduledDate: '2026-11-16',
    status: SessionStatus.scheduled,
    dayOffset: 1,
    sequenceNumber: 2,
    dominantKind: 'worksheet',
    requiresAdultSupport: false,
    estimatedMinutes: 5,
    liveMaterialCount: 0,
    learnerMaterialCount: 1,
    adultMaterialCount: 0,
    notes: '',
    materialsByKind: const [],
    materials: [material('review')],
  );
  final sessions = [current, later];
  final continuation = LearnerContinueBlock(
    title: 'Continue lesson',
    description: 'A short focused session.',
    actionLabel: 'Open session',
    session: current,
  );
  final journey = LearnerJourney(
    playlistId: 'column-playlist',
    playlistTitle: 'Legacy title should not appear',
    playlistDescription: '',
    title: 'Column addition sequence',
    description: '',
    sourceLabel: 'Playbook',
    recommendedAge: 7,
    recommendedLevel: 'Foundation',
    durationDays: 2,
    totalSessionCount: sessions.length,
    completedSessionCount: 0,
    pendingSessionCount: sessions.length,
    totalMaterialCount: 3,
    liveMaterialCount: 1,
    pathwayId: 'written',
    pathwayTitle: 'Written arithmetic',
    nextSessionId: 'current',
  );
  final assigned = LearnerAssignedJourney(
    assignment: AssignmentSummary(
      assignmentId: 'assignment',
      playlistId: 'column-playlist',
      title: journey.title,
      startDate: '2026-11-15',
      endDate: '2026-11-16',
      status: 'active',
      totalSessions: sessions.length,
      completedSessions: 0,
      completionPercent: 0,
    ),
    journey: journey,
    sessions: sessions,
    sections: [
      if (support)
        PlaybookSection(
          sectionId: 'teach',
          title: 'Teach',
          description: 'Teaching approach and corrections.',
          items: const [
            PlaybookSectionItem(
              materialId: 'teaching',
              sessionIndex: 1,
              sessionId: 'current',
              sessionMaterialId: 'teaching',
            ),
          ],
        ),
      PlaybookSection(
        sectionId: 'learn',
        title: 'Learn',
        description: 'Study the explanation and worked examples.',
        items: const [
          PlaybookSectionItem(
            materialId: 'lesson',
            sessionIndex: 1,
            sessionId: 'current',
            sessionMaterialId: 'lesson',
          ),
        ],
      ),
      PlaybookSection(
        sectionId: 'practice',
        title: 'Practice',
        description: 'Generate fresh questions as often as you need.',
        items: const [
          PlaybookSectionItem(
            materialId: 'practice',
            sessionIndex: 1,
            sessionId: 'current',
            sessionMaterialId: 'practice',
          ),
        ],
      ),
      PlaybookSection(
        sectionId: 'checkpoint',
        title: 'Checkpoint',
        description: 'Work independently to check your understanding.',
        items: const [
          PlaybookSectionItem(
            materialId: 'check',
            sessionIndex: 1,
            sessionId: 'current',
            sessionMaterialId: 'check',
          ),
        ],
      ),
    ],
    currentSessionId: 'current',
    continueBlock: continuation,
  );
  return LearnerWorkspacePayload(
    status: 'ok',
    workspaceView: support ? 'owner_support' : 'learner',
    viewerRole: support ? 'owner' : 'learner',
    includesAdultMaterials: support,
    learner: LearnerSummary(
      learnerId: 'john',
      displayName: 'John',
      currentAge: 7,
      currentLevel: 'Foundation',
      notes: '',
    ),
    pathwayCatalog: testCatalog(
      total: catalogTotal,
      scope: catalogTotal > 1 ? 'all' : 'assigned',
    ),
    assignedJourneys: [assigned],
    assignedPathways: [
      LearnerAssignedPathway(
        pathwayId: 'written',
        pathwayTitle: 'Written arithmetic',
        pathwayDescription: '',
        playlistCount: 1,
        assignmentCount: 1,
        summaryLabel: '1 playbook',
        totalSessionCount: sessions.length,
        completedSessionCount: 0,
        pendingSessionCount: sessions.length,
        assignments: [assigned],
      ),
    ],
    // A different aggregate order must not override the backend's current session.
    sessions: [later, current],
    progress: const [],
    reviewItems: const [],
    practiceMastery: const [],
    workspace: LearnerWorkspace(
      attentionLabel: 'Continue learning',
      continueBlock: continuation,
      practiceLane: const [],
      recentWins: const [],
      progressSnapshot: LearnerProgressSnapshot(
        confirmedCount: 0,
        readyForCheckCount: 0,
        needsPracticeCount: 0,
        notStartedCount: 1,
        reviewDueCount: 0,
        completedSessionCount: 0,
        pendingSessionCount: sessions.length,
      ),
    ),
  );
}

Future<void> pumpWork(
  WidgetTester tester,
  LearnerWorkspacePayload data, {
  double width = 1280,
  void Function(SessionMaterial)? onStart,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LearnerWorkspaceView(
          viewer: null,
          workspace: data,
          onLoadPathways: loadTestCatalog,
          onLoadPathway: loadTestPathway,
          viewerCanReadLibrary: false,
          onOpenLibraryRoute: (_) {},
          onStartActivity: (_, material) async {
            onStart?.call(material);
          },
          onStartReview: (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Assigned playbook opens Learn with its printable explanation, no internal session tree',
    (tester) async {
      await pumpWork(tester, fixture());
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Your pathways'), findsOneWidget);
      expect(find.text('Multiplication next'), findsNothing);
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pathway-written')));
      await tester.pumpAndSettle();
      expect(find.text('Multiplication next'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('pathway-playbook-column-playlist')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Checkpoint'), findsOneWidget);
      expect(find.text('Teach'), findsNothing);
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsOneWidget);
      expect(find.text('ADULT ONLY GUIDE'), findsNothing);
      expect(find.text('Next-day review'), findsNothing);
      expect(find.text('Legacy title should not appear'), findsNothing);
    },
  );

  testWidgets(
    'Practice uses the backend section refs even when aggregate session order differs',
    (tester) async {
      final launched = <String>[];
      await pumpWork(
        tester,
        fixture(),
        onStart: (m) => launched.add(m.sessionMaterialId),
      );
      await tester.tap(find.byKey(const ValueKey('pathway-written')));
      await tester.pumpAndSettle();
      expect(find.text('Multiplication next'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('pathway-playbook-column-playlist')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-practice')));
      await tester.pumpAndSettle();
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('start-practice')));
      expect(launched, ['practice']);
      await tester.tap(find.byKey(const ValueKey('section-checkpoint')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-check')));
      expect(launched, ['practice', 'check']);
    },
  );

  testWidgets(
    'Owner Teach remains available while moving between practice and explanation',
    (tester) async {
      await pumpWork(tester, fixture(support: true));
      await tester.tap(find.byKey(const ValueKey('pathway-written')));
      await tester.pumpAndSettle();
      expect(find.text('Multiplication next'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('pathway-playbook-column-playlist')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teach'), findsOneWidget);
      expect(find.text('ADULT ONLY GUIDE'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('section-practice')));
      await tester.pumpAndSettle();
      expect(find.text('ADULT ONLY GUIDE'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('section-teach')));
      await tester.pumpAndSettle();
      expect(find.text('ADULT ONLY GUIDE'), findsOneWidget);
      expect(find.text('Viewing learner work · owner profile'), findsOneWidget);
    },
  );

  testWidgets(
    'Narrow learner flow keeps the three sections readable and returns to assigned work',
    (tester) async {
      await pumpWork(tester, fixture(), width: 390);
      await tester.tap(find.byKey(const ValueKey('continue-learning')));
      await tester.pumpAndSettle();
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsOneWidget);
      for (final section in ['learn', 'practice', 'checkpoint']) {
        expect(
          find.byKey(ValueKey('section-$section')).hitTestable(),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('section-checkpoint')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('start-check')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('learning-home')));
      await tester.pumpAndSettle();
      expect(find.text('Your pathways'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Returning from an activity restores the selected playbook and Practice section',
    (tester) async {
      final bucket = PageStorageBucket();
      final data = fixture();
      var visible = true;
      var catalogRefreshes = 0;
      late StateSetter redraw;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: StatefulBuilder(
                builder: (context, setState) {
                  redraw = setState;
                  return visible
                      ? LearnerWorkspaceView(
                          viewer: null,
                          workspace: data,
                          onLoadPathways: (scope, query, page) async {
                            catalogRefreshes++;
                            return testCatalog(
                              scope: scope,
                              query: query,
                              page: page,
                            );
                          },
                          onLoadPathway: loadTestPathway,
                          viewerCanReadLibrary: false,
                          onOpenLibraryRoute: (_) {},
                          onStartActivity: (_, _) async {},
                          onStartReview: (_) async {},
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('continue-learning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-practice')));
      await tester.pumpAndSettle();
      redraw(() => visible = false);
      await tester.pumpAndSettle();
      redraw(() => visible = true);
      await tester.pumpAndSettle();
      expect(catalogRefreshes, 1);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('section-practice')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const ValueKey('start-practice')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pathway-playbook-column-playlist')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'A hundred pathways stay paged and retain home position after exploring',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearnerWorkspaceView(
              viewer: null,
              workspace: fixture(catalogTotal: 100),
              viewerCanReadLibrary: false,
              onOpenLibraryRoute: (_) {},
              onStartActivity: (_, _) async {},
              onStartReview: (_) async {},
              onLoadPathways: (scope, query, page) async {
                requests.add(page);
                return testCatalog(
                  scope: scope,
                  query: query,
                  page: page,
                  total: 100,
                );
              },
              onLoadPathway: loadTestPathway,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pathway-path-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('pathway-path-12')), findsNothing);
      await tester.scrollUntilVisible(
        find.byTooltip('Next pathways'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next pathways'));
      await tester.pumpAndSettle();
      expect(requests, [2]);
      expect(find.text('Page 2 of 9 · 100 pathways'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('pathway-path-12')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pathway-path-12')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('learning-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learning-home')));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 9 · 100 pathways'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
