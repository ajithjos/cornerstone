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

LearnerWorkspacePayload fixture({
  bool support = false,
  bool startActivity = false,
  bool nextEnabled = true,
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
    learningPathways: [
      LearnerPathwayMap.fromJson({
        'pathway_id': 'written',
        'title': 'Written arithmetic',
        'description': 'Written methods',
        'progress_label': '0 of 2 playbooks complete',
        'playbooks': [
          {
            'playlist_id': 'column-playlist',
            'title': journey.title,
            'description': '',
            'assignment_id': 'assignment',
            'can_open': true,
            'status': 'active',
            'progress_label': '0 of 1 checkpoints complete',
          },
          {
            'playlist_id': 'multiply',
            'title': 'Multiplication next',
            'description': '',
            'assignment_id': null,
            'can_open': false,
            'status': 'unassigned',
            'progress_label': 'Not assigned yet',
          },
        ],
      }),
    ],
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
      expect(find.text('Multiplication next'), findsOneWidget);
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsNothing);
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
      await tester.tap(find.text('Your pathways'));
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
}
