part of '../../../main.dart';

class _LearnerWorkContent extends StatefulWidget {
  const _LearnerWorkContent({
    super.key,
    required this.workspace,
    required this.viewerCanReadLibrary,
    required this.onOpenLibraryRoute,
    required this.onStartActivity,
    required this.onStartReview,
    required this.onLoadPathways,
    required this.onLoadPathway,
    this.onSetReadinessOverride,
    this.onClearReadinessOverride,
    this.onCreateWorksheetForLevel,
    this.onRecordPaperResult,
    this.initialAssignmentId,
    this.onInitialAssignmentHandled,
  });
  final String? initialAssignmentId;
  final VoidCallback? onInitialAssignmentHandled;
  final LearnerWorkspacePayload workspace;
  final bool viewerCanReadLibrary;
  final ValueChanged<String> onOpenLibraryRoute;
  final Future<void> Function(SessionDetail, SessionMaterial) onStartActivity;
  final Future<void> Function(ReviewItem) onStartReview;
  final Future<void> Function(SessionMaterial)? onSetReadinessOverride;
  final Future<void> Function(SessionMaterial)? onClearReadinessOverride;
  final ValueChanged<String>? onCreateWorksheetForLevel;
  final Future<void> Function(SessionDetail)? onRecordPaperResult;
  final Future<LearnerPathwayCatalog> Function(
    String scope,
    String query,
    int page,
  )
  onLoadPathways;
  final Future<LearnerPathwayMap> Function(String pathwayId) onLoadPathway;
  @override
  State<_LearnerWorkContent> createState() => _LearnerWorkContentState();
}

class _LearnerWorkContentState extends State<_LearnerWorkContent> {
  String? _assignmentId;
  String? _sectionId;
  String? _readingId;
  String? _selectedLevelId;
  String? _pathwayId;
  LearnerPathwayMap? _pathway;
  LearnerPathwayCatalog? _catalog;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  double _homeScrollOffset = 0;
  Timer? _searchTimer;
  int _catalogRequest = 0;
  bool _catalogBusy = false;
  bool _pathwayBusy = false;
  String? _catalogError;
  String? _pathwayError;
  bool _progressOpen = false;
  bool _restored = false;
  LearnerWorkspacePayload get _data => widget.workspace;
  bool get _support => _data.workspaceView == 'owner_support';
  LearnerAssignedJourney? get _assignment => _data.assignedJourneys
      .where((a) => a.assignment.assignmentId == _assignmentId)
      .firstOrNull;
  PlaybookSection? get _section => _assignment?.sections
      .where((section) => section.sectionId == _sectionId)
      .firstOrNull;

  SessionDetail? _sessionFor(PlaybookSectionItem item) => _assignment?.sessions
      .where((session) => session.sessionId == item.sessionId)
      .firstOrNull;
  SessionMaterial? _materialFor(PlaybookSectionItem item) => _sessionFor(item)
      ?.materials
      .where((material) => material.sessionMaterialId == item.sessionMaterialId)
      .firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = PageStorage.maybeOf(context)?.readState(
      context,
      identifier: 'playbook-work-${_data.learner.learnerId}',
    );
    if (saved is Map) {
      _homeScrollOffset = saved['homeScroll'] as double? ?? 0;
      _pathwayId = saved['pathwayId'] as String?;
      _pathway = saved['pathway'] as LearnerPathwayMap?;
      _catalog = saved['catalog'] as LearnerPathwayCatalog?;
      _assignmentId = saved['assignment'] as String?;
      _sectionId = saved['section'] as String?;
      _readingId = saved['reading'] as String?;
      _selectedLevelId = saved['level'] as String?;
    }
    _catalog ??= _data.pathwayCatalog;
    _search.text = _catalog!.query;
    // Keep the browsing position, but refresh progress after an activity.
    if (saved is Map && saved['catalog'] != null) {
      _loadCatalog(_catalog!.scope, _catalog!.query, _catalog!.page);
    }
    _applyInitialAssignment();
    if (_pathwayId != null) _loadPathway(_pathwayId!);
  }

  void _applyInitialAssignment() {
    final initial = _data.assignedJourneys
        .where((a) => a.assignment.assignmentId == widget.initialAssignmentId)
        .firstOrNull;
    if (initial == null) return;
    _openAssignment(initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInitialAssignmentHandled?.call();
    });
  }

  void _change(VoidCallback change) {
    setState(change);
    if (_restored) {
      PageStorage.maybeOf(context)?.writeState(context, {
        'homeScroll': _homeScrollOffset,
        'pathwayId': _pathwayId,
        'pathway': _pathway,
        'catalog': _catalog,
        'assignment': _assignmentId,
        'section': _sectionId,
        'reading': _readingId,
        'level': _selectedLevelId,
      }, identifier: 'playbook-work-${_data.learner.learnerId}');
    }
  }

  @override
  void didUpdateWidget(covariant _LearnerWorkContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAssignmentId != widget.initialAssignmentId) {
      _applyInitialAssignment();
    }
    if (_assignmentId != null && _assignment == null) {
      _assignmentId = null;
      _readingId = null;
    }
    if (oldWidget.workspace != widget.workspace) {
      if (_pathwayId != null) _loadPathway(_pathwayId!);
      final catalog = _catalog ?? _data.pathwayCatalog;
      _loadCatalog(catalog.scope, catalog.query, catalog.page);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog(String scope, String query, int page) async {
    final request = ++_catalogRequest;
    setState(() {
      _catalogBusy = true;
      _catalogError = null;
    });
    try {
      final catalog = await widget.onLoadPathways(scope, query, page);
      if (!mounted || request != _catalogRequest) return;
      _change(() {
        _catalog = catalog;
        _catalogBusy = false;
      });
    } catch (_) {
      if (mounted && request == _catalogRequest) {
        setState(() {
          _catalogBusy = false;
          _catalogError = 'The pathways could not be loaded. Try again.';
        });
      }
    }
  }

  void _searchPathways(String query) {
    _searchTimer?.cancel();
    ++_catalogRequest;
    setState(() {});
    _searchTimer = Timer(
      const Duration(milliseconds: 300),
      () => _loadCatalog(_catalog!.scope, query, 1),
    );
  }

  Future<void> _loadPathway(String id) async {
    setState(() {
      _pathwayBusy = true;
      _pathwayError = null;
    });
    try {
      final path = await widget.onLoadPathway(id);
      if (!mounted || _pathwayId != id) return;
      _change(() {
        _pathway = path;
        _pathwayBusy = false;
      });
    } catch (_) {
      if (mounted && _pathwayId == id) {
        setState(() {
          _pathwayBusy = false;
          _pathwayError = 'This pathway could not be loaded. Try again.';
        });
      }
    }
  }

  void _rememberHomePosition() {
    if (_pathwayId == null && _assignmentId == null && _scroll.hasClients) {
      _homeScrollOffset = _scroll.offset;
    }
  }

  void _scrollTo(double offset) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
        }
      });

  void _openPathway(String id) {
    _rememberHomePosition();
    _scrollTo(0);
    _change(() {
      _pathwayId = id;
      _pathway = null;
      _assignmentId = null;
      _readingId = null;
    });
    _loadPathway(id);
  }

  void _openAssignmentById(String id) {
    final assigned = _data.assignedJourneys
        .where((a) => a.assignment.assignmentId == id)
        .firstOrNull;
    if (assigned != null) _openAssignment(assigned);
  }

  void _home() {
    _change(() {
      _assignmentId = null;
      _pathwayId = null;
      _pathway = null;
      _readingId = null;
    });
    _scrollTo(_homeScrollOffset);
  }

  void _openAssignment(
    LearnerAssignedJourney assignment, {
    bool resume = false,
  }) {
    _rememberHomePosition();
    _scrollTo(0);
    var section = assignment.sections.firstOrNull;
    String? reading;
    if (resume) {
      final next = assignment.continueBlock?.session.nextStep;
      section =
          assignment.sections
              .where(
                (section) => section.items.any(
                  (item) => item.sessionMaterialId == next?.sessionMaterialId,
                ),
              )
              .firstOrNull ??
          section;
      if (next?.actionKind == 'open_material') {
        reading = next?.sessionMaterialId;
      }
    }
    _change(() {
      _pathwayId = assignment.journey.pathwayId;
      if (_pathway?.summary.pathwayId != _pathwayId) _pathway = null;
      _assignmentId = assignment.assignment.assignmentId;
      _sectionId = section?.sectionId;
      _readingId = reading;
      _progressOpen = false;
    });
    if (_pathwayId != null && _pathway == null) _loadPathway(_pathwayId!);
  }

  void _selectSection(String id) => _change(() {
    _sectionId = id;
    _selectedLevelId = null;
    _readingId = null;
  });

  Widget _panel(Widget child, {bool emphasized = false}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: emphasized
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .45)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _status(String label) =>
      Text(label, style: Theme.of(context).textTheme.bodySmall);

  Widget _assignedWork() {
    final theme = Theme.of(context);
    final currentId = _data.workspace.continueBlock?.session.sessionId;
    final current = _data.assignedJourneys
        .where((a) => a.sessions.any((s) => s.sessionId == currentId))
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONTINUE LEARNING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  current.journey.pathwayTitle ?? 'Your next playbook',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  current.journey.title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  current.continueBlock?.session.nextStep?.instruction ??
                      'Open your playbook to learn, practise or take a checkpoint.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('continue-learning'),
                  onPressed: () => _openAssignment(current, resume: true),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Continue learning'),
                ),
              ],
            ),
            emphasized: true,
          ),
          const SizedBox(height: 28),
        ],
        if (_data.assignedJourneys.isEmpty) ...[
          _panel(
            Text(
              _support
                  ? 'Choose a playbook from the library to start this learner’s journey.'
                  : 'Your teacher will choose your first playbook. You can explore the pathways below.',
            ),
          ),
          const SizedBox(height: 24),
        ],
        _LearnerPathwayBrowser(
          catalog: _catalog ?? _data.pathwayCatalog,
          search: _search,
          busy: _catalogBusy,
          error: _catalogError,
          onSearch: _searchPathways,
          onScope: (scope) {
            _searchTimer?.cancel();
            _loadCatalog(scope, _search.text, 1);
          },
          onPage: (page) => _loadCatalog(_catalog!.scope, _search.text, page),
          onOpen: _openPathway,
        ),
      ],
    );
  }

  Widget _materialActions(
    SessionDetail session,
    SessionMaterial material, {
    bool reading = false,
  }) {
    final checkpoint = _sectionId == 'checkpoint';
    final locked = !(material.gate?.enabled ?? true);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (material.isExecutable)
          FilledButton.icon(
            key: ValueKey('start-${material.sessionMaterialId}'),
            onPressed: material.canStartActivity
                ? () => widget.onStartActivity(session, material)
                : null,
            icon: Icon(
              checkpoint ? Icons.flag_outlined : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              checkpoint
                  ? 'Take checkpoint'
                  : material.status == SessionMaterialStatus.completed
                  ? 'Practise again'
                  : 'Start practice',
            ),
          ),
        if (!reading && (material.documentBody ?? '').isNotEmpty)
          OutlinedButton.icon(
            onPressed: locked
                ? null
                : () => _change(() => _readingId = material.sessionMaterialId),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(material.isExecutable ? 'Instructions' : 'Read'),
          ),
        if (material.activityLevelId != null &&
            widget.onCreateWorksheetForLevel != null)
          OutlinedButton.icon(
            key: ValueKey('fresh-print-${material.materialId}'),
            onPressed: () =>
                widget.onCreateWorksheetForLevel!(material.activityLevelId!),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print fresh questions'),
          ),
        if (material.printable &&
            learningMaterialPrintingSupported &&
            (reading ||
                !material.isExecutable ||
                material.activityLevelId == null ||
                widget.onCreateWorksheetForLevel == null))
          OutlinedButton.icon(
            onPressed: locked
                ? null
                : () => _runPrintAction(
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
            label: Text(material.isExecutable ? 'Print instructions' : 'Print'),
          ),
        if (_support &&
            checkpoint &&
            !material.isExecutable &&
            widget.onRecordPaperResult != null)
          FilledButton.tonalIcon(
            onPressed: () => widget.onRecordPaperResult!(session),
            icon: const Icon(Icons.task_alt, size: 18),
            label: const Text('Record paper result'),
          ),
        if (_support && material.readiness != null)
          TextButton.icon(
            onPressed: () => _showReadiness(material),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Practice target'),
          ),
      ],
    );
  }

  Widget _practiceMaterials(List<PlaybookSectionItem> items) {
    final levels = items
        .where((item) => _materialFor(item)!.isExecutable)
        .toList();
    final selected =
        levels
            .where((item) => item.materialId == _selectedLevelId)
            .firstOrNull ??
        levels.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (levels.length > 1 && selected != null)
          _PracticeLevelPicker(
            levels: [
              for (final item in levels)
                (
                  id: item.materialId,
                  title: _materialFor(item)!.title,
                  status:
                      _materialFor(item)!.status ==
                          SessionMaterialStatus.completed
                      ? (_sectionId == 'checkpoint' ? 'Passed' : 'Practised')
                      : null,
                ),
            ],
            selectedId: selected.materialId,
            onSelected: (id) => _change(() => _selectedLevelId = id),
            detail: _materialCard(selected),
          )
        else if (selected != null)
          _materialCard(selected),
        for (final item in items.where(
          (item) => !_materialFor(item)!.isExecutable,
        ))
          if (_sectionId == 'practice')
            ExpansionTile(
              title: Text(_materialFor(item)!.title),
              tilePadding: EdgeInsets.zero,
              children: [_materialCard(item)],
            )
          else
            _materialCard(item),
      ],
    );
  }

  Widget _materialCard(PlaybookSectionItem item) {
    final session = _sessionFor(item);
    final material = _materialFor(item);
    if (session == null || material == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              material.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (material.checkpointPolicy != null)
              _CheckpointConditions(policy: material.checkpointPolicy!),
            const SizedBox(height: 6),
            if (material.readiness != null)
              _status(material.readiness!.detailLabel),
            if (material.gate?.enabled == false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  material.gate!.reasonLabel,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (material.status == SessionMaterialStatus.completed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _status('Previous attempt recorded'),
              ),
            const SizedBox(height: 14),
            _materialActions(session, material),
          ],
        ),
      ),
    );
  }

  Widget _reader(PlaybookSectionItem item) {
    final session = _sessionFor(item)!;
    final material = _materialFor(item)!;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _materialActions(session, material, reading: true),
              if (_readingId != null &&
                  _sectionId != 'learn' &&
                  _sectionId != 'teach')
                TextButton.icon(
                  onPressed: () => _change(() => _readingId = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close reading'),
                ),
            ],
          ),
          const Divider(height: 32),
          SelectionArea(
            child: MarkdownBody(
              data: material.documentBody ?? '',
              selectable: true,
              styleSheet: _workspaceMarkdownStyle(Theme.of(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playbook() {
    final assignment = _assignment!;
    final section = _section;
    final items =
        section?.items.where((item) => _materialFor(item) != null).toList() ??
        <PlaybookSectionItem>[];
    final explicitReading = items
        .where((item) => item.sessionMaterialId == _readingId)
        .firstOrNull;
    final reading =
        explicitReading ??
        ((_sectionId == 'learn' || _sectionId == 'teach')
            ? items
                  .where(
                    (item) =>
                        (_materialFor(item)?.documentBody ?? '').isNotEmpty,
                  )
                  .firstOrNull
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          assignment.journey.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        _status(
          '${assignment.assignment.completedCheckpointCount} of ${assignment.assignment.checkpointCount} checkpoints complete',
        ),
        const SizedBox(height: 20),
        _PlaybookSectionTabs(
          sections: assignment.sections,
          selectedId: _sectionId ?? '',
          onSelected: _selectSection,
        ),
        const SizedBox(height: 24),
        if (section != null) ...[
          Text(
            section.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            _panel(const Text('No additional material is needed here.')),
          if (reading != null) ...[
            if (items.length > 1 &&
                (_sectionId == 'learn' || _sectionId == 'teach'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      ChoiceChip(
                        label: Text(_materialFor(item)!.title),
                        selected:
                            reading.sessionMaterialId == item.sessionMaterialId,
                        onSelected: (_) =>
                            _change(() => _readingId = item.sessionMaterialId),
                      ),
                  ],
                ),
              ),
            _reader(reading),
          ] else
            _practiceMaterials(items),
        ],
      ],
    );
  }

  String get _playbookPositionLabel {
    final path = _pathway;
    final assignment = _assignment;
    if (path == null || assignment == null) return 'Playbook';
    final index = path.playbooks.indexWhere(
      (p) => p.playlistId == assignment.assignment.playlistId,
    );
    return index < 0
        ? 'Playbook'
        : 'Playbook ${index + 1} of ${path.playbooks.length}';
  }

  Widget _trail() => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        TextButton.icon(
          key: const ValueKey('learning-home'),
          onPressed: _home,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('My learning'),
        ),
        if (_pathwayId != null) ...[
          const Icon(Icons.chevron_right, size: 14),
          TextButton(
            onPressed: _assignment == null
                ? null
                : () => _change(() {
                    _assignmentId = null;
                    _readingId = null;
                    _scrollTo(0);
                  }),
            child: Text(
              _pathway?.summary.title ??
                  _assignment?.journey.pathwayTitle ??
                  'Pathway',
            ),
          ),
        ],
        if (_assignment != null) ...[
          const Icon(Icons.chevron_right, size: 14),
          Text(
            _playbookPositionLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  Widget _pathwayPage() {
    final theme = Theme.of(context);
    final path = _pathway;
    if (_pathwayError != null) {
      return _InlineBrowseError(
        message: _pathwayError!,
        onRetry: () => _loadPathway(_pathwayId!),
      );
    }
    if (path == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LEARNING PATHWAY',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(path.summary.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(path.summary.description, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(path.summary.progressLabel)),
            Text(
              '${path.summary.assignedPlaybookCount} assigned',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: path.summary.completionPercent / 100,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 30),
        Text('One playbook at a time', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Open your assigned work. The quieter steps show the rest of this pathway.',
        ),
        const SizedBox(height: 24),
        _LearningPathwayMap(
          pathway: path,
          onOpenAssignment: _openAssignmentById,
        ),
      ],
    );
  }

  Widget _playbookWithPathway() => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 1000 || _pathway == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pathwayBusy) const LinearProgressIndicator(),
            if (_pathwayError != null)
              _InlineBrowseError(
                message: _pathwayError!,
                onRetry: () => _loadPathway(_pathwayId!),
              ),
            _playbook(),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IN THIS PATHWAY',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 16),
                _LearningPathwayMap(
                  pathway: _pathway!,
                  onOpenAssignment: _openAssignmentById,
                  selectedPlaylistId: _assignment!.assignment.playlistId,
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(child: _playbook()),
        ],
      );
    },
  );

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
  Widget build(BuildContext context) => ListView(
    controller: _scroll,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 28),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _support
                      ? '${_data.learner.displayName}’s learning'
                      : 'My learning',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                _status(
                  _support
                      ? 'Viewing learner work · owner profile'
                      : _data.learner.displayName,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _progressOpen ? 'Close progress' : 'Progress and review',
            onPressed: () => _change(() => _progressOpen = !_progressOpen),
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (_progressOpen)
        _progressPanel()
      else ...[
        if (_pathwayId != null || _assignment != null) _trail(),
        if (_assignment != null)
          _playbookWithPathway()
        else if (_pathwayId != null)
          _pathwayPage()
        else
          _assignedWork(),
      ],
      const SizedBox(height: 32),
    ],
  );
}
