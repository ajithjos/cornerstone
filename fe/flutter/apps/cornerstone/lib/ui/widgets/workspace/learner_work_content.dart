part of '../../../main.dart';

class _LearnerWorkContent extends StatefulWidget {
  const _LearnerWorkContent({
    super.key,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
    required this.onStartReview,
    this.onSetReadinessOverride,
    this.onClearReadinessOverride,
  });

  final LearnerWorkspacePayload workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail session, SessionMaterial material)
  onStartActivity;
  final Future<void> Function(ReviewItem reviewItem) onStartReview;
  final Future<void> Function(SessionMaterial material)? onSetReadinessOverride;
  final Future<void> Function(SessionMaterial material)?
  onClearReadinessOverride;

  @override
  State<_LearnerWorkContent> createState() => _LearnerWorkContentState();
}

class _LearnerWorkContentState extends State<_LearnerWorkContent> {
  String? _selectedSessionId;
  String? _selectedAssignmentId;
  String? _readingMaterialId;
  String? _expandedPathwayId;
  bool _browseOpen = false;
  bool _progressOpen = false;
  final _sessionKey = GlobalKey();
  final _readingKey = GlobalKey();
  final _progressKey = GlobalKey();

  LearnerWorkspacePayload get _data => widget.workspace;
  bool get _support => _data.workspaceView == 'owner_support';
  LearnerContinueBlock? get _continue => _data.workspace.continueBlock;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = _continue?.session.sessionId;
    _selectedAssignmentId = _assignmentFor(
      _selectedSessionId,
    )?.assignment.assignmentId;
  }

  @override
  void didUpdateWidget(covariant _LearnerWorkContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousCurrent =
        oldWidget.workspace.workspace.continueBlock?.session.sessionId;
    final followCurrent =
        _selectedSessionId == previousCurrent && _readingMaterialId == null;
    if (followCurrent ||
        (_selectedSessionId != null &&
            _findSession(_selectedSessionId) == null)) {
      _selectedSessionId = _continue?.session.sessionId;
      _selectedAssignmentId = _assignmentFor(
        _selectedSessionId,
      )?.assignment.assignmentId;
      _readingMaterialId = null;
    }
  }

  SessionDetail? _findSession(String? id) {
    if (id == null) return null;
    for (final session in _data.sessions) {
      if (session.sessionId == id) return session;
    }
    for (final assignment in _data.assignedJourneys) {
      for (final session in assignment.sessions) {
        if (session.sessionId == id) return session;
      }
    }
    return _continue?.session.sessionId == id ? _continue?.session : null;
  }

  LearnerAssignedJourney? _assignmentFor(String? sessionId) {
    if (sessionId == null) return null;
    return _data.assignedJourneys
        .where(
          (item) =>
              item.sessions.any((session) => session.sessionId == sessionId),
        )
        .firstOrNull;
  }

  LearnerAssignedJourney? get _selectedAssignment => _data.assignedJourneys
      .where((item) => item.assignment.assignmentId == _selectedAssignmentId)
      .firstOrNull;

  SessionDetail? get _selectedSession => _findSession(_selectedSessionId);

  List<SessionMaterial> _visibleMaterials(SessionDetail session) => session
      .materials
      .where((item) => item.isLearnerFacing || (_support && item.isAdultFacing))
      .toList(growable: false);

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 220),
          alignment: 0.04,
        );
      }
    });
  }

  void _selectSession(SessionDetail session, {bool closeBrowse = false}) {
    setState(() {
      _selectedSessionId = session.sessionId;
      _selectedAssignmentId = _assignmentFor(
        session.sessionId,
      )?.assignment.assignmentId;
      _readingMaterialId = null;
      if (closeBrowse) _browseOpen = false;
    });
    _scrollTo(_sessionKey);
  }

  void _selectAssignment(LearnerAssignedJourney assignment) {
    setState(() {
      _selectedAssignmentId = assignment.assignment.assignmentId;
      _selectedSessionId = assignment.currentSessionId;
      _readingMaterialId = null;
    });
    _scrollTo(_sessionKey);
  }

  void _openMaterial(SessionDetail session, SessionMaterial material) {
    if (!(material.gate?.enabled ?? true)) return;
    setState(() {
      _selectedSessionId = session.sessionId;
      _selectedAssignmentId = _assignmentFor(
        session.sessionId,
      )?.assignment.assignmentId;
      _readingMaterialId = material.sessionMaterialId;
    });
    _scrollTo(_readingKey);
  }

  void _performNextStep(SessionDetail session) {
    final step = session.nextStep;
    if (step == null) {
      _selectSession(session);
      return;
    }
    if (!step.enabled) return;
    final material = _visibleMaterials(session)
        .where((item) => item.sessionMaterialId == step.sessionMaterialId)
        .firstOrNull;
    if (material == null) {
      _selectSession(session);
      return;
    }
    if (step.actionKind == 'start_activity') {
      widget.onStartActivity(session, material);
    } else {
      _openMaterial(session, material);
    }
  }

  Widget _panel(Widget child, {bool emphasized = false}) {
    final theme = Theme.of(context);
    return Material(
      color: emphasized
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: emphasized
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  String _materialRole(SessionMaterial material) => switch (material.kind) {
    'lesson_note' => 'Learn',
    'teaching_note' => 'Parent guidance',
    'quick_check' => 'Check',
    'worksheet' || 'drill' => 'Practise',
    _ => _materialKindLabel(material.kind),
  };

  Widget _status(String label) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _continueCard() {
    final theme = Theme.of(context);
    final block = _continue;
    if (block == null) {
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _data.assignedJourneys.isEmpty
                  ? 'No work assigned yet'
                  : 'Choose something to revisit',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _data.assignedJourneys.isEmpty
                  ? (_support
                        ? 'Choose a playlist or material in Learning library for ${_data.learner.displayName}.'
                        : 'Your parent or teacher will choose your first lesson and practice.')
                  : 'Open an assigned session below, or visit Progress & review.',
            ),
          ],
        ),
      );
    }
    final session = block.session;
    final assignment = _assignmentFor(session.sessionId);
    final step = session.nextStep;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue learning',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (assignment != null) ...[
            const SizedBox(height: 6),
            _status(
              [
                if ((assignment.journey.pathwayTitle ?? '').isNotEmpty)
                  assignment.journey.pathwayTitle!,
                assignment.journey.title,
              ].join('  ›  '),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            step?.instruction ?? block.description,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const ValueKey('continue-learning'),
                onPressed: step?.enabled == false
                    ? null
                    : () => _performNextStep(session),
                icon: Icon(
                  step?.actionKind == 'start_activity'
                      ? Icons.play_arrow_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(step?.actionLabel ?? 'Open session'),
              ),
              TextButton(
                onPressed: () => _selectSession(session),
                child: const Text('View session'),
              ),
              if (session.estimatedMinutes > 0)
                _status('About ${session.estimatedMinutes} minutes'),
            ],
          ),
        ],
      ),
      emphasized: true,
    );
  }

  Widget _breadcrumb(
    SessionDetail? session,
    LearnerAssignedJourney? assignment,
  ) {
    final theme = Theme.of(context);
    final journey = assignment?.journey;
    final pieces = <Widget>[
      TextButton(
        onPressed: () {
          final current = _continue?.session;
          if (current != null) _selectSession(current);
        },
        child: Text(_support ? 'Student work' : 'My work'),
      ),
      if ((journey?.pathwayTitle ?? '').isNotEmpty)
        TextButton(
          onPressed: () => setState(() {
            _browseOpen = true;
            _expandedPathwayId = journey.pathwayId;
          }),
          child: Text(journey!.pathwayTitle!),
        ),
      if (assignment != null)
        TextButton(
          onPressed: () => _selectAssignment(assignment),
          child: Text(journey!.title),
        ),
      if (session != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            session.sequenceNumber == null
                ? 'Session'
                : 'Session ${session.sequenceNumber}',
            style: theme.textTheme.labelLarge,
          ),
        ),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        for (var i = 0; i < pieces.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          pieces[i],
        ],
      ],
    );
  }

  Widget _sessionPanel() {
    final theme = Theme.of(context);
    final session = _selectedSession;
    final assignment = _selectedAssignment;
    if (session == null) {
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assignment != null) ...[
              _breadcrumb(null, assignment),
              Text(assignment.journey.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              _status(assignment.journey.sourceLabel),
              const SizedBox(height: 12),
              for (final item in assignment.sessions) _sessionLink(item),
            ] else ...[
              Text('Your session', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Choose a session from Assigned learning to see its lesson and practice.',
              ),
            ],
          ],
        ),
      );
    }
    final materials = _visibleMaterials(session);
    final reading = materials
        .where((item) => item.sessionMaterialId == _readingMaterialId)
        .firstOrNull;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _breadcrumb(session, assignment),
          const SizedBox(height: 6),
          Text(
            session.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _status(
            [
              session.status.label,
              if (session.estimatedMinutes > 0)
                '${session.estimatedMinutes} min',
              if (session.requiresAdultSupport) 'With adult support',
              if (assignment != null) assignment.journey.sourceLabel,
            ].join(' · '),
          ),
          const SizedBox(height: 20),
          Text('In this session', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          if (materials.isEmpty)
            const Text('The materials for this session are not available yet.')
          else
            for (var i = 0; i < materials.length; i++)
              _materialRow(session, materials[i], i + 1),
          if (reading != null) ...[
            const SizedBox(height: 20),
            Container(key: _readingKey, child: _readingPanel(session, reading)),
          ],
          if (assignment != null && assignment.sessions.length > 1) ...[
            const Divider(height: 32),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Other sessions in this playlist'),
                subtitle: Text(
                  '${assignment.journey.completedSessionCount} of ${assignment.journey.totalSessionCount} sessions finished',
                ),
                children: [
                  for (final item in assignment.sessions) _sessionLink(item),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _materialRow(
    SessionDetail session,
    SessionMaterial material,
    int number,
  ) {
    final theme = Theme.of(context);
    final next =
        session.nextStep?.sessionMaterialId == material.sessionMaterialId;
    final locked = !(material.gate?.enabled ?? true);
    final reading = _readingMaterialId == material.sessionMaterialId;
    final canRead =
        !locked &&
        (material.documentBody ?? '').trim().isNotEmpty &&
        (!material.isExecutable || _support);
    final repeat = material.status == SessionMaterialStatus.completed;
    final action = material.isExecutable
        ? _materialActionLabel(material.kind, repeat: repeat)
        : _materialDocumentActionLabel(material.kind);
    return Container(
      key: ValueKey('session-step-${material.sessionMaterialId}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: reading
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
            : next
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
            : null,
        border: Border.all(
          color: next
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text('$number', style: theme.textTheme.titleMedium),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _materialRole(material),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(material.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    _status(
                      [
                        if (next) 'Next step',
                        if (material.estimatedMinutes > 0)
                          '${material.estimatedMinutes} min',
                        if (repeat) 'Finished',
                        if (material.readiness != null)
                          material.readiness!.statusLabel,
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              if (locked)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.lock_outline_rounded, size: 19),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (material.isExecutable)
                FilledButton.tonalIcon(
                  onPressed: material.canStartActivity
                      ? () => widget.onStartActivity(session, material)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(action),
                )
              else
                OutlinedButton.icon(
                  onPressed: canRead
                      ? () => _openMaterial(session, material)
                      : null,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(action),
                ),
              if (material.isExecutable && canRead)
                TextButton(
                  onPressed: () => _openMaterial(session, material),
                  child: const Text('Activity notes'),
                ),
              if (_support && material.readiness != null)
                TextButton.icon(
                  onPressed: () => _showReadiness(material),
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Practice target'),
                ),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 6),
            Text(
              material.gate!.reasonLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readingPanel(SessionDetail session, SessionMaterial material) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(material.title, style: theme.textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => setState(() => _readingMaterialId = null),
              tooltip: 'Close material and return to session',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectionArea(
          child: MarkdownBody(
            data: material.documentBody ?? '',
            selectable: true,
            styleSheet: _workspaceMarkdownStyle(theme),
          ),
        ),
        const SizedBox(height: 12),
        if (_support && !material.isExecutable) ...[
          _status('Record completed paper work in Learners.'),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() => _readingMaterialId = null);
                _scrollTo(_sessionKey);
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to session'),
            ),
            if (_support &&
                material.printable &&
                learningMaterialPrintingSupported)
              OutlinedButton.icon(
                onPressed: () => _runPrintAction(
                  context,
                  () => printLearningMaterial(
                    _learningMaterialPrintPayload(
                      session: session,
                      material: material,
                      body: material.documentBody ?? '',
                    ),
                  ),
                ),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
              ),
            if (widget.viewerCanReadLibrary &&
                material.documentRoutePath != null)
              TextButton(
                onPressed: () =>
                    widget.onOpenLibraryRoute(material.documentRoutePath!),
                child: const Text('Open reference page'),
              ),
          ],
        ),
      ],
    );
  }

  void _showReadiness(SessionMaterial material) {
    final readiness = material.readiness;
    if (readiness == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Practice target · ${material.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(readiness.statusLabel),
              const SizedBox(height: 8),
              Text(readiness.detailLabel),
              if (readiness.overrideReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(readiness.overrideReason),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (readiness.overrideApplied &&
              widget.onClearReadinessOverride != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onClearReadinessOverride!(material);
              },
              child: const Text('Use default target'),
            ),
          if (widget.onSetReadinessOverride != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onSetReadinessOverride!(material);
              },
              child: Text(
                readiness.overrideApplied ? 'Edit target' : 'Set target',
              ),
            ),
        ],
      ),
    );
  }

  Widget _sessionLink(SessionDetail session, {bool closeBrowse = false}) =>
      ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        selected: session.sessionId == _selectedSessionId,
        leading: Icon(
          session.status == SessionStatus.completed
              ? Icons.check_circle_outline_rounded
              : Icons.circle_outlined,
          size: 18,
        ),
        title: Text(
          session.sequenceNumber == null
              ? session.title
              : '${session.sequenceNumber}. ${session.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: session.sessionId == _continue?.session.sessionId
            ? const Text('Continue here')
            : null,
        onTap: () => _selectSession(session, closeBrowse: closeBrowse),
      );

  Widget _assignmentOutline(
    LearnerAssignedJourney assignment, {
    required bool narrow,
  }) {
    final current = assignment.assignment.assignmentId == _selectedAssignmentId;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey(
          'learning-assignment-${assignment.assignment.assignmentId}-$current',
        ),
        initiallyExpanded: current,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 12),
        title: Text(
          assignment.journey.title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          '${assignment.journey.sourceLabel} · ${assignment.journey.completedSessionCount}/${assignment.journey.totalSessionCount} sessions finished',
        ),
        children: [
          for (final session in assignment.sessions)
            _sessionLink(session, closeBrowse: narrow),
        ],
      ),
    );
  }

  Widget _assignedLearning({required bool narrow}) {
    final theme = Theme.of(context);
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _browseOpen ? 'Browse learning' : 'Assigned learning',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_data.assignedPathways.isEmpty && _data.assignedJourneys.isEmpty)
            const Text('Assigned lessons and practice will appear here.'),
          for (final pathway in _data.assignedPathways)
            if (_browseOpen)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey(
                    'learning-pathway-${pathway.pathwayId}-${_expandedPathwayId == pathway.pathwayId}',
                  ),
                  initiallyExpanded: _expandedPathwayId == pathway.pathwayId,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    pathway.pathwayTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(pathway.summaryLabel),
                  children: [
                    for (final assignment in pathway.assignments)
                      _assignmentOutline(assignment, narrow: narrow),
                  ],
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  pathway.pathwayTitle,
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  '${pathway.summaryLabel}\n${pathway.completedSessionCount}/${pathway.totalSessionCount} sessions finished',
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => setState(() {
                  _browseOpen = true;
                  _expandedPathwayId = pathway.pathwayId;
                }),
              ),
          if (_data.assignedPathways.isEmpty)
            for (final assignment in _data.assignedJourneys)
              _browseOpen
                  ? _assignmentOutline(assignment, narrow: narrow)
                  : ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(assignment.journey.title),
                      subtitle: Text(assignment.journey.sourceLabel),
                      onTap: () => _selectAssignment(assignment),
                    ),
          if (!_browseOpen && _data.assignedJourneys.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => setState(() => _browseOpen = true),
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Browse learning'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progressPanel() {
    final theme = Theme.of(context);
    final snapshot = _data.workspace.progressSnapshot;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress & review', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text('${snapshot.confirmedCount} skills confirmed'),
              Text('${snapshot.readyForCheckCount} ready for a check'),
              Text('${snapshot.needsPracticeCount} need practice'),
              Text('${snapshot.completedSessionCount} sessions finished'),
            ],
          ),
          if (_data.reviewItems.isNotEmpty) ...[
            const Divider(height: 28),
            Text('Review practice', style: theme.textTheme.titleMedium),
            for (final review in _data.reviewItems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(review.reason),
                trailing: TextButton(
                  onPressed: review.reviewStatus == ReviewStatus.due
                      ? () => widget.onStartReview(review)
                      : null,
                  child: Text(review.actionLabel),
                ),
              ),
          ],
          if (_data.practiceMastery.isNotEmpty) ...[
            const Divider(height: 28),
            PracticeMasteryPanel(
              practiceMastery: _data.practiceMastery,
              compact: true,
            ),
          ],
          if (_data.workspace.recentWins.isNotEmpty) ...[
            const Divider(height: 28),
            Text('Recent work', style: theme.textTheme.titleMedium),
            for (final result in _data.workspace.recentWins.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(result.sessionTitle),
                subtitle: Text(result.scoreLabel),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final assigned = _assignedLearning(narrow: !wide);
        final session = Container(key: _sessionKey, child: _sessionPanel());
        return ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _support
                          ? '${_data.learner.displayName}’s work'
                          : 'My work',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_support) ...[
                      const SizedBox(height: 4),
                      Text(
                        _data.learner.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _browseOpen = !_browseOpen),
                  icon: Icon(
                    _browseOpen
                        ? Icons.close_rounded
                        : Icons.account_tree_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _browseOpen ? 'Close learning outline' : 'Browse learning',
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _progressOpen = !_progressOpen);
                    if (_progressOpen) _scrollTo(_progressKey);
                  },
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Progress & review'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _continueCard(),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: assigned),
                  const SizedBox(width: 20),
                  Expanded(child: session),
                ],
              )
            else ...[
              if (_browseOpen) ...[assigned, const SizedBox(height: 16)],
              session,
              if (!_browseOpen) ...[const SizedBox(height: 16), assigned],
            ],
            if (_progressOpen) ...[
              const SizedBox(height: 20),
              Container(key: _progressKey, child: _progressPanel()),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
