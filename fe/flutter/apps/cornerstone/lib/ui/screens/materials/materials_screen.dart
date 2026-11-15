part of '../../../main.dart';

enum _LibraryScope {
  overview,
  pathway,
  playlist,
  session,
  extraPractice,
  material,
  document,
}

class MaterialsWorkspaceView extends StatefulWidget {
  const MaterialsWorkspaceView({
    super.key,
    required this.library,
    required this.documents,
    required this.activeDocument,
    required this.documentBusy,
    required this.canAssign,
    required this.onAssignMaterial,
    required this.onAssignPlaylist,
    required this.onOpenDocument,
    required this.onCreateWorksheet,
    this.requestedPreviewRoute,
    this.onPreviewRequestHandled,
  });
  final LibraryWorkspacePayload library;
  final LibraryDocumentsPayload? documents;
  final LibraryDocumentData? activeDocument;
  final bool documentBusy;
  final bool canAssign;
  final ValueChanged<LibraryCatalogMaterial> onAssignMaterial;
  final ValueChanged<LibraryWorkspacePlaylist> onAssignPlaylist;
  final ValueChanged<String> onOpenDocument;
  final VoidCallback onCreateWorksheet;
  final String? requestedPreviewRoute;
  final VoidCallback? onPreviewRequestHandled;
  @override
  State<MaterialsWorkspaceView> createState() => _MaterialsWorkspaceViewState();
}

class _MaterialsWorkspaceViewState extends State<MaterialsWorkspaceView> {
  final _search = TextEditingController();
  _LibraryScope _scope = _LibraryScope.overview;
  String? _pathwayId;
  String? _playlistId;
  int? _sessionIndex;
  String? _materialId;
  String? _previewRoute;
  String? _kindFilter;
  String? _extraGroupTitle;
  _LibraryScope _previewOrigin = _LibraryScope.overview;
  bool _searching = false;
  bool _restored = false;
  bool _previewRequestScheduled = false;

  LibraryWorkspacePathway? get _pathway => widget.library.pathways
      .where((item) => item.pathwayId == _pathwayId)
      .firstOrNull;
  LibraryWorkspacePlaylist? get _playlist => _pathway?.playlists
      .where((item) => item.playlistId == _playlistId)
      .firstOrNull;
  LibraryWorkspaceSession? get _session => _playlist?.sessions
      .where((item) => item.sessionIndex == _sessionIndex)
      .firstOrNull;
  LibraryCatalogMaterial? _catalog(String id) => widget.library.materials
      .where((item) => item.materialId == id)
      .firstOrNull;
  LibraryCatalogMaterial? get _material =>
      _materialId == null ? null : _catalog(_materialId!);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: 'learning-library-selection');
    if (saved is Map) {
      _pathwayId = saved['pathway'] as String?;
      _playlistId = saved['playlist'] as String?;
      _sessionIndex = saved['session'] as int?;
      _materialId = saved['material'] as String?;
      _previewRoute = saved['preview'] as String?;
      _extraGroupTitle = saved['extra_group'] as String?;
      _previewOrigin =
          _LibraryScope.values
              .where((value) => value.name == saved['origin'])
              .firstOrNull ??
          _LibraryScope.overview;
      _scope =
          _LibraryScope.values
              .where((value) => value.name == saved['scope'])
              .firstOrNull ??
          _LibraryScope.overview;
      if (_pathwayId != null && _pathway == null) {
        _scope = _LibraryScope.overview;
      }
    }
    _applyPreviewRequest();
  }

  @override
  void didUpdateWidget(covariant MaterialsWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestedPreviewRoute != widget.requestedPreviewRoute) {
      _applyPreviewRequest();
    }
  }

  void _applyPreviewRequest() {
    final route = widget.requestedPreviewRoute;
    if (route == null || _previewRequestScheduled) return;
    _previewRequestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewRequestScheduled = false;
      if (!mounted) return;
      widget.onPreviewRequestHandled?.call();
      _openDocument(route);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback action) {
    setState(action);
    PageStorage.maybeOf(context)?.writeState(context, {
      'pathway': _pathwayId,
      'playlist': _playlistId,
      'session': _sessionIndex,
      'material': _materialId,
      'preview': _previewRoute,
      'scope': _scope.name,
      'extra_group': _extraGroupTitle,
      'origin': _previewOrigin.name,
    }, identifier: 'learning-library-selection');
  }

  void _overview() => _change(() {
    _scope = _LibraryScope.overview;
    _searching = false;
    _pathwayId = null;
    _playlistId = null;
    _sessionIndex = null;
    _materialId = null;
  });
  void _selectPathway(LibraryWorkspacePathway pathway) => _change(() {
    _pathwayId = pathway.pathwayId;
    _playlistId = null;
    _sessionIndex = null;
    _materialId = null;
    _scope = _LibraryScope.pathway;
    _searching = false;
  });
  void _selectPlaylist(
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
  ) => _change(() {
    _pathwayId = pathway.pathwayId;
    _playlistId = playlist.playlistId;
    _sessionIndex = null;
    _materialId = null;
    _scope = _LibraryScope.playlist;
    _searching = false;
  });
  void _selectSession(
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
    LibraryWorkspaceSession session,
  ) => _change(() {
    _pathwayId = pathway.pathwayId;
    _playlistId = playlist.playlistId;
    _sessionIndex = session.sessionIndex;
    _materialId = null;
    _scope = _LibraryScope.session;
    _searching = false;
  });
  void _extra(LibraryWorkspacePathway pathway, [String? groupTitle]) =>
      _change(() {
        _pathwayId = pathway.pathwayId;
        _playlistId = null;
        _sessionIndex = null;
        _materialId = null;
        _extraGroupTitle = groupTitle;
        _scope = _LibraryScope.extraPractice;
        _searching = false;
      });

  void _context(LibraryMaterialContext location) => _change(() {
    _pathwayId = location.pathwayId;
    _playlistId = location.playlistId;
    _sessionIndex = location.sessionIndex;
    _materialId = null;
    _searching = false;
    _scope = location.sessionIndex != null
        ? _LibraryScope.session
        : location.playlistId != null
        ? _LibraryScope.playlist
        : _LibraryScope.extraPractice;
  });

  void _openMaterial(
    LibraryWorkspaceMaterial material, {
    LibraryMaterialContext? location,
  }) {
    final context =
        location ??
        (_searching
            ? _catalog(material.materialId)?.contexts.firstOrNull
            : null);
    _change(() {
      if (context != null) {
        _pathwayId = context.pathwayId;
        _playlistId = context.playlistId;
        _sessionIndex = context.sessionIndex;
        _previewOrigin = context.sessionIndex != null
            ? _LibraryScope.session
            : context.playlistId != null
            ? _LibraryScope.playlist
            : _LibraryScope.extraPractice;
        _extraGroupTitle = _pathway?.extraPracticeGroups
            .where((group) => group.materialIds.contains(material.materialId))
            .firstOrNull
            ?.title;
      } else if (_scope != _LibraryScope.material &&
          _scope != _LibraryScope.document) {
        _previewOrigin = _scope;
      }
      _materialId = material.materialId;
      _previewRoute = material.routePath;
      _scope = _LibraryScope.material;
      _searching = false;
    });
    if (material.routePath != null) widget.onOpenDocument(material.routePath!);
  }

  void _openDocument(String route) {
    final material = widget.library.materials
        .where((item) => item.routePath == route)
        .firstOrNull;
    if (material != null) {
      _openMaterial(material, location: material.contexts.firstOrNull);
      return;
    }
    _change(() {
      if (_scope != _LibraryScope.document &&
          _scope != _LibraryScope.material) {
        _previewOrigin = _scope;
      }
      _previewRoute = route;
      _materialId = null;
      _scope = _LibraryScope.document;
      _searching = false;
    });
    widget.onOpenDocument(route);
  }

  void _returnToMap() => _change(() {
    _searching = false;
    _scope = _previewOrigin;
    _materialId = null;
  });

  Widget _outline({VoidCallback? afterSelection}) => LearningLibraryOutline(
    pathways: widget.library.pathways,
    selectedPathwayId: _pathwayId,
    selectedPlaylistId: _playlistId,
    selectedSessionIndex: _sessionIndex,
    selectedMaterialId: _materialId,
    overviewSelected: _scope == _LibraryScope.overview && !_searching,
    extraSelected: _scope == _LibraryScope.extraPractice,
    onOverview: () {
      _overview();
      afterSelection?.call();
    },
    onPathway: (pathway) {
      _selectPathway(pathway);
      afterSelection?.call();
    },
    onPlaylist: (pathway, playlist) {
      _selectPlaylist(pathway, playlist);
      afterSelection?.call();
    },
    onSession: (pathway, playlist, session) {
      _selectSession(pathway, playlist, session);
      afterSelection?.call();
    },
    onExtraPractice: (pathway) {
      _extra(pathway);
      afterSelection?.call();
    },
    onMaterial: (pathway, playlist, session, material) {
      _selectSession(pathway, playlist, session);
      _openMaterial(material);
      afterSelection?.call();
    },
  );

  Future<void> _showOutline() async => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          ListTile(
            title: const Text('Learning map'),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: _outline(afterSelection: () => Navigator.pop(context)),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                spacing: 24,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learning library',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'See the route. Choose a session. Teach and practise.',
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!wide)
                        OutlinedButton.icon(
                          onPressed: _showOutline,
                          icon: const Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                          ),
                          label: const Text('Learning map'),
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            _change(() => _searching = !_searching),
                        icon: Icon(
                          _searching ? Icons.arrow_back : Icons.search,
                          size: 18,
                        ),
                        label: Text(
                          _searching
                              ? 'Back to learning map'
                              : 'Find a material',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onCreateWorksheet,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Create worksheet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Container(
                      width: 264,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: _outline(),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _breadcrumbs(),
                        Expanded(
                          child: SelectionArea(
                            child: ListView(
                              key: ValueKey(
                                'library-${_searching ? 'search' : _scope.name}-$_pathwayId-$_playlistId-$_sessionIndex-$_materialId',
                              ),
                              padding: EdgeInsets.all(wide ? 28 : 18),
                              children: _searching
                                  ? _searchContent()
                                  : _scopeContent(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _breadcrumbs() {
    Widget crumb(String text, VoidCallback action, {bool current = false}) =>
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: TextButton(
              onPressed: current ? null : action,
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          crumb(
            'Library',
            _overview,
            current: _scope == _LibraryScope.overview && !_searching,
          ),
          if (_pathway != null) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb(_pathway!.title, () => _selectPathway(_pathway!)),
          ],
          if (_playlist != null) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb(
              _playlist!.title,
              () => _selectPlaylist(_pathway!, _playlist!),
            ),
          ],
          if (_session != null) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb(
              'Session ${_session!.sessionIndex}',
              () => _selectSession(_pathway!, _playlist!, _session!),
            ),
          ],
          if (_scope == _LibraryScope.extraPractice ||
              ((_scope == _LibraryScope.material ||
                      _scope == _LibraryScope.document) &&
                  _previewOrigin == _LibraryScope.extraPractice)) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb(
              'Extra practice',
              () => _extra(_pathway!),
              current:
                  _scope == _LibraryScope.extraPractice &&
                  _extraGroupTitle == null,
            ),
            if (_extraGroupTitle != null) ...[
              const Icon(Icons.chevron_right, size: 16),
              crumb(
                _extraGroupTitle!,
                () => _extra(_pathway!, _extraGroupTitle),
                current: _scope == _LibraryScope.extraPractice,
              ),
            ],
          ],
          if (_scope == _LibraryScope.material && _material != null) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb(_material!.title, () {}, current: true),
          ],
          if (_searching) ...[
            const Icon(Icons.chevron_right, size: 16),
            crumb('Find a material', () {}, current: true),
          ],
        ],
      ),
    );
  }

  Widget _heading(
    String eyebrow,
    String title,
    String description, {
    List<Widget> actions = const [],
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, children: actions),
        ],
      ],
    ),
  );
}
