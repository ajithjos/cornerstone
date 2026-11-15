part of '../../../main.dart';

/// Selecting a learner changes the inspected record, never the signed-in user.
class _OwnerWorkspaceView extends StatelessWidget {
  const _OwnerWorkspaceView({
    required this.learners,
    required this.selectedLearnerId,
    required this.detail,
    required this.onSelectLearner,
    required this.onOpenLearning,
    required this.onOpenAssignment,
    required this.onOpenLibrary,
    required this.onStartReview,
  });
  final List<LearnerDashboard> learners;
  final String? selectedLearnerId;
  final LearnerDetailPayload? detail;
  final ValueChanged<String> onSelectLearner;
  final VoidCallback onOpenLearning;
  final ValueChanged<String> onOpenAssignment;
  final VoidCallback onOpenLibrary;
  final Future<void> Function(ReviewItem) onStartReview;

  Widget _learnerOverview(BuildContext context) {
    final data = detail;
    final theme = Theme.of(context);
    if (data == null) {
      return const _SurfaceCard(
        child: Text('Choose a learner to see the assigned work and progress.'),
      );
    }
    final snapshot = data.workspace.progressSnapshot;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  data.learner.displayName.substring(0, 1),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.learner.displayName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age ${data.learner.currentAge} · ${data.learner.currentLevel}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onOpenLearning,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Open learning'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Assign a playbook'),
              ),
            ],
          ),
          ...[
            const Divider(height: 40),
            Wrap(
              spacing: 28,
              runSpacing: 20,
              children: [
                _stat(
                  context,
                  '${snapshot.confirmedCount}',
                  'Skills confirmed',
                ),
                _stat(
                  context,
                  '${snapshot.readyForCheckCount}',
                  'Ready for checkpoint',
                ),
                _stat(
                  context,
                  '${data.reviewItems.where((item) => item.reviewStatus == ReviewStatus.due).length}',
                  'Reviews due',
                ),
              ],
            ),
          ],
          const Divider(height: 40),
          Text('Assigned playbooks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (data.assignedJourneys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No work assigned yet. Choose a playbook to get started.',
              ),
            ),
          for (final assignment in data.assignedJourneys)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(assignment.journey.title),
              subtitle: Text(
                assignment.journey.pathwayTitle ?? 'Learning playbook',
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => onOpenAssignment(assignment.assignment.assignmentId),
            ),
          if (data.reviewItems.isNotEmpty) ...[
            const Divider(height: 32),
            Text('Review', style: theme.textTheme.titleMedium),
            for (final item in data.reviewItems)
              ReviewItemActionTile(item: item, onStartReview: onStartReview),
          ],
          if (data.workspace.recentWins.isNotEmpty == true) ...[
            const Divider(height: 32),
            Text('Recent results', style: theme.textTheme.titleMedium),
            for (final win in data.workspace.recentWins.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(win.sessionTitle),
                subtitle: Text(win.scoreLabel),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 880;
      final roster = _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your learners',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final learner in learners)
              _LearnerCard(
                learner: learner,
                selected: learner.learnerId == selectedLearnerId,
                onTap: () => onSelectLearner(learner.learnerId),
              ),
            if (learners.isEmpty) const Text('No learners in this space yet.'),
          ],
        ),
      );
      return ListView(
        padding: EdgeInsets.all(wide ? 28 : 16),
        children: [
          Text('Learners', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'See where each child stands and help with the next step.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: roster),
                const SizedBox(width: 24),
                Expanded(child: _learnerOverview(context)),
              ],
            )
          else ...[
            roster,
            const SizedBox(height: 16),
            _learnerOverview(context),
          ],
        ],
      );
    },
  );
}
