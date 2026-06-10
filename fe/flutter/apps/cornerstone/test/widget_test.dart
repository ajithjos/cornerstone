import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:cornerstone/main.dart';
import 'package:cornerstone/ui/theme/theme_controller.dart';

void main() {
  testWidgets('app shell builds', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CornerstoneApp(themeController: CornerstoneThemeController()),
    );

    expect(find.byType(CornerstoneApp), findsOneWidget);
  });
}
