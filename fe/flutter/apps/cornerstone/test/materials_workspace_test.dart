import 'dart:convert';
import 'package:cornerstone/main.dart';
import 'package:cornerstone/models/models.dart';
import 'package:cornerstone/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PlaylistAssignmentTarget target(
  String id,
  String name, {
  bool assigned = false,
}) => PlaylistAssignmentTarget(
  learnerId: id,
  displayName: name,
  currentAge: 8,
  currentLevel: 'Foundation',
  recommended: false,
  statusLabel: 'Available',
  assignedHere: assigned,
  assignedAssignmentTitles: const [],
);

LibraryWorkspacePayload libraryFixture() {
  final materials = [
    LibraryWorkspaceMaterial(
      materialId: 'teach',
      title: 'Teaching place value',
      kind: 'teaching_note',
      audience: 'adult',
      estimatedMinutes: 5,
      skillIds: const [],
      executable: false,
      printable: true,
      routePath: 'materials/teach',
    ),
    LibraryWorkspaceMaterial(
      materialId: 'learn',
      title: 'Place-value lesson',
      kind: 'lesson_note',
      audience: 'learner',
      estimatedMinutes: 5,
      skillIds: const [],
      executable: false,
      printable: true,
      routePath: 'materials/learn',
    ),
    LibraryWorkspaceMaterial(
      materialId: 'practice',
      title: 'Column addition',
      kind: 'worksheet',
      audience: 'learner',
      estimatedMinutes: 5,
      skillIds: const [],
      executable: true,
      routePath: 'materials/practice',
      activityLevelId: 'addition_2_carry',
    ),
    LibraryWorkspaceMaterial(
      materialId: 'checkpoint',
      title: 'Independent check',
      kind: 'quick_check',
      audience: 'learner',
      estimatedMinutes: 5,
      skillIds: const [],
      executable: true,
      routePath: 'materials/checkpoint',
      checkpointPolicy: const CheckpointPolicy(
        questionCount: 6,
        targetAccuracy: 1,
      ),
    ),
  ];
  final playlist = LibraryWorkspacePlaylist(
    playlistId: 'first',
    title: 'First steps',
    description: 'Understand place value and column addition.',
    recommendedAge: 8,
    recommendedLevel: 'Foundation',
    durationDays: 1,
    stageCount: 1,
    skillCount: 1,
    materialCount: 4,
    liveMaterialCount: 2,
    deliveryShape: PlaylistDeliveryShape(
      estimatedTotalMinutes: 20,
      lessonNoteCount: 1,
      teachingNoteCount: 1,
      worksheetCount: 1,
      drillCount: 0,
      quickCheckCount: 1,
      requiresAdultSupport: true,
    ),
    assignmentTargets: [target('john', 'John')],
    sections: [
      for (final section in [
        ('teach', 'Teach'),
        ('learn', 'Learn'),
        ('practice', 'Practice'),
        ('checkpoint', 'Checkpoint'),
      ])
        PlaybookSection(
          sectionId: section.$1,
          title: section.$2,
          description: '${section.$2} guidance.',
          items: [PlaybookSectionItem(materialId: section.$1, sessionIndex: 1)],
        ),
    ],
    sessions: [
      LibraryWorkspaceSession(
        sessionIndex: 1,
        authoredSessionId: 'internal',
        dayOffset: 0,
        title: 'Internal delivery session',
        skillIds: const [],
        dominantKind: 'worksheet',
        requiresAdultSupport: true,
        materialCount: 4,
        estimatedMinutes: 20,
        liveMaterialCount: 2,
        materialsByKind: const [],
        materials: materials,
      ),
    ],
  );
  return LibraryWorkspacePayload(
    status: 'ok',
    pathways: [
      LibraryWorkspacePathway(
        pathwayId: 'written',
        title: 'Written methods',
        description: 'Learn clear column methods.',
        areaTitle: 'Arithmetic',
        recommendedAgeMin: 7,
        recommendedAgeMax: 10,
        stageCount: 1,
        playlistCount: 1,
        entryPoints: const [],
        playlists: [playlist],
      ),
    ],
  );
}

Future<void> mountLibrary(
  WidgetTester tester, {
  Size size = const Size(1500, 1000),
  ValueChanged<String>? onOpen,
  ValueChanged<LibraryWorkspacePlaylist>? onAssign,
  ValueChanged<String>? onPrint,
  ValueChanged<LibraryWorkspaceMaterial>? onPreview,
  String? requestedPreviewRoute,
  VoidCallback? onPreviewRequestHandled,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  LibraryDocumentData? document;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => MaterialsWorkspaceView(
            library: libraryFixture(),
            documents: null,
            activeDocument: document,
            documentBusy: false,
            canAssign: true,
            requestedPreviewRoute: requestedPreviewRoute,
            onPreviewRequestHandled: onPreviewRequestHandled,
            onAssignPlaylist: onAssign ?? (_) {},
            onCreateWorksheetForLevel: onPrint,
            onPreviewActivity: onPreview,
            onOpenDocument: (route) {
              onOpen?.call(route);
              setState(
                () => document = LibraryDocumentData(
                  routePath: route,
                  sourcePath: '$route.md',
                  kind: 'material',
                  documentId: route,
                  title: route,
                  subjectId: 'maths',
                  areaId: 'arithmetic',
                  pathwayId: 'written',
                  description: '',
                  body: 'Reading $route',
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openPlaybook(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('explore-written')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('playbook-first')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Owner playbook exposes the four contracted sections and assigns the whole playbook',
    (tester) async {
      String? assigned;
      await mountLibrary(tester, onAssign: (p) => assigned = p.playlistId);
      await openPlaybook(tester);
      expect(find.text('Teach'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Checkpoint'), findsOneWidget);
      expect(find.text('Reading materials/teach'), findsOneWidget);
      expect(find.text('Internal delivery session'), findsNothing);
      expect(find.text('Extra practice'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('assign-playlist-first')));
      expect(assigned, 'first');
      await tester.tap(find.byKey(const ValueKey('section-learn')));
      await tester.pumpAndSettle();
      expect(find.text('Reading materials/learn'), findsOneWidget);
    },
  );

  testWidgets(
    'Practice keeps fresh printing contextual and checkpoint states its conditions',
    (tester) async {
      String? printed;
      final previews = <String>[];
      await mountLibrary(
        tester,
        onPrint: (id) => printed = id,
        onPreview: (m) => previews.add(m.materialId),
      );
      await openPlaybook(tester);
      await tester.tap(find.byKey(const ValueKey('section-practice')));
      await tester.pumpAndSettle();
      expect(find.text('Column addition'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fresh-print-practice')));
      expect(printed, 'addition_2_carry');
      await tester.tap(find.text('Start practice'));
      expect(previews, ['practice']);
      await tester.tap(find.byKey(const ValueKey('section-checkpoint')));
      await tester.pumpAndSettle();
      expect(find.text('6 questions'), findsOneWidget);
      expect(find.text('100% to pass'), findsOneWidget);
      expect(find.text('No time limit'), findsOneWidget);
      await tester.tap(find.text('Take checkpoint'));
      expect(previews, ['practice', 'checkpoint']);
    },
  );

  testWidgets(
    'Search results open the correct section rather than a disconnected material',
    (tester) async {
      await mountLibrary(tester);
      await tester.tap(find.byTooltip('Search playbooks and materials'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'column');
      await tester.pumpAndSettle();
      expect(find.text('First steps · Practice'), findsOneWidget);
      await tester.tap(find.text('Column addition'));
      await tester.pumpAndSettle();
      expect(find.text('Reading materials/practice'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('section-practice')))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('assign-playlist-first')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Narrow map selects a playbook without overflow', (tester) async {
    await mountLibrary(tester, size: const Size(390, 844));
    await tester.tap(find.byTooltip('Learning map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-pathway-written')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byKey(const ValueKey('playbook-first')));
    await tester.pumpAndSettle();
    expect(find.text('Reading materials/teach'), findsOneWidget);
    for (final section in ['teach', 'learn', 'practice', 'checkpoint']) {
      expect(
        find.byKey(ValueKey('section-$section')).hitTestable(),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('section-checkpoint')));
    await tester.pumpAndSettle();
    expect(find.text('6 questions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A requested reference opens inside its owning playbook section',
    (tester) async {
      var handled = false;
      await mountLibrary(
        tester,
        requestedPreviewRoute: 'materials/learn',
        onPreviewRequestHandled: () => handled = true,
      );
      expect(handled, isTrue);
      expect(find.text('Reading materials/learn'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('section-learn')))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('assign-playlist-first')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Assignment requires an explicit eligible learner; mode belongs to the playbook',
    (tester) async {
      AssignmentSelection? selection;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    selection = await showDialog<AssignmentSelection>(
                      context: context,
                      builder: (_) => AssignMaterialDialog(
                        title: 'First steps',
                        targets: [
                          target('john', 'John'),
                          target('mary', 'Mary', assigned: true),
                        ],
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Assign'))
            .onPressed,
        isNull,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('John').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      expect(selection?.learnerId, 'john');
    },
  );

  test('Assignment API sends only the selected learner and playbook', () async {
    Map<String, dynamic>? body;
    final client = CornerstoneApiClient(
      baseUrl: 'https://school.test',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );
    await client.createAssignment(learnerId: 'john', playlistId: 'first');
    expect(body, {'learner_id': 'john', 'playlist_id': 'first'});
  });
}
