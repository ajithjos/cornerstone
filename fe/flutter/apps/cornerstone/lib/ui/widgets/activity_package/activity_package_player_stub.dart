import 'package:flutter/material.dart';
import '../../../models/activity_presentation.dart';
import 'activity_package_protocol.dart';

class ActivityPackagePlayerView extends StatelessWidget {
  const ActivityPackagePlayerView({
    super.key,
    required this.presentation,
    required this.apiBaseUrl,
    required this.onCheck,
    required this.onComplete,
    this.onCompleted,
  });
  final ActivityPresentation presentation;
  final String apiBaseUrl;
  final ActivityPackageAction onCheck;
  final ActivityPackageAction onComplete;
  final VoidCallback? onCompleted;
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Open Cornerstone in a web browser to use this interactive activity.',
      ),
    ),
  );
}
