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
  bool direct = false,
  bool startActivity = false,
  bool nextEnabled = true,
}) {
  final lesson = material('lesson');
  final practice = material('practice', live: true);
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
    materials: [lesson, practice, if (support) teaching],
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
  final sessions = [current, if (!direct) later];
  final continuation = LearnerContinueBlock(
    title: 'Continue lesson',
    description: 'A short focused session.',
    actionLabel: 'Open session',
    session: current,
  );
  final journey = LearnerJourney(
    playlistId: direct ? '' : 'column-playlist',
    playlistTitle: 'Legacy title should not appear',
    playlistDescription: '',
    title: direct ? 'Individual addition practice' : 'Column addition sequence',
    description: '',
    sourceKind: direct ? 'material' : 'playlist',
    sourceLabel: direct ? 'Individual material' : 'Playlist',
    sourceMaterialId: direct ? 'practice' : null,
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
      playlistId: direct ? '' : 'column-playlist',
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
    assignedJourneys: [assigned],
    assignedPathways: [
      LearnerAssignedPathway(
        pathwayId: 'written',
        pathwayTitle: 'Written arithmetic',
        pathwayDescription: '',
        playlistCount: direct ? 0 : 1,
        assignmentCount: 1,
        materialAssignmentCount: direct ? 1 : 0,
        summaryLabel: direct ? '1 individual material' : '1 playlist',
        totalSessionCount: sessions.length,
        completedSessionCount: 0,
        pendingSessionCount: sessions.length,
        assignments: [assigned],
      ),
    ],
    // A different aggregate order must not override the backend's current session.
    sessions: [if (!direct) later, current],
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
    'Continue follows the backend lesson step instead of the first session or executable',
    (tester) async {
      final launched = <String>[];
      await pumpWork(
        tester,
        fixture(),
        onStart: (item) => launched.add(item.sessionMaterialId),
      );
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Continue learning'), findsOneWidget);
      expect(
        find.text('Read the lesson before beginning practice.'),
        findsOneWidget,
      );
      expect(find.text('LESSON BODY: ten ones make one ten.'), findsNothing);
      expect(find.text('ADULT ONLY GUIDE'), findsNothing);
      expect(find.text('Legacy title should not appear'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('continue-learning')));
      await tester.pumpAndSettle();
      expect(launched, isEmpty);
      expect(
        find.textContaining('LESSON BODY: ten ones make one ten.'),
        findsOneWidget,
      );
      expect(find.text('Back to session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Continue launches only the explicit backend activity and honors its enabled state',
    (tester) async {
      final launched = <String>[];
      await pumpWork(
        tester,
        fixture(startActivity: true),
        onStart: (item) => launched.add(item.sessionMaterialId),
      );
      await tester.tap(find.byKey(const ValueKey('continue-learning')));
      expect(launched, ['practice']);
      await pumpWork(
        tester,
        fixture(startActivity: true, nextEnabled: false),
        onStart: (item) => launched.add(item.sessionMaterialId),
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('continue-learning')),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'learning outline preserves pathway assignment session connections on a narrow screen',
    (tester) async {
      await pumpWork(tester, fixture(), width: 390);
      expect(find.text('2. Next-day review'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Browse learning'));
      await tester.pumpAndSettle();
      final pathway = find.widgetWithText(ExpansionTile, 'Written arithmetic');
      await tester.ensureVisible(pathway);
      await tester.tap(pathway);
      await tester.pumpAndSettle();
      final session = find.text('2. Next-day review');
      await tester.ensureVisible(session);
      await tester.tap(session);
      await tester.pumpAndSettle();
      expect(find.text('Next-day review'), findsOneWidget);
      expect(find.text('Session 2'), findsOneWidget);
      expect(find.text('In this session'), findsOneWidget);
      expect(find.text('Close learning outline'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct material assignment keeps its source label and parent learner context',
    (tester) async {
      await pumpWork(tester, fixture(support: true, direct: true));
      expect(find.text('John’s work'), findsOneWidget);
      expect(
        find.text('1 individual material\n0/1 sessions finished'),
        findsOneWidget,
      );
      expect(find.textContaining('Individual material'), findsWidgets);
      expect(find.text('Parent guidance'), findsOneWidget);
      expect(find.text('Other sessions in this playlist'), findsNothing);
      expect(find.text('ADULT ONLY GUIDE'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
