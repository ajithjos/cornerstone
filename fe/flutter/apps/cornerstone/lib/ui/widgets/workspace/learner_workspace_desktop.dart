part of '../../../main.dart';

enum _SessionStatusFilter { all, pending, completed }

class _LearnerWorkspaceDesktop extends StatefulWidget {
  const _LearnerWorkspaceDesktop({
    required this.viewer,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
    this.onSetProficiencyOverride,
    this.onClearProficiencyOverride,
  });

  final ViewerUser? viewer;
  final LearnerWorkspacePayload workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;
  final Future<void> Function(SessionMaterial material)?
  onSetProficiencyOverride;
  final Future<void> Function(SessionMaterial material)?
  onClearProficiencyOverride;

  @override
  State<_LearnerWorkspaceDesktop> createState() =>
      _LearnerWorkspaceDesktopState();
}

class _LearnerWorkspaceDesktopState extends State<_LearnerWorkspaceDesktop> {
  String? _selectedAssignmentId;
  String? _selectedSessionId;
  _SessionStatusFilter _sessionFilter = _SessionStatusFilter.all;
  bool _learningMenuOpen = true;
  bool _progressOpen = false;
  int _menuTreeVersion = 0;
  final Set<String> _expandedPathwayKeys = <String>{};
  final Set<String> _expandedAssignmentIds = <String>{};

  List<LearnerAssignedJourney> get _assignedJourneys =>
      widget.workspace.assignedJourneys;

  List<LearnerAssignedPathway> get _assignedPathways =>
      widget.workspace.assignedPathways;

  LearnerWorkspace get _workspace => widget.workspace.workspace;

  bool get _isSupportView => widget.workspace.workspaceView == 'owner_support';

  String get _viewerModeLabel {
    if (_isSupportView) {
      return switch (widget.workspace.viewerRole) {
        'owner' => 'Parent view',
        'learner' => 'Learner view',
        _ => 'Teacher view',
      };
    }
    return 'Learner view';
  }

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

  SessionMaterial? _primaryExecutableMaterial(SessionDetail session) {
    final learnerExecutables = session.materials
        .where((material) => material.isLearnerFacing && material.isExecutable)
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

  Iterable<String> get _allPathwayKeys sync* {
    for (final pathway in _assignedPathways) {
      yield _pathwayKey(pathway);
    }
  }

  Iterable<String> get _allAssignmentIds sync* {
    if (_assignedPathways.isNotEmpty) {
      for (final pathway in _assignedPathways) {
        for (final playlist in pathway.assignedPlaylists) {
          yield playlist.assignment.assignmentId;
        }
      }
      return;
    }
    for (final journey in _assignedJourneys) {
      yield journey.assignment.assignmentId;
    }
  }

  bool get _isAllMenuExpanded {
    final pathwayKeys = _allPathwayKeys.toList(growable: false);
    final assignmentIds = _allAssignmentIds.toList(growable: false);
    if (pathwayKeys.isEmpty && assignmentIds.isEmpty) {
      return false;
    }
    final pathwaysExpanded =
        pathwayKeys.isEmpty || pathwayKeys.every(_expandedPathwayKeys.contains);
    final playlistsExpanded = assignmentIds.every(
      _expandedAssignmentIds.contains,
    );
    return pathwaysExpanded && playlistsExpanded;
  }

  void _toggleExpandAllMenu() {
    setState(() {
      if (_isAllMenuExpanded) {
        _expandedPathwayKeys.clear();
        _expandedAssignmentIds.clear();
      } else {
        _expandedPathwayKeys.addAll(_allPathwayKeys);
        _expandedAssignmentIds.addAll(_allAssignmentIds);
      }
      _menuTreeVersion++;
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

  Widget _buildCompactStat(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconToggle({
    required ThemeData theme,
    required String tooltip,
    required IconData icon,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          backgroundColor: active
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.40,
                ),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final snapshot = _workspace.progressSnapshot;
    final assignedPlaylistCount = _assignedJourneys.length;
    final assignedPathwayCount = _assignedPathways.length;
    final hasAssignments =
        assignedPlaylistCount > 0 || _assignedPathways.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _isSupportView ? 'Learner workspace' : 'My learning',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _PillBadge(
                      text: _viewerModeLabel,
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (assignedPathwayCount > 0)
                    _buildCompactStat(
                      theme,
                      value: '$assignedPathwayCount',
                      label: 'pathways',
                      icon: CornerstoneIcons.pathway,
                    ),
                  if (assignedPlaylistCount > 0)
                    _buildCompactStat(
                      theme,
                      value: '$assignedPlaylistCount',
                      label: 'playlists',
                      icon: CornerstoneIcons.playlist,
                    ),
                  _buildCompactStat(
                    theme,
                    value: '${snapshot.pendingSessionCount}',
                    label: 'pending',
                    icon: CornerstoneIcons.pending,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (hasAssignments)
                _buildIconToggle(
                  theme: theme,
                  tooltip: _learningMenuOpen ? 'Hide menu' : 'Show menu',
                  icon: _learningMenuOpen
                      ? CornerstoneIcons.menuOpen
                      : CornerstoneIcons.menu,
                  active: _learningMenuOpen,
                  onPressed: () {
                    setState(() => _learningMenuOpen = !_learningMenuOpen);
                  },
                )
              else
                const SizedBox(width: 34, height: 34),
              const Spacer(),
              _buildIconToggle(
                theme: theme,
                tooltip: _progressOpen
                    ? 'Hide progress snapshot'
                    : 'Show progress snapshot',
                icon: _progressOpen
                    ? CornerstoneIcons.progressActive
                    : CornerstoneIcons.progress,
                active: _progressOpen,
                onPressed: () {
                  setState(() => _progressOpen = !_progressOpen);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionFilterBar(ThemeData theme) {
    return Row(
      children: [
        _buildFilterChip(theme, 'All', _SessionStatusFilter.all),
        const SizedBox(width: 6),
        _buildFilterChip(theme, 'Pending', _SessionStatusFilter.pending),
        const SizedBox(width: 6),
        _buildFilterChip(theme, 'Done', _SessionStatusFilter.completed),
        const Spacer(),
        _buildIconToggle(
          theme: theme,
          tooltip: _isAllMenuExpanded ? 'Collapse all' : 'Expand all',
          icon: _isAllMenuExpanded
              ? CornerstoneIcons.collapseAll
              : CornerstoneIcons.expandAll,
          active: _isAllMenuExpanded,
          onPressed: _toggleExpandAllMenu,
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    ThemeData theme,
    String label,
    _SessionStatusFilter value,
  ) {
    final selected = _sessionFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _sessionFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.35)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
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

    final hasRepeatableActivity =
        session.status == 'completed' &&
        _primaryExecutableMaterial(session) != null;

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : isCurrent
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.40)
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
                  radius: 12,
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
                              textColor: theme.colorScheme.onSecondaryContainer,
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
                          if (hasRepeatableActivity)
                            _PillBadge(
                              text: 'Repeat',
                              color: theme.colorScheme.secondaryContainer,
                              textColor: theme.colorScheme.onSecondaryContainer,
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
        key: ValueKey('playlist-$assignmentId-$_menuTreeVersion'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        visualDensity: VisualDensity.compact,
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
          CornerstoneIcons.playlist,
          size: 18,
          color: isPlaylistSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          journey.playlistTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isPlaylistSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${journey.completedSessionCount}/${journey.totalSessionCount}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('pathway-$pathwayKey-$_menuTreeVersion'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
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
        leading: Icon(
          CornerstoneIcons.pathway,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          pathway.pathwayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${pathway.playlistCount} playlists · ${pathway.completedSessionCount}/${pathway.totalSessionCount}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: pathway.assignedPlaylists
            .map(
              (playlist) => _buildPlaylistSection(
                theme: theme,
                assignedJourney: playlist,
                pathwayKey: pathwayKey,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLearningMenu(ThemeData theme) {
    final pathways = _assignedPathways;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSessionFilterBar(theme),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                'No assigned work yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
              CornerstoneIcons.chevronRight,
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
    final primaryExecutable = _primaryExecutableMaterial(session);
    final isRepeatableRun =
        primaryExecutable != null && session.status == 'completed';
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb(theme, session),
          const SizedBox(height: 12),
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
          if (primaryExecutable != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: primaryExecutable.canStartActivity
                  ? () => widget.onStartActivity(session, primaryExecutable)
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
              icon: CornerstoneIcons.learnerAudience,
              groups: learnerGroups,
              session: session,
              viewerCanReadLibrary: widget.viewerCanReadLibrary,
              showDocumentBodies: true,
              allowPrinting: _isSupportView,
              onOpenLibraryRoute: widget.onOpenLibraryRoute,
              onStartActivity: widget.onStartActivity,
              onSetProficiencyOverride: widget.onSetProficiencyOverride,
              onClearProficiencyOverride: widget.onClearProficiencyOverride,
            ),
          if (_isSupportView) ...[
            const SizedBox(height: 12),
            _SessionWorkspaceAudiencePanel(
              title: 'Teaching guidance',
              description:
                  'Use these notes to guide explanation and correction for this session.',
              emptyState: 'No teaching guidance is attached to this session.',
              icon: CornerstoneIcons.teachingGuidance,
              groups: adultGroups,
              session: session,
              viewerCanReadLibrary: widget.viewerCanReadLibrary,
              showDocumentBodies: true,
              allowPrinting: _isSupportView,
              onOpenLibraryRoute: widget.onOpenLibraryRoute,
              onStartActivity: widget.onStartActivity,
              onSetProficiencyOverride: widget.onSetProficiencyOverride,
              onClearProficiencyOverride: widget.onClearProficiencyOverride,
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
      return Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: ratio,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMeter(
            'Secure',
            snapshot.secureCount,
            theme.colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          buildMeter(
            'Developing',
            snapshot.developingCount,
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          buildMeter(
            'Not started',
            snapshot.notStartedCount,
            theme.colorScheme.outline,
          ),
          if (reviewItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...reviewItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.reason,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PillBadge(
                      text: item.dueDate,
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                  ],
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

        final sessionPanel = _buildSessionDetailPanel(theme, selectedSession);

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            _buildHeader(theme),
            if (_progressOpen) ...[
              const SizedBox(height: 10),
              _buildProgressPanel(theme),
            ],
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _learningMenuOpen
                  ? (useSideBySide
                        ? Row(
                            key: const ValueKey('menu-open-side'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _buildLearningMenu(theme),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: sessionPanel),
                            ],
                          )
                        : Column(
                            key: const ValueKey('menu-open-stacked'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLearningMenu(theme),
                              const SizedBox(height: 12),
                              sessionPanel,
                            ],
                          ))
                  : KeyedSubtree(
                      key: const ValueKey('menu-closed'),
                      child: sessionPanel,
                    ),
            ),
          ],
        );
      },
    );
  }
}
