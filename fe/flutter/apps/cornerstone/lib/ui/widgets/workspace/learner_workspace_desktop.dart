part of '../../../main.dart';

enum _SessionStatusFilter { all, pending, completed }

class _LearnerWorkspaceDesktop extends StatefulWidget {
  const _LearnerWorkspaceDesktop({
    required this.viewer,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
  });

  final ViewerUser? viewer;
  final LearnerWorkspacePayload workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;

  @override
  State<_LearnerWorkspaceDesktop> createState() =>
      _LearnerWorkspaceDesktopState();
}

class _LearnerWorkspaceDesktopState extends State<_LearnerWorkspaceDesktop> {
  String? _selectedAssignmentId;
  String? _selectedSessionId;
  _SessionStatusFilter _sessionFilter = _SessionStatusFilter.all;
  final Set<String> _expandedPathwayKeys = <String>{};
  final Set<String> _expandedAssignmentIds = <String>{};

  List<LearnerAssignedJourney> get _assignedJourneys =>
      widget.workspace.assignedJourneys;

  List<LearnerAssignedPathway> get _assignedPathways =>
      widget.workspace.assignedPathways;

  LearnerWorkspace get _workspace => widget.workspace.workspace;

  bool get _isSupportView => widget.workspace.workspaceView == 'owner_support';

  List<SessionDetail> _orderSessions(Iterable<SessionDetail> source) {
    final sessions = source.toList(growable: false)
      ..sort((left, right) {
        final leftSequence = left.sequenceNumber ?? 1 << 30;
        final rightSequence = right.sequenceNumber ?? 1 << 30;
        final sequenceCompare = leftSequence.compareTo(rightSequence);
        if (sequenceCompare != 0) return sequenceCompare;
        final dateCompare = left.scheduledDate.compareTo(right.scheduledDate);
        if (dateCompare != 0) return dateCompare;
        return left.title.compareTo(right.title);
      });
    return sessions;
  }

  LearnerAssignedJourney? get _selectedAssignedJourney {
    final journeys = _assignedJourneys;
    if (journeys.isEmpty) {
      return null;
    }
    for (final journey in journeys) {
      if (journey.assignment.assignmentId == _selectedAssignmentId) {
        return journey;
      }
    }
    return journeys.first;
  }

  LearnerJourney? get _journey =>
      _selectedAssignedJourney?.journey ?? widget.workspace.journey;

  List<SessionDetail> get _orderedSessions {
    return _orderSessions(
      _selectedAssignedJourney?.sessions ?? widget.workspace.sessions,
    );
  }

  SessionDetail? _currentSessionForJourney(
    LearnerAssignedJourney assignedJourney,
  ) {
    final orderedJourneySessions = _orderSessions(assignedJourney.sessions);
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
    return orderedJourneySessions.isEmpty ? null : orderedJourneySessions.first;
  }

  SessionDetail? get _currentSession {
    final selectedJourney = _selectedAssignedJourney;
    if (selectedJourney != null) {
      return _currentSessionForJourney(selectedJourney);
    }
    for (final session in _orderedSessions) {
      if (session.status != 'completed') {
        return session;
      }
    }
    return null;
  }

  SessionDetail? get _selectedSession {
    final sessions = _orderedSessions;
    if (sessions.isEmpty) {
      return null;
    }
    for (final session in sessions) {
      if (session.sessionId == _selectedSessionId) {
        return session;
      }
    }
    return _currentSession ?? sessions.first;
  }

  String _pathwayKey(LearnerAssignedPathway pathway) {
    return pathway.pathwayId ?? 'title:${pathway.pathwayTitle}';
  }

  bool _sessionMatchesFilter(SessionDetail session) {
    return switch (_sessionFilter) {
      _SessionStatusFilter.all => true,
      _SessionStatusFilter.pending => session.status != 'completed',
      _SessionStatusFilter.completed => session.status == 'completed',
    };
  }

  void _selectPlaylist(LearnerAssignedJourney assignedJourney) {
    final currentSession = _currentSessionForJourney(assignedJourney);
    setState(() {
      _selectedAssignmentId = assignedJourney.assignment.assignmentId;
      _selectedSessionId = currentSession?.sessionId;
      _expandedAssignmentIds.add(assignedJourney.assignment.assignmentId);
    });
  }

  void _selectSession(
    LearnerAssignedJourney assignedJourney,
    SessionDetail session,
  ) {
    setState(() {
      _selectedAssignmentId = assignedJourney.assignment.assignmentId;
      _selectedSessionId = session.sessionId;
      _expandedAssignmentIds.add(assignedJourney.assignment.assignmentId);
    });
  }

  void _ensureExpansionForSelection() {
    final selectedJourney = _selectedAssignedJourney;
    if (selectedJourney == null) {
      return;
    }
    for (final pathway in _assignedPathways) {
      for (final playlist in pathway.assignedPlaylists) {
        if (playlist.assignment.assignmentId ==
            selectedJourney.assignment.assignmentId) {
          _expandedPathwayKeys.add(_pathwayKey(pathway));
          _expandedAssignmentIds.add(selectedJourney.assignment.assignmentId);
          return;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _syncSelection();
    _ensureExpansionForSelection();
  }

  @override
  void didUpdateWidget(covariant _LearnerWorkspaceDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
    _ensureExpansionForSelection();
  }

  void _syncSelection() {
    final continueSessionId = _workspace.continueBlock?.session.sessionId;
    final assignedJourneys = _assignedJourneys;
    if (assignedJourneys.isNotEmpty) {
      final hasSelectedAssignment = assignedJourneys.any(
        (journey) => journey.assignment.assignmentId == _selectedAssignmentId,
      );
      if (!hasSelectedAssignment) {
        if (continueSessionId != null) {
          for (final journey in assignedJourneys) {
            if (journey.sessions.any(
              (session) => session.sessionId == continueSessionId,
            )) {
              _selectedAssignmentId = journey.assignment.assignmentId;
              break;
            }
          }
        }
        _selectedAssignmentId ??=
            assignedJourneys.first.assignment.assignmentId;
      }
    }
    final selected = _selectedSession;
    _selectedSessionId = selected?.sessionId;
  }

  Widget _buildHeader(ThemeData theme) {
    final snapshot = _workspace.progressSnapshot;
    final assignedPlaylistCount = _assignedJourneys.length;
    final assignedPathwayCount = _assignedPathways.length;
    final continueBlock = _workspace.continueBlock;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillBadge(
                text: _isSupportView ? 'support view' : 'learner view',
                color: theme.colorScheme.secondaryContainer,
                textColor: theme.colorScheme.onSecondaryContainer,
              ),
              if (_isSupportView)
                _PillBadge(
                  text: 'role:${widget.workspace.viewerRole}',
                  color: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isSupportView
                ? 'Learner workspace preview'
                : 'My learning workspace',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            assignedPlaylistCount > 0
                ? 'Browse pathways, playlists, and sessions in order on the left. Open any session on the right to read materials and start activities.'
                : _isSupportView
                ? 'No assigned playlists yet. Session details will appear here when work is assigned.'
                : 'Your assigned learning will appear here when a parent or teacher assigns pathways.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (assignedPathwayCount > 0)
                _StatChip(
                  label: 'Pathways',
                  value: '$assignedPathwayCount',
                  icon: Icons.route_rounded,
                ),
              if (assignedPlaylistCount > 0)
                _StatChip(
                  label: 'Playlists',
                  value: '$assignedPlaylistCount',
                  icon: Icons.view_carousel_rounded,
                ),
              _StatChip(
                label: 'Completed',
                value: '${snapshot.completedSessionCount}',
                icon: Icons.task_alt_rounded,
              ),
              _StatChip(
                label: 'Pending',
                value: '${snapshot.pendingSessionCount}',
                icon: Icons.timelapse_rounded,
              ),
              _StatChip(
                label: 'Review',
                value: '${snapshot.reviewItemCount}',
                icon: Icons.pending_actions_rounded,
              ),
            ],
          ),
          if (continueBlock != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          continueBlock.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          continueBlock.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      for (final journey in _assignedJourneys) {
                        if (journey.sessions.any(
                          (session) =>
                              session.sessionId ==
                              continueBlock.session.sessionId,
                        )) {
                          _selectSession(journey, continueBlock.session);
                          return;
                        }
                      }
                      setState(() {
                        _selectedSessionId = continueBlock.session.sessionId;
                      });
                    },
                    child: Text(continueBlock.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionFilterBar(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All sessions'),
          selected: _sessionFilter == _SessionStatusFilter.all,
          onSelected: (_) {
            setState(() => _sessionFilter = _SessionStatusFilter.all);
          },
        ),
        ChoiceChip(
          label: const Text('Pending'),
          selected: _sessionFilter == _SessionStatusFilter.pending,
          onSelected: (_) {
            setState(() => _sessionFilter = _SessionStatusFilter.pending);
          },
        ),
        ChoiceChip(
          label: const Text('Completed'),
          selected: _sessionFilter == _SessionStatusFilter.completed,
          onSelected: (_) {
            setState(() => _sessionFilter = _SessionStatusFilter.completed);
          },
        ),
      ],
    );
  }

  Widget _buildSessionTile({
    required ThemeData theme,
    required SessionDetail session,
    required bool isSelected,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    if (!_sessionMatchesFilter(session)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : isCurrent
                  ? theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.40,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : isCurrent
                    ? theme.colorScheme.secondary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  child: Text(
                    '${session.sequenceNumber ?? '?'}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isCurrent)
                            _PillBadge(
                              text: 'Current',
                              color: theme.colorScheme.secondaryContainer,
                              textColor:
                                  theme.colorScheme.onSecondaryContainer,
                            ),
                          _PillBadge(
                            text: session.status == 'completed'
                                ? 'Completed'
                                : 'Pending',
                            color: session.status == 'completed'
                                ? theme.colorScheme.surfaceContainerHighest
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                            textColor: session.status == 'completed'
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistSection({
    required ThemeData theme,
    required LearnerAssignedJourney assignedJourney,
    required String pathwayKey,
  }) {
    final journey = assignedJourney.journey;
    final assignmentId = assignedJourney.assignment.assignmentId;
    final orderedSessions = _orderSessions(assignedJourney.sessions);
    final visibleSessions = orderedSessions
        .where(_sessionMatchesFilter)
        .toList(growable: false);
    final currentSession = _currentSessionForJourney(assignedJourney);
    final isPlaylistSelected = assignmentId == _selectedAssignmentId;
    final isExpanded = _expandedAssignmentIds.contains(assignmentId);

    if (visibleSessions.isEmpty && _sessionFilter != _SessionStatusFilter.all) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('playlist-$assignmentId'),
        tilePadding: const EdgeInsets.only(left: 12, right: 4),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        initiallyExpanded: isExpanded || isPlaylistSelected,
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedAssignmentIds.add(assignmentId);
            } else {
              _expandedAssignmentIds.remove(assignmentId);
            }
          });
        },
        leading: Icon(
          Icons.view_carousel_rounded,
          size: 20,
          color: isPlaylistSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          journey.playlistTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: isPlaylistSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${journey.completedSessionCount}/${journey.totalSessionCount} sessions done',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          tooltip: 'Open this playlist',
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          onPressed: () => _selectPlaylist(assignedJourney),
        ),
        children: visibleSessions.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 8),
                  child: Text(
                    'No sessions match this filter.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : visibleSessions
                  .map(
                    (session) => _buildSessionTile(
                      theme: theme,
                      session: session,
                      isSelected: session.sessionId == _selectedSessionId,
                      isCurrent: session.sessionId == currentSession?.sessionId,
                      onTap: () => _selectSession(assignedJourney, session),
                    ),
                  )
                  .toList(growable: false),
      ),
    );
  }

  Widget _buildPathwaySection({
    required ThemeData theme,
    required LearnerAssignedPathway pathway,
  }) {
    final pathwayKey = _pathwayKey(pathway);
    final isExpanded = _expandedPathwayKeys.contains(pathwayKey);
    final hasVisiblePlaylists = pathway.assignedPlaylists.any((playlist) {
      if (_sessionFilter == _SessionStatusFilter.all) {
        return true;
      }
      return _orderSessions(playlist.sessions).any(_sessionMatchesFilter);
    });

    if (!hasVisiblePlaylists) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('pathway-$pathwayKey'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedPathwayKeys.add(pathwayKey);
              } else {
                _expandedPathwayKeys.remove(pathwayKey);
              }
            });
          },
          title: Text(
            pathway.pathwayTitle,
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            '${pathway.playlistCount} playlist${pathway.playlistCount == 1 ? '' : 's'} · ${pathway.completedSessionCount}/${pathway.totalSessionCount} sessions done',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            if (pathway.pathwayDescription.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  pathway.pathwayDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...pathway.assignedPlaylists.map(
              (playlist) => _buildPlaylistSection(
                theme: theme,
                assignedJourney: playlist,
                pathwayKey: pathwayKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigatorPanel(ThemeData theme) {
    final pathways = _assignedPathways;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning navigator', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Pathways, playlists, and sessions appear in assignment order. Expand each level to browse everything, completed or not.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _buildSessionFilterBar(theme),
          const SizedBox(height: 14),
          if (pathways.isNotEmpty)
            ...pathways.map(
              (pathway) => _buildPathwaySection(theme: theme, pathway: pathway),
            )
          else if (_assignedJourneys.isNotEmpty)
            ..._assignedJourneys.map(
              (assignedJourney) => _buildPlaylistSection(
                theme: theme,
                assignedJourney: assignedJourney,
                pathwayKey: 'ungrouped',
              ),
            )
          else
            Text(
              'No assigned pathways yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(ThemeData theme, SessionDetail session) {
    final journey = _journey;
    if (journey == null) {
      return const SizedBox.shrink();
    }

    final parts = <String>[
      if ((journey.pathwayTitle ?? '').isNotEmpty) journey.pathwayTitle!,
      journey.playlistTitle,
      'Session ${session.sequenceNumber ?? '?'}',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < parts.length; index++) ...[
          if (index > 0)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          _PillBadge(
            text: parts[index],
            color: index == parts.length - 1
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            textColor: index == parts.length - 1
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _buildSessionDetailPanel(ThemeData theme, SessionDetail? session) {
    if (session == null) {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session workspace', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Select a session in the navigator to open its materials here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final learnerGroups = session.materialsByKind
        .where((group) => group.audience == 'learner')
        .toList(growable: false);
    final adultGroups = session.materialsByKind
        .where((group) => group.audience == 'adult')
        .toList(growable: false);
    final isCurrent = session.sessionId == _currentSession?.sessionId;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb(theme, session),
          const SizedBox(height: 14),
          Text(
            isCurrent ? 'Current session' : 'Selected session',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(session.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillBadge(
                text: session.status == 'completed' ? 'Completed' : 'Pending',
                color: session.status == 'completed'
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                textColor: session.status == 'completed'
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              if (session.estimatedMinutes > 0)
                _PillBadge(
                  text: '${session.estimatedMinutes} min',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
              if (session.requiresAdultSupport)
                _PillBadge(
                  text: 'Adult-guided',
                  color: theme.colorScheme.tertiaryContainer,
                  textColor: theme.colorScheme.onTertiaryContainer,
                ),
              _ContractChip(
                domain: 'material_kind',
                value: session.dominantKind,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (learnerGroups.isEmpty)
            const _MissingLearnerContentNotice()
          else
            _SessionWorkspaceAudiencePanel(
              title: _isSupportView
                  ? 'Learner items'
                  : 'What I do in this session',
              description:
                  'Everything learner-facing for this session is grouped here.',
              emptyState:
                  'No learner-facing materials are attached to this session yet.',
              icon: Icons.school_rounded,
              groups: learnerGroups,
              session: session,
              viewerCanReadLibrary: widget.viewerCanReadLibrary,
              showDocumentBodies: true,
              onOpenLibraryRoute: widget.onOpenLibraryRoute,
              onStartActivity: widget.onStartActivity,
            ),
          if (_isSupportView) ...[
            const SizedBox(height: 12),
            _SessionWorkspaceAudiencePanel(
              title: 'Teaching guidance',
              description:
                  'Use these notes to guide explanation and correction for this session.',
              emptyState: 'No teaching guidance is attached to this session.',
              icon: Icons.co_present_rounded,
              groups: adultGroups,
              session: session,
              viewerCanReadLibrary: widget.viewerCanReadLibrary,
              showDocumentBodies: true,
              onOpenLibraryRoute: widget.onOpenLibraryRoute,
              onStartActivity: widget.onStartActivity,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressPanel(ThemeData theme) {
    final snapshot = _workspace.progressSnapshot;
    final reviewItems = widget.workspace.reviewItems;
    final total =
        snapshot.secureCount +
        snapshot.developingCount +
        snapshot.notStartedCount;

    Widget buildMeter(String label, int value, Color color) {
      final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text('$value', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      );
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress snapshot', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          buildMeter(
            'Secure',
            snapshot.secureCount,
            theme.colorScheme.secondary,
          ),
          const SizedBox(height: 10),
          buildMeter(
            'Developing',
            snapshot.developingCount,
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          buildMeter(
            'Not started',
            snapshot.notStartedCount,
            theme.colorScheme.outline,
          ),
          if (reviewItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Review items', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            ...reviewItems.map(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedSession = _selectedSession;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideBySide = constraints.maxWidth >= 1180;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            if (useSideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: _buildNavigatorPanel(theme),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 14,
                    child: _buildSessionDetailPanel(theme, selectedSession),
                  ),
                ],
              )
            else ...[
              _buildNavigatorPanel(theme),
              const SizedBox(height: 16),
              _buildSessionDetailPanel(theme, selectedSession),
            ],
            const SizedBox(height: 16),
            _buildProgressPanel(theme),
          ],
        );
      },
    );
  }
}
