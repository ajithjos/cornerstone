part of '../../../main.dart';

class _LearnerWorkspaceView extends StatelessWidget {
  const _LearnerWorkspaceView({
    required this.viewer,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
  });

  final ViewerUser? viewer;
  final LearnerWorkspacePayload? workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnerWorkspace = workspace;
    if (learnerWorkspace == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CornerstoneIcons.learning,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                viewer != null && viewer!.isLearner
                    ? 'This username is not linked to a learner profile yet.'
                    : 'Select a learner to open the learner workspace.',
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

    final assignedJourneys = learnerWorkspace.assignedJourneys.toList(
      growable: false,
    );
    final assignedPathways = learnerWorkspace.assignedPathways.toList(
      growable: false,
    );
    final assignedPathwayCount = assignedPathways.length;
    final singleAssignedJourney = assignedJourneys.length == 1
        ? assignedJourneys.first
        : null;
    final hasMultipleAssignedJourneys = assignedJourneys.length > 1;
    final journey = singleAssignedJourney?.journey ?? learnerWorkspace.journey;
    final learnerSurface = learnerWorkspace.workspace;
    final isSupportView = learnerWorkspace.workspaceView == 'owner_support';
    final continueBlock = learnerSurface.continueBlock;
    List<SessionDetail> orderSessions(Iterable<SessionDetail> source) {
      final ordered = source.toList(growable: false)
        ..sort((left, right) {
          final leftSequence = left.sequenceNumber ?? 1 << 30;
          final rightSequence = right.sequenceNumber ?? 1 << 30;
          final sequenceCompare = leftSequence.compareTo(rightSequence);
          if (sequenceCompare != 0) return sequenceCompare;
          final dateCompare = left.scheduledDate.compareTo(right.scheduledDate);
          if (dateCompare != 0) return dateCompare;
          return left.title.compareTo(right.title);
        });
      return ordered;
    }

    SessionDetail? currentSessionForJourney(
      LearnerAssignedJourney assignedJourney,
      List<SessionDetail> orderedJourneySessions,
    ) {
      final preferredSessionId =
          assignedJourney.currentSessionId ??
          assignedJourney.continueBlock?.session.sessionId;
      if (preferredSessionId != null) {
        for (final session in orderedJourneySessions) {
          if (session.sessionId == preferredSessionId) {
            return session;
          }
        }
      }
      for (final session in orderedJourneySessions) {
        if (session.status != 'completed') {
          return session;
        }
      }
      return orderedJourneySessions.isEmpty
          ? null
          : orderedJourneySessions.first;
    }

    final orderedSessions = orderSessions(
      singleAssignedJourney?.sessions ?? learnerWorkspace.sessions,
    );
    final nextSession =
        continueBlock?.session ??
        orderedSessions
            .where((session) => session.status != 'completed')
            .cast<SessionDetail?>()
            .firstWhere((_) => true, orElse: () => null);
    final currentStanding =
        nextSession?.sequenceNumber ??
        (journey != null && journey.totalSessionCount > 0
            ? (journey.completedSessionCount + 1).clamp(
                1,
                journey.totalSessionCount,
              )
            : null);
    final journeyProgress = journey == null || journey.totalSessionCount == 0
        ? null
        : (journey.completedSessionCount / journey.totalSessionCount).clamp(
            0.0,
            1.0,
          );
    final progressStatusCounts = <String, int>{};
    for (final state in learnerWorkspace.progress) {
      progressStatusCounts.update(
        state.status,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final practiceSessions = learnerSurface.practiceLane;
    final progressSnapshot = learnerSurface.progressSnapshot;
    final recentWins = learnerSurface.recentWins;

    SessionMaterial? primaryExecutableMaterial(SessionDetail session) {
      final learnerExecutables = session.materials
          .where(
            (material) => material.isLearnerFacing && material.isExecutable,
          )
          .toList(growable: false);
      if (learnerExecutables.isEmpty) {
        return null;
      }
      for (final kind in const ['drill', 'quick_check']) {
        for (final material in learnerExecutables) {
          if (material.kind == kind) {
            return material;
          }
        }
      }
      return learnerExecutables.first;
    }

    if (MediaQuery.sizeOf(context).width > 1080) {
      return _LearnerWorkspaceDesktop(
        viewer: viewer,
        workspace: learnerWorkspace,
        viewerCanReadLibrary: viewerCanReadLibrary,
        onOpenLibraryRoute: onOpenLibraryRoute,
        onStartActivity: onStartActivity,
      );
    }

    Widget buildSessionSequenceCard(
      SessionDetail session, {
      required bool active,
    }) {
      final learnerGroups = session.materialsByKind
          .where((group) => group.audience == 'learner')
          .toList(growable: false);
      final adultGroups = session.materialsByKind
          .where((group) => group.audience == 'adult')
          .toList(growable: false);
      final primaryExecutable = primaryExecutableMaterial(session);
      final isRepeatableRun =
          primaryExecutable != null && session.status == 'completed';
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(
                  theme.colorScheme.secondary.withValues(alpha: 0.07),
                  theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.72 : 0.94,
                  ),
                )
              : theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.58 : 0.88,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? theme.colorScheme.secondary.withValues(alpha: 0.22)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.84),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 136),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 14),
            initiallyExpanded: active,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: active
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: active
                      ? theme.colorScheme.onSecondary
                      : theme.colorScheme.primary,
                  child: Text('${session.sequenceNumber ?? '?'}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ContractChip(
                            domain: 'material_kind',
                            value: session.dominantKind,
                          ),
                          if (session.status == 'completed')
                            _PillBadge(
                              text: 'Practice again',
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
                              textColor: theme.colorScheme.primary,
                            ),
                          if (session.requiresAdultSupport)
                            _PillBadge(
                              text: 'Adult support',
                              color: theme.colorScheme.tertiaryContainer,
                              textColor: theme.colorScheme.onTertiaryContainer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PillBadge(
                  text: session.status == 'completed'
                      ? 'Completed'
                      : session.scheduledDate,
                  color: active
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: active
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.primary,
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.materialsByKind
                        .map(
                          (group) => _PillBadge(
                            text:
                                '${_materialKindLabel(group.kind)} · ${group.materialCount}',
                            color: _materialKindBackgroundColor(
                              theme,
                              group.kind,
                            ),
                            textColor: _materialKindForegroundColor(
                              theme,
                              group.kind,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (primaryExecutable != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: primaryExecutable.canStartActivity
                          ? () => onStartActivity(session, primaryExecutable)
                          : null,
                      icon: Icon(
                        CornerstoneIcons.materialKind(primaryExecutable.kind),
                        size: 18,
                      ),
                      label: Text(
                        primaryExecutable.canStartActivity
                            ? _materialActionLabel(
                                primaryExecutable.kind,
                                repeat: isRepeatableRun,
                              )
                            : 'Assessment locked',
                      ),
                    ),
                    if (primaryExecutable.gate != null &&
                        !primaryExecutable.gate!.enabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        primaryExecutable.gate!.reasonLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            children: [
              if (learnerGroups.isEmpty)
                const _MissingLearnerContentNotice()
              else
                _SessionWorkspaceAudiencePanel(
                  title: active
                      ? 'Current session workspace'
                      : 'Session workspace',
                  description:
                      'Open this session to read the note, work through the practice, and launch live activity items.',
                  emptyState:
                      'No learner-facing materials are attached to this session yet.',
                  icon: CornerstoneIcons.learnerAudience,
                  groups: learnerGroups,
                  session: session,
                  viewerCanReadLibrary: viewerCanReadLibrary,
                  showDocumentBodies: true,
                  onOpenLibraryRoute: onOpenLibraryRoute,
                  onStartActivity: onStartActivity,
                ),
              if (isSupportView && adultGroups.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SessionWorkspaceAudiencePanel(
                  title: 'Teaching guidance for parent or teacher',
                  description:
                      'Use this guidance to explain and correct before the learner attempts activities.',
                  emptyState:
                      'No teaching guidance is attached to this session yet.',
                  icon: CornerstoneIcons.teachingGuidance,
                  groups: adultGroups,
                  session: session,
                  viewerCanReadLibrary: viewerCanReadLibrary,
                  showDocumentBodies: true,
                  onOpenLibraryRoute: onOpenLibraryRoute,
                  onStartActivity: onStartActivity,
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget buildAssignedJourneyCard(
      LearnerAssignedJourney assignedJourney, {
      bool includePathwayContext = true,
    }) {
      final assignedJourneyInfo = assignedJourney.journey;
      final orderedJourneySessions = orderSessions(assignedJourney.sessions);
      final currentJourneySession = currentSessionForJourney(
        assignedJourney,
        orderedJourneySessions,
      );
      final currentJourneyStanding =
          currentJourneySession?.sequenceNumber ??
          (assignedJourneyInfo.totalSessionCount > 0
              ? (assignedJourneyInfo.completedSessionCount + 1).clamp(
                  1,
                  assignedJourneyInfo.totalSessionCount,
                )
              : null);
      final journeyProgress = assignedJourneyInfo.totalSessionCount == 0
          ? null
          : (assignedJourneyInfo.completedSessionCount /
                    assignedJourneyInfo.totalSessionCount)
                .clamp(0.0, 1.0);

      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (includePathwayContext) ...[
              Text(
                assignedJourneyInfo.pathwayTitle ??
                    assignedJourneyInfo.playlistTitle,
                style: theme.textTheme.titleLarge,
              ),
              if ((assignedJourneyInfo.pathwayDescription ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  assignedJourneyInfo.pathwayDescription!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            Text(
              assignedJourneyInfo.playlistTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              assignedJourneyInfo.playlistDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillBadge(
                  text: 'status:${assignedJourney.assignment.status}',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
                _PillBadge(
                  text: currentJourneyStanding == null
                      ? 'Standing not started'
                      : 'Standing S$currentJourneyStanding/${assignedJourneyInfo.totalSessionCount}',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
                _PillBadge(
                  text:
                      '${assignedJourneyInfo.completedSessionCount} completed',
                  color: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                ),
                _PillBadge(
                  text: '${assignedJourneyInfo.pendingSessionCount} pending',
                  color: theme.colorScheme.tertiaryContainer,
                  textColor: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ),
            if (journeyProgress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: journeyProgress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            if (viewerCanReadLibrary &&
                (assignedJourneyInfo.pathwayRoutePath != null ||
                    assignedJourneyInfo.playlistRoutePath != null)) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (assignedJourneyInfo.pathwayRoutePath != null)
                    TextButton(
                      onPressed: () => onOpenLibraryRoute(
                        assignedJourneyInfo.pathwayRoutePath!,
                      ),
                      child: const Text('Open pathway brief'),
                    ),
                  if (assignedJourneyInfo.playlistRoutePath != null)
                    TextButton(
                      onPressed: () => onOpenLibraryRoute(
                        assignedJourneyInfo.playlistRoutePath!,
                      ),
                      child: const Text('Open playlist brief'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text('Session path', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'This playlist shows every session in order, with the current one highlighted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (orderedJourneySessions.isEmpty)
              Text(
                'No sessions are available yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...orderedJourneySessions.map(
                (session) => buildSessionSequenceCard(
                  session,
                  active: session.sessionId == currentJourneySession?.sessionId,
                ),
              ),
          ],
        ),
      );
    }

    Widget buildAssignedPathwayCard(LearnerAssignedPathway assignedPathway) {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignedPathway.pathwayTitle,
              style: theme.textTheme.headlineSmall,
            ),
            if (assignedPathway.pathwayDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                assignedPathway.pathwayDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillBadge(
                  text:
                      '${assignedPathway.playlistCount} playlist${assignedPathway.playlistCount == 1 ? '' : 's'}',
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
            if (viewerCanReadLibrary &&
                assignedPathway.pathwayRoutePath != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () =>
                    onOpenLibraryRoute(assignedPathway.pathwayRoutePath!),
                child: const Text('Open pathway brief'),
              ),
            ],
            const SizedBox(height: 18),
            Text('Assigned playlists', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Each playlist below keeps its own standing and full session path inside this pathway.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            ...assignedPathway.assignedPlaylists.expand(
              (assignedJourney) => [
                const SizedBox(height: 18),
                buildAssignedJourneyCard(
                  assignedJourney,
                  includePathwayContext: false,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _PageHeroCard(
          eyebrow: isSupportView ? 'Learner preview' : 'Learner home',
          title: isSupportView
              ? 'Learner workspace for support'
              : 'My learning workspace',
          description: hasMultipleAssignedJourneys
              ? assignedPathwayCount > 1
                    ? 'You have ${assignedJourneys.length} assigned playlists across $assignedPathwayCount pathways. Start in Now, then open each playlist below to see its own current session and full session path.'
                    : 'You have ${assignedJourneys.length} assigned playlists in one pathway. Start in Now, then open each playlist below to see its own current session and full session path.'
              : journey == null
              ? 'This is your learner home: start now, keep practising, and track progress in one place.'
              : learnerSurface.attentionLabel.isNotEmpty
              ? learnerSurface.attentionLabel
              : currentStanding == null
              ? 'You are part of ${journey.playlistTitle}. Start in the Now lane, then move through practice and journey steps.'
              : 'You are in ${journey.playlistTitle}, standing at session $currentStanding of ${journey.totalSessionCount}. Start in Now, then continue through practice and progress.',
          chips: [
            if (isSupportView)
              _PillBadge(
                text: 'support view · role:${learnerWorkspace.viewerRole}',
                color: theme.colorScheme.tertiaryContainer,
                textColor: theme.colorScheme.onTertiaryContainer,
              ),
            if (assignedJourneys.isNotEmpty)
              _StatChip(
                label: 'Playlists',
                value: '${assignedJourneys.length}',
                icon: CornerstoneIcons.playlist,
              ),
            if (assignedPathwayCount > 0)
              _StatChip(
                label: 'Pathways',
                value: '$assignedPathwayCount',
                icon: CornerstoneIcons.pathway,
              ),
            if (!hasMultipleAssignedJourneys)
              _StatChip(
                label: 'Standing',
                value: currentStanding == null
                    ? '--'
                    : 'S$currentStanding/${journey?.totalSessionCount ?? learnerWorkspace.sessions.length}',
                icon: CornerstoneIcons.standing,
              ),
            _StatChip(
              label: 'Completed',
              value: '${progressSnapshot.completedSessionCount}',
              icon: CornerstoneIcons.completed,
            ),
            _StatChip(
              label: 'Ready now',
              value: '${progressSnapshot.pendingSessionCount}',
              icon: CornerstoneIcons.readyNow,
            ),
            _StatChip(
              label: 'Review',
              value: '${progressSnapshot.reviewItemCount}',
              icon: CornerstoneIcons.review,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learning lanes', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Use this order: Now, Practice, Journey, Progress.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PillBadge(
                    text: nextSession == null
                        ? 'Now: waiting'
                        : 'Now: Session ${nextSession.sequenceNumber ?? '?'}',
                    color: theme.colorScheme.secondaryContainer,
                    textColor: theme.colorScheme.onSecondaryContainer,
                  ),
                  _PillBadge(
                    text:
                        'Practice: ${practiceSessions.length} step${practiceSessions.length == 1 ? '' : 's'}',
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    textColor: theme.colorScheme.primary,
                  ),
                  _PillBadge(
                    text:
                        'Progress: ${progressSnapshot.reviewItemCount} review',
                    color: theme.colorScheme.tertiaryContainer,
                    textColor: theme.colorScheme.onTertiaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (assignedPathways.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned playlists',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  assignedPathwayCount > 1
                      ? 'Your work is grouped by pathway first, then by playlist, so each session path stays separate.'
                      : 'Your assigned work is grouped by pathway, then by playlist, so the session path stays clear.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...assignedPathways.expand(
            (assignedPathway) => [
              const SizedBox(height: 20),
              buildAssignedPathwayCard(assignedPathway),
            ],
          ),
        ] else if (journey != null) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My current pathway',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  journey.pathwayTitle ?? journey.playlistTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const _ContractChipRow(
                  children: [
                    _ContractChip(domain: 'entity', value: 'pathway'),
                    _ContractChip(domain: 'entity', value: 'playlist'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  journey.pathwayDescription ?? journey.playlistDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillBadge(
                      text: '${journey.totalSessionCount} sessions',
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      textColor: theme.colorScheme.primary,
                    ),
                    _PillBadge(
                      text: '${journey.totalMaterialCount} materials',
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                    if (journey.recommendedLevel.isNotEmpty)
                      _PillBadge(
                        text: journey.recommendedLevel,
                        color: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                      ),
                  ],
                ),
                if (journeyProgress != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: journeyProgress,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentStanding == null
                        ? '${journey.completedSessionCount} of ${journey.totalSessionCount} sessions completed'
                        : 'You are standing at session $currentStanding of ${journey.totalSessionCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (viewerCanReadLibrary &&
                    (journey.pathwayRoutePath != null ||
                        journey.playlistRoutePath != null)) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (journey.pathwayRoutePath != null)
                        TextButton(
                          onPressed: () =>
                              onOpenLibraryRoute(journey.pathwayRoutePath!),
                          child: const Text('Open pathway brief'),
                        ),
                      if (journey.playlistRoutePath != null)
                        TextButton(
                          onPressed: () =>
                              onOpenLibraryRoute(journey.playlistRoutePath!),
                          child: const Text('Open playlist brief'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (nextSession != null) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Now', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  continueBlock?.description ??
                      'This is the workspace for what you are learning right now. Read the note, do the practice, and launch the live step from here.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (continueBlock != null) ...[
                  Text(continueBlock.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                ],
                _ContractChipRow(
                  children: [
                    if (continueBlock != null)
                      _PillBadge(
                        text: continueBlock.actionLabel,
                        color: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                    const _ContractChip(domain: 'entity', value: 'session'),
                    _ContractChip(
                      domain: 'material_kind',
                      value: nextSession.dominantKind,
                    ),
                    if (nextSession.requiresAdultSupport)
                      const _ContractChip(
                        domain: 'status',
                        value: 'adult_guided',
                      ),
                    if (nextSession.estimatedMinutes > 0)
                      _PillBadge(
                        text: '${nextSession.estimatedMinutes} min',
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        textColor: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final learnerGroups = nextSession.materialsByKind
                        .where((group) => group.audience == 'learner')
                        .toList(growable: false);
                    final adultGroups = nextSession.materialsByKind
                        .where((group) => group.audience == 'adult')
                        .toList(growable: false);
                    if (learnerGroups.isEmpty) {
                      return const _MissingLearnerContentNotice();
                    }
                    return Column(
                      children: [
                        _SessionWorkspaceAudiencePanel(
                          title: isSupportView
                              ? 'Learner materials in this session'
                              : 'What I work on now',
                          description:
                              'The learner-facing materials for the current session stay together here.',
                          emptyState:
                              'No learner-facing materials are attached to this session yet.',
                          icon: CornerstoneIcons.learnerAudience,
                          groups: learnerGroups,
                          session: nextSession,
                          viewerCanReadLibrary: viewerCanReadLibrary,
                          showDocumentBodies: true,
                          onOpenLibraryRoute: onOpenLibraryRoute,
                          onStartActivity: onStartActivity,
                        ),
                        if (isSupportView && adultGroups.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SessionWorkspaceAudiencePanel(
                            title: 'Teaching guidance for parent or teacher',
                            description:
                                'Use this guidance to explain and correct before the learner attempts activities.',
                            emptyState:
                                'No teaching guidance is attached to this session yet.',
                            icon: CornerstoneIcons.teachingGuidance,
                            groups: adultGroups,
                            session: nextSession,
                            viewerCanReadLibrary: viewerCanReadLibrary,
                            showDocumentBodies: true,
                            onOpenLibraryRoute: onOpenLibraryRoute,
                            onStartActivity: onStartActivity,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (recentWins.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent wins', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Completed work that has already been recorded for this learner.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ...recentWins.map(
                  (win) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                win.sessionTitle,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                win.notes.isEmpty
                                    ? 'Completed and recorded in the learner history.'
                                    : win.notes,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _PillBadge(
                          text: win.scoreLabel,
                          color: theme.colorScheme.secondaryContainer,
                          textColor: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (assignedJourneys.isEmpty) ...[
          const SizedBox(height: 20),
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Journey lane', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Open any session workspace below to see where you stand and what that session asks you to do.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (learnerWorkspace.sessions.isEmpty)
                  Text(
                    'No sessions are available yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...orderedSessions.map(
                    (session) => buildSessionSequenceCard(
                      session,
                      active: session.sessionId == nextSession?.sessionId,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Practice lane', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Open the practice and unlocked assessments that are already inside your assigned route.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (practiceSessions.isEmpty)
                Text(
                  'No practice items are available yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...practiceSessions.map((session) {
                  final practiceGroups = session.materialsByKind
                      .where(
                        (group) =>
                            group.kind == 'worksheet' ||
                            group.kind == 'drill' ||
                            group.kind == 'quick_check',
                      )
                      .toList(growable: false);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ContractChip(
                              domain: 'material_kind',
                              value: session.dominantKind,
                            ),
                            _PillBadge(
                              text: 'Session ${session.sequenceNumber ?? '?'}',
                              color: theme.colorScheme.surfaceContainerHighest,
                              textColor: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...practiceGroups.map(
                          (group) => _SessionMaterialGroupPanel(
                            group: group,
                            session: session,
                            viewerCanReadLibrary: viewerCanReadLibrary,
                            showDocumentBodies: true,
                            onOpenLibraryRoute: onOpenLibraryRoute,
                            onStartActivity: onStartActivity,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Progress report', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'A simple snapshot of where this learner is secure, still developing, and not started yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (progressStatusCounts.isEmpty &&
                  progressSnapshot.secureCount == 0 &&
                  progressSnapshot.developingCount == 0 &&
                  progressSnapshot.notStartedCount == 0)
                Text(
                  'No progress has been recorded yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PillBadge(
                      text: '${progressSnapshot.secureCount} secure',
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                    _PillBadge(
                      text: '${progressSnapshot.developingCount} developing',
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      textColor: theme.colorScheme.primary,
                    ),
                    _PillBadge(
                      text: '${progressSnapshot.notStartedCount} not started',
                      color: theme.colorScheme.surfaceContainerHighest,
                      textColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    _PillBadge(
                      text: '${progressSnapshot.reviewItemCount} review items',
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review queue', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'These are the skills that still need another pass.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (learnerWorkspace.reviewItems.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    const Text('No pending review items.'),
                  ],
                )
              else
                ...learnerWorkspace.reviewItems.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.reason),
                    subtitle: Text(_contractTermLabel(item.skillId)),
                    trailing: _PillBadge(
                      text: item.dueDate,
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
