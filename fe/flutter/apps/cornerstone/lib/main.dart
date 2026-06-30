import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/models.dart';
import 'services/api_service.dart';
import 'services/learning_material_print.dart';
import 'ui/icons/cornerstone_icons.dart';
import 'ui/theme/theme_controller.dart';

part 'app/cornerstone_app.dart';
part 'ui/screens/home/home_shell.dart';
part 'ui/screens/home/home_views.dart';
part 'ui/widgets/markdown_widgets.dart';
part 'ui/widgets/home/shell_widgets.dart';
part 'ui/widgets/home/activity_dialog.dart';
part 'ui/widgets/contract_chip_widgets.dart';
part 'ui/widgets/workspace/shared_widgets.dart';
part 'ui/widgets/workspace/owner_workspace_view.dart';
part 'ui/widgets/workspace/learner_workspace_view.dart';
part 'ui/widgets/workspace/learner_workspace_desktop.dart';
part 'ui/widgets/workspace/library_workspace_view.dart';
part 'ui/widgets/workspace/library_planning_desktop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = CornerstoneThemeController();
  await themeController.load();
  runApp(CornerstoneApp(themeController: themeController));
}
