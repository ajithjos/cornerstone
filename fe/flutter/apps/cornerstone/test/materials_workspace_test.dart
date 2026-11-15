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
LibraryCatalogMaterial material(
  String id,
  String title, {
  String kind = 'worksheet',
  String audience = 'learner',
  bool extra = false,
}) => LibraryCatalogMaterial(
  materialId: id,
  title: title,
  kind: kind,
  audience: audience,
  estimatedMinutes: 10,
  skillIds: const [],
  executable: kind == 'worksheet',
  routePath: 'materials/$id',
  description: 'Short deliberate practice.',
  subjectTitle: 'Maths',
  areaTitle: 'Arithmetic',
  recommendedAge: 8,
  difficulty: 'foundation',
  assignable: audience == 'learner',
  assignmentTargets: [target('john', 'John')],
  activityLevelId: kind == 'worksheet' ? 'column_addition' : null,
  contextLabel: extra
      ? 'Extra practice in Written methods'
      : 'Written methods · First steps · Session 1',
  contexts: [
    LibraryMaterialContext(
      pathwayId: 'written',
      pathwayTitle: 'Written methods',
      playlistId: extra ? null : 'first',
      playlistTitle: extra ? null : 'First steps',
      sessionIndex: extra ? null : 1,
      sessionTitle: extra ? null : 'Understand place value',
    ),
  ],
);

LibraryWorkspacePayload libraryFixture() {
  final lesson = material('lesson', 'Place-value lesson', kind: 'lesson_note');
  final practice = material('column', 'Column addition');
  final check = material('check', 'Independent check', kind: 'quick_check');
  final sessionMaterials = [lesson, practice, check];
  final session = LibraryWorkspaceSession(
    sessionIndex: 1,
    authoredSessionId: 'place-value',
    dayOffset: 0,
    title: 'Understand place value',
    skillIds: const [],
    dominantKind: 'worksheet',
    requiresAdultSupport: false,
    materialCount: 3,
    estimatedMinutes: 25,
    liveMaterialCount: 1,
    materials: sessionMaterials,
    materialsByKind: [
      for (final item in sessionMaterials)
        WorkspaceMaterialKindGroup(
          kind: item.kind,
          audience: item.audience,
          materialCount: 1,
          materials: [item],
        ),
    ],
  );
  final playlist = LibraryWorkspacePlaylist(
    playlistId: 'first',
    title: 'First steps',
    description: 'Begin with place value, then practise.',
    recommendedAge: 8,
    recommendedLevel: 'Foundation',
    durationDays: 1,
    stageCount: 1,
    skillCount: 1,
    materialCount: 3,
    liveMaterialCount: 1,
    deliveryShape: PlaylistDeliveryShape(
      estimatedTotalMinutes: 25,
      lessonNoteCount: 1,
      teachingNoteCount: 0,
      worksheetCount: 1,
      drillCount: 0,
      quickCheckCount: 1,
      requiresAdultSupport: false,
    ),
    assignmentTargets: [target('john', 'John')],
    sessions: [session],
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
        extraPracticeGroups: const [
          LibraryPracticeGroup(
            title: 'Addition',
            materialIds: ['add2', 'add4'],
          ),
          LibraryPracticeGroup(title: 'Division', materialIds: ['divide']),
        ],
      ),
    ],
    materials: [
      ...sessionMaterials,
      material('add2', 'Two-digit addition', extra: true),
      material('add4', 'Four-digit addition', extra: true),
      material('divide', 'Division with remainders', extra: true),
    ],
  );
}

Future<void> mountLibrary(
  WidgetTester tester, {
  Size size = const Size(1500, 1000),
  ValueChanged<String>? onOpen,
  ValueChanged<LibraryCatalogMaterial>? onAssign,
  ValueChanged<LibraryWorkspacePlaylist>? onAssignPlaylist,
  String? requestedPreviewRoute,
  VoidCallback? onPreviewRequestHandled,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MaterialsWorkspaceView(
          library: libraryFixture(),
          requestedPreviewRoute: requestedPreviewRoute,
          onPreviewRequestHandled: onPreviewRequestHandled,
          documents: null,
          activeDocument: LibraryDocumentData(
            routePath: 'old/pathway',
            sourcePath: 'old.md',
            kind: 'pathway',
            documentId: 'old',
            title: 'Old pathway',
            subjectId: 'maths',
            areaId: 'arithmetic',
            pathwayId: 'old',
            description: '',
            body: 'Old pathway content',
          ),
          documentBusy: false,
          canAssign: true,
          onAssignMaterial: onAssign ?? (_) {},
          onAssignPlaylist: onAssignPlaylist ?? (_) {},
          onOpenDocument: onOpen ?? (_) {},
          onCreateWorksheet: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Library opens the map, then keeps session and material context',
    (tester) async {
      String? preview;
      String? assigned;
      String? playlist;
      await mountLibrary(
        tester,
        onOpen: (value) => preview = value,
        onAssign: (value) => assigned = value.materialId,
        onAssignPlaylist: (value) => playlist = value.playlistId,
      );
      expect(find.text('What will you teach next?'), findsOneWidget);
      expect(find.text('Old pathway'), findsNothing);
      expect(preview, isNull);
      await tester.tap(find.byKey(const ValueKey('explore-written')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-playlist-first')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-playlist-first')));
      expect(playlist, 'first');
      await tester.tap(find.byKey(const ValueKey('map-session-first-1')));
      await tester.pumpAndSettle();
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Practise'), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('material-row-column')));
      await tester.pumpAndSettle();
      expect(preview, 'materials/column');
      expect(
        find.widgetWithText(TextButton, 'Column addition'),
        findsOneWidget,
      );
      expect(find.text('Session 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assign-material-column')));
      expect(assigned, 'column');
      await tester.tap(find.text('Back to session'));
      await tester.pumpAndSettle();
      expect(find.text('Learn'), findsOneWidget);
    },
  );

  testWidgets(
    'Extra practice respects group and server order through preview and back',
    (tester) async {
      await mountLibrary(tester);
      await tester.tap(find.byKey(const ValueKey('explore-written')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Addition · 2 levels'));
      await tester.tap(find.text('Addition · 2 levels'));
      await tester.pumpAndSettle();
      expect(find.text('Division with remainders'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('material-row-add2'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('material-row-add4'))).dy,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('material-row-add2')));
      await tester.pumpAndSettle();
      expect(find.text('Extra practice'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Addition'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Two-digit addition'),
        findsOneWidget,
      );
      await tester.tap(find.text('Back to Addition'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('material-row-add2')), findsOneWidget);
      expect(find.byKey(const ValueKey('material-row-divide')), findsNothing);
    },
  );

  testWidgets('Find a material shows its explicit session context', (
    tester,
  ) async {
    await mountLibrary(tester);
    await tester.tap(find.text('Find a material'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'column');
    await tester.pumpAndSettle();
    expect(find.text('1 material'), findsOneWidget);
    expect(
      find.text('Written methods · First steps · Session 1'),
      findsOneWidget,
    );
    await tester.tap(find.text('Session 1 · First steps'));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-session-first-1')), findsOneWidget);
  });

  testWidgets(
    'Narrow learning map closes on selection and keeps selected place',
    (tester) async {
      await mountLibrary(tester, size: const Size(390, 844));
      await tester.tap(find.text('Learning map'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('map-pathway-written')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Learning sequence'), findsOneWidget);
      await tester.tap(find.text('Learning map'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-playlist-first')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Sessions in order'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Explicit lesson request opens the material at its session', (
    tester,
  ) async {
    var handled = false;
    String? opened;
    await mountLibrary(
      tester,
      requestedPreviewRoute: 'materials/lesson',
      onPreviewRequestHandled: () => handled = true,
      onOpen: (route) => opened = route,
    );
    expect(handled, isTrue);
    expect(opened, 'materials/lesson');
    expect(find.text('Back to session'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Place-value lesson'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back to session'));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
  });

  testWidgets('assignment asks for one student and returns explicit mode', (
    tester,
  ) async {
    AssignmentSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selection = await showDialog<AssignmentSelection>(
                  context: context,
                  builder: (_) => AssignMaterialDialog(
                    title: 'Column addition',
                    targets: [
                      target('john', 'John'),
                      target('mary', 'Mary', assigned: true),
                    ],
                    offerActivityMode: true,
                  ),
                );
              },
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
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('John').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assisted practice').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assessment').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    expect(selection!.learnerId, 'john');
    expect(selection!.activityMode, 'assessment');
  });

  test(
    'assignment API sends exactly one material source and preserves playlist support',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = CornerstoneApiClient(
        baseUrl: 'https://school.test',
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 200);
        }),
      );
      await client.createAssignment(
        learnerId: 'john',
        materialId: 'column',
        activityMode: 'assisted',
      );
      await client.createAssignment(
        learnerId: 'john',
        playlistId: 'number_sense',
      );
      expect(bodies.first, {
        'learner_id': 'john',
        'material_id': 'column',
        'activity_mode': 'assisted',
      });
      expect(bodies.last, {
        'learner_id': 'john',
        'playlist_id': 'number_sense',
      });
    },
  );
}
