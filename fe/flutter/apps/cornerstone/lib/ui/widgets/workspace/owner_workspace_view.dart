part of '../../../main.dart';

class _OwnerWorkspaceView extends StatelessWidget {
  const _OwnerWorkspaceView({
    required this.viewer,
    required this.learners,
    required this.owners,
    required this.selectedLearnerId,
    required this.detail,
    required this.libraryWorkspace,
    required this.currentActionSession,
    required this.scoreController,
    required this.maxScoreController,
    required this.durationController,
    required this.notesController,
    required this.onSelectLearner,
    required this.onCreateAssignment,
    required this.onOpenLibraryRoute,
    required this.onOpenLibraryWorkspace,
    required this.onRecordSession,
    required this.onStartActivity,
  });

  final ViewerUser? viewer;
  final List<LearnerDashboard> learners;
  final List<ViewerUser> owners;
  final String? selectedLearnerId;
  final LearnerDetailPayload? detail;
  final LibraryWorkspacePayload libraryWorkspace;
  final SessionDetail? currentActionSession;
  final TextEditingController scoreController;
  final TextEditingController maxScoreController;
  final TextEditingController durationController;
  final TextEditingController notesController;
  final ValueChanged<String> onSelectLearner;
  final Future<void> Function(String learnerId, String playlistId)
  onCreateAssignment;
  final ValueChanged<String> onOpenLibraryRoute;
  final VoidCallback onOpenLibraryWorkspace;
  final VoidCallback onRecordSession;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalReviewItems = learners.fold<int>(
      0,
      (count, learner) => count + learner.reviewItemCount,
    );
    final activeSessionCount = learners
        .where((learner) => learner.todaySession != null)
        .length;
    final selectedDetail = detail;
    final assignedJourneys =
      selectedDetail?.assignedJourneys ?? const <LearnerAssignedJourney>[];
    final assignedPathways =
      selectedDetail?.assignedPathways ?? const <LearnerAssignedPathway>[];
    final singleAssignedJourney =
      assignedJourneys.length == 1 ? assignedJourneys.first : null;
    final journey = singleAssignedJourney?.journey ?? selectedDetail?.journey;
    final workspace = selectedDetail?.workspace;
    final continueBlock = workspace?.continueBlock;
    final recentWins = workspace?.recentWins ?? const <LearnerRecentWin>[];
    final assignedPathwayCount = assignedPathways.length;
    SessionDetail? activeSession;
    activeSession = continueBlock?.session;
    if (activeSession == null && selectedDetail != null) {
      for (final session in selectedDetail.sessions) {
        if (session.status != 'completed') {
          activeSession = session;
          break;
        }
      }
    }
    activeSession ??= currentActionSession;
    final learnerFacingGroups =
        activeSession?.materialsByKind
            .where((group) => group.audience == 'learner')
            .toList(growable: false) ??
        const <SessionMaterialKindGroup>[];
    final adultFacingGroups =
        activeSession?.materialsByKind
            .where((group) => group.audience == 'adult')
            .toList(growable: false) ??
        const <SessionMaterialKindGroup>[];
    final currentStanding =
        activeSession?.sequenceNumber ??
        (journey != null && journey.totalSessionCount > 0
            ? journey.completedSessionCount + 1
            : null);
    final journeyProgress = journey == null || journey.totalSessionCount == 0
        ? null
        : (journey.completedSessionCount / journey.totalSessionCount).clamp(
            0.0,
            1.0,
          );
    final activeMaterials =
        activeSession?.materials
            .where((material) => material.isExecutable)
            .toList(growable: false) ??
        const <SessionMaterial>[];
    final selectedProgressCounts = <String, int>{};
    if (selectedDetail != null) {
      for (final state in selectedDetail.progress) {
        selectedProgressCounts.update(
          state.status,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final selectedSecureCount = selectedProgressCounts['secure'] ?? 0;
    final selectedDevelopingCount = selectedProgressCounts['developing'] ?? 0;
    final selectedNotStartedCount = selectedProgressCounts['not_started'] ?? 0;
    final selectedReviewCount = selectedDetail?.reviewItems.length ?? 0;

    Widget buildSelectionPanel() {
      if (selectedDetail == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 54,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose a learner from the roster.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final hasLearnerItems = learnerFacingGroups.isNotEmpty;
      final hasTeacherNotes = adultFacingGroups.isNotEmpty;
      final tabPanelHeight = !hasLearnerItems && !hasTeacherNotes
          ? 150.0
          : hasLearnerItems && hasTeacherNotes
          ? 400.0
          : 250.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDetail.learner.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PillBadge(
                          text: selectedDetail.learner.currentLevel,
                          color: theme.colorScheme.secondaryContainer,
                          textColor: theme.colorScheme.onSecondaryContainer,
                        ),
                        _PillBadge(
                          text: 'Age ${selectedDetail.learner.currentAge}',
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          textColor: theme.colorScheme.primary,
                        ),
                        if ((workspace?.attentionLabel ?? '').isNotEmpty)
                          _PillBadge(
                            text: workspace!.attentionLabel,
                            color: theme.colorScheme.surfaceContainerHighest,
                            textColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        if (assignedJourneys.isNotEmpty)
                          _PillBadge(
                            text: '${assignedJourneys.length} playlists',
                            color: theme.colorScheme.tertiaryContainer,
                            textColor: theme.colorScheme.onTertiaryContainer,
                          ),
                        if (assignedPathwayCount > 0)
                          _PillBadge(
                            text: '$assignedPathwayCount pathways',
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            textColor: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Band(
            title: 'Assigned pathways',
            child: assignedJourneys.isEmpty && journey == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No pathways are assigned to this learner yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignedPathwayCount > 1
                            ? 'All assigned playlists are grouped under their pathway so you can see exactly where each route sits.'
                            : 'This pathway shows the playlists currently assigned to the learner.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...assignedPathways.expand((assignedPathway) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.62,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignedPathway.pathwayTitle,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  if (assignedPathway.pathwayDescription.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      assignedPathway.pathwayDescription,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _PillBadge(
                                        text: '${assignedPathway.playlistCount} playlists',
                                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                        textColor: theme.colorScheme.primary,
                                      ),
                                      _PillBadge(
                                        text: '${assignedPathway.totalSessionCount} sessions',
                                        color: theme.colorScheme.secondaryContainer,
                                        textColor: theme.colorScheme.onSecondaryContainer,
                                      ),
                                      _PillBadge(
                                        text: '${assignedPathway.pendingSessionCount} pending',
                                        color: theme.colorScheme.tertiaryContainer,
                                        textColor: theme.colorScheme.onTertiaryContainer,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...assignedPathway.assignedPlaylists.map((assignedJourney) {
                                    final assignedJourneyInfo = assignedJourney.journey;
                                    final currentJourneySession =
                                        assignedJourney.continueBlock?.session ??
                                        assignedJourney.sessions
                                            .where((session) => session.status != 'completed')
                                            .cast<SessionDetail?>()
                                            .firstWhere((_) => true, orElse: () => assignedJourney.sessions.isEmpty ? null : assignedJourney.sessions.first);
                                    final currentJourneyStanding =
                                        currentJourneySession?.sequenceNumber ??
                                        (assignedJourneyInfo.totalSessionCount > 0
                                            ? (assignedJourneyInfo.completedSessionCount + 1)
                                                .clamp(1, assignedJourneyInfo.totalSessionCount)
                                            : null);
                                    final assignedJourneyProgress =
                                        assignedJourneyInfo.totalSessionCount == 0
                                        ? null
                                        : (assignedJourneyInfo.completedSessionCount /
                                                assignedJourneyInfo.totalSessionCount)
                                            .clamp(0.0, 1.0);
                                    return Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assignedJourneyInfo.playlistTitle,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            assignedJourneyInfo.playlistDescription,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _PillBadge(
                                                text: 'status:${assignedJourney.assignment.status}',
                                                color: theme.colorScheme.secondaryContainer,
                                                textColor: theme.colorScheme.onSecondaryContainer,
                                              ),
                                              if (currentJourneyStanding != null)
                                                _PillBadge(
                                                  text: 'Current session: $currentJourneyStanding/${assignedJourneyInfo.totalSessionCount}',
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                                  textColor: theme.colorScheme.primary,
                                                ),
                                              _PillBadge(
                                                text: 'Completed: ${assignedJourneyInfo.completedSessionCount}',
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                textColor: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              _PillBadge(
                                                text: 'Pending: ${assignedJourneyInfo.pendingSessionCount}',
                                                color: theme.colorScheme.tertiaryContainer,
                                                textColor: theme.colorScheme.onTertiaryContainer,
                                              ),
                                            ],
                                          ),
                                          if (assignedJourneyProgress != null) ...[
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                minHeight: 10,
                                                value: assignedJourneyProgress,
                                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ];
                      }),
                      if (assignedJourneys.isEmpty && journey != null) ...[
                        if (journey.pathwayTitle != null)
                          Text(
                            journey.pathwayTitle!,
                            style: theme.textTheme.titleLarge,
                          ),
                        if ((journey.pathwayDescription ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            journey.pathwayDescription!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          journey.playlistTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          journey.playlistDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (currentStanding != null)
                              _PillBadge(
                                text:
                                    'Current session: $currentStanding/${journey.totalSessionCount}',
                                color: theme.colorScheme.secondaryContainer,
                                textColor: theme.colorScheme.onSecondaryContainer,
                              ),
                            _PillBadge(
                              text: 'Completed: ${journey.completedSessionCount}',
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              textColor: theme.colorScheme.primary,
                            ),
                            _PillBadge(
                              text: 'Pending: ${journey.pendingSessionCount}',
                              color: theme.colorScheme.tertiaryContainer,
                              textColor: theme.colorScheme.onTertiaryContainer,
                            ),
                          ],
                        ),
                        if (journeyProgress != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: journeyProgress,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          _Band(
            title: 'Current session',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (continueBlock != null) ...[
                  Text(continueBlock.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    continueBlock.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (activeSession != null) ...[
                  Text(activeSession.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PillBadge(
                        text: 'Session ${activeSession.sequenceNumber ?? '-'}',
                        color: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                      if (activeSession.estimatedMinutes > 0)
                        _PillBadge(
                          text: '${activeSession.estimatedMinutes} min',
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          textColor: theme.colorScheme.primary,
                        ),
                      if (activeSession.requiresAdultSupport)
                        _PillBadge(
                          text: 'Adult-guided',
                          color: theme.colorScheme.tertiaryContainer,
                          textColor: theme.colorScheme.onTertiaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: [
                            Tab(
                              text:
                                  'Learner items (${learnerFacingGroups.length})',
                            ),
                            Tab(
                              text:
                                  'Teacher notes (${adultFacingGroups.length})',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: tabPanelHeight,
                          child: TabBarView(
                            children: [
                              hasLearnerItems
                                  ? SingleChildScrollView(
                                      child: _SessionWorkspaceAudiencePanel(
                                        title: 'Learner items',
                                        description:
                                            'Everything the learner needs for this session.',
                                        emptyState:
                                            'No learner-facing materials are attached to this session yet.',
                                        icon: Icons.school_rounded,
                                        groups: learnerFacingGroups,
                                        session: activeSession,
                                        viewerCanReadLibrary:
                                            viewer?.canReadLibrary ?? false,
                                        showDocumentBodies: true,
                                        onOpenLibraryRoute: onOpenLibraryRoute,
                                        onStartActivity: onStartActivity,
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        'No learner item content in this session.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                              hasTeacherNotes
                                  ? SingleChildScrollView(
                                      child: _SessionWorkspaceAudiencePanel(
                                        title: 'Teacher notes',
                                        description:
                                            'Teaching guidance for running this session.',
                                        emptyState:
                                            'No adult guidance notes are attached to this session.',
                                        icon: Icons.record_voice_over_rounded,
                                        groups: adultFacingGroups,
                                        session: activeSession,
                                        viewerCanReadLibrary:
                                            viewer?.canReadLibrary ?? false,
                                        showDocumentBodies: true,
                                        onOpenLibraryRoute: onOpenLibraryRoute,
                                        onStartActivity: onStartActivity,
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        'No adult guidance or note content in this session.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeMaterials.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: activeMaterials
                          .map(
                            (material) => FilledButton.icon(
                              onPressed: () =>
                                  onStartActivity(activeSession!, material),
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 18,
                              ),
                              label: Text('Start ${material.title}'),
                            ),
                          )
                          .toList(growable: false),
                    )
                  else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _CompactField(
                          label: 'Score',
                          controller: scoreController,
                        ),
                        _CompactField(
                          label: 'Max score',
                          controller: maxScoreController,
                        ),
                        _CompactField(
                          label: 'Minutes',
                          controller: durationController,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Session notes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onRecordSession,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Record session'),
                    ),
                  ],
                ] else
                  Text(
                    'No active session for this learner right now.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (recentWins.isNotEmpty)
            _Band(
              title: 'Recent evidence',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recentWins
                    .map(
                      (win) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    win.sessionTitle,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    win.notes.isEmpty
                                        ? 'Recorded session evidence.'
                                        : win.notes,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _PillBadge(
                              text: win.scoreLabel,
                              color: theme.colorScheme.secondaryContainer,
                              textColor: theme.colorScheme.onSecondaryContainer,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1120;
        final rosterPanel = _SurfaceCard(
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Learner', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 14),
                _GoldAccentDivider(),
                const SizedBox(height: 14),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Learners (${learners.length})'),
                    Tab(text: 'Owners (${owners.length})'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 560,
                  child: TabBarView(
                    children: [
                      learners.isEmpty
                          ? Text(
                              'No learners are visible in this workspace yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: learners
                                    .map(
                                      (learner) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _LearnerCard(
                                          learner: learner,
                                          selected:
                                              learner.learnerId ==
                                              selectedLearnerId,
                                          onTap: () => onSelectLearner(
                                            learner.learnerId,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                      owners.isEmpty
                          ? Text(
                              'No owners are visible in this workspace yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: owners
                                    .map(
                                      (owner) => Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface
                                              .withValues(alpha: 0.58),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              owner.displayName,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '@${owner.username}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _PillBadge(
                                                  text: owner.role,
                                                  color: theme
                                                      .colorScheme
                                                      .secondaryContainer,
                                                  textColor: theme
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                                if (owner.canReadLibrary)
                                                  _PillBadge(
                                                    text: 'Library',
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    textColor: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                if (owner.canViewAllLearners)
                                                  _PillBadge(
                                                    text: 'All learners',
                                                    color: theme
                                                        .colorScheme
                                                        .tertiaryContainer,
                                                    textColor: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PillBadge(
                        text: 'team',
                        color: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Team teaching workspace',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenLibraryWorkspace,
                        child: const Text('Pathway planning'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ContractChipRow(
                    children: [
                      _PillBadge(
                        text: '${learners.length} learners',
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        textColor: theme.colorScheme.primary,
                      ),
                      _PillBadge(
                        text: '$activeSessionCount active today',
                        color: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                      _PillBadge(
                        text: '$totalReviewItems review items',
                        color: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                      ),
                      if (selectedDetail != null)
                        _PillBadge(
                          text:
                              '${selectedDetail.learner.displayName}: $selectedSecureCount secure / $selectedDevelopingCount developing / $selectedNotStartedCount not started / $selectedReviewCount review',
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: rosterPanel),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: _SurfaceCard(child: buildSelectionPanel()),
                  ),
                ],
              )
            else ...[
              rosterPanel,
              const SizedBox(height: 20),
              _SurfaceCard(child: buildSelectionPanel()),
            ],
          ],
        );
      },
    );
  }
}
