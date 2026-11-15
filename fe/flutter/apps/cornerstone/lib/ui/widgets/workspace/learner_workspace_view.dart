part of '../../../main.dart';

/// The same focused learning surface is used by a child and by an adult viewing
/// that child's assigned work. Session choice and next actions come from Rust.
class LearnerWorkspaceView extends StatelessWidget {
  const LearnerWorkspaceView({
    super.key,
    required this.viewer,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
    required this.onStartReview,
    this.onSetReadinessOverride,
    this.onClearReadinessOverride,
  });

  final ViewerUser? viewer;
  final LearnerWorkspacePayload? workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;
  final Future<void> Function(ReviewItem reviewItem) onStartReview;
  final Future<void> Function(SessionMaterial material)? onSetReadinessOverride;
  final Future<void> Function(SessionMaterial material)?
  onClearReadinessOverride;

  @override
  Widget build(BuildContext context) {
    final data = workspace;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            viewer?.isLearner == true
                ? 'Your learner profile is not ready yet. Ask your parent or teacher to help.'
                : 'Select a learner to see the next lesson and assigned work.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _LearnerWorkContent(
      key: ValueKey(data.learner.learnerId),
      workspace: data,
      viewerCanReadLibrary: viewerCanReadLibrary,
      onOpenLibraryRoute: onOpenLibraryRoute,
      onStartActivity: onStartActivity,
      onStartReview: onStartReview,
      onSetReadinessOverride: onSetReadinessOverride,
      onClearReadinessOverride: onClearReadinessOverride,
    );
  }
}
