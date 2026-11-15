part of '../../../main.dart';

class MaterialsWorkspaceView extends StatefulWidget {
  const MaterialsWorkspaceView({
    super.key,
    required this.library,
    required this.documents,
    required this.activeDocument,
    required this.documentBusy,
    required this.canAssign,
    required this.onAssignPlaylist,
    required this.onOpenDocument,
    this.onPreviewActivity,
    this.onCreateWorksheetForLevel,
    this.requestedPreviewRoute,
    this.onPreviewRequestHandled,
  });
  final LibraryWorkspacePayload library;
  final LibraryDocumentsPayload? documents;
  final LibraryDocumentData? activeDocument;
  final bool documentBusy;
  final bool canAssign;
  final ValueChanged<LibraryWorkspacePlaylist> onAssignPlaylist;
  final ValueChanged<String> onOpenDocument;
  final ValueChanged<LibraryWorkspaceMaterial>? onPreviewActivity;
  final ValueChanged<String>? onCreateWorksheetForLevel;
  final String? requestedPreviewRoute;
  final VoidCallback? onPreviewRequestHandled;
  @override
  State<MaterialsWorkspaceView> createState() => _MaterialsWorkspaceViewState();
}

class _MaterialsWorkspaceViewState extends State<MaterialsWorkspaceView> {
  final _search = TextEditingController();
  String? _pathwayId;
  String? _playlistId;
  String? _sectionId;
  String? _materialId;
  String? _selectedLevelId;
  String? _documentRoute;
  bool _searching = false;
  bool _restored = false;
  bool _requestScheduled = false;
  LibraryWorkspacePathway? get _pathway => widget.library.pathways
      .where((p) => p.pathwayId == _pathwayId)
      .firstOrNull;
  LibraryWorkspacePlaylist? get _playlist =>
      _pathway?.playlists.where((p) => p.playlistId == _playlistId).firstOrNull;
  PlaybookSection? get _section =>
      _playlist?.sections.where((s) => s.sectionId == _sectionId).firstOrNull;
  LibraryWorkspaceMaterial? _materialFor(PlaybookSectionItem item) => _playlist
      ?.sessions
      .where((s) => s.sessionIndex == item.sessionIndex)
      .firstOrNull
      ?.materials
      .where((m) => m.materialId == item.materialId)
      .firstOrNull;
  LibraryWorkspaceMaterial? get _material => _playlist?.sessions
      .expand((s) => s.materials)
      .where((m) => m.materialId == _materialId)
      .firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: 'playbook-library-selection');
    if (saved is Map) {
      _pathwayId = saved['pathway'] as String?;
      _playlistId = saved['playlist'] as String?;
      _sectionId = saved['section'] as String?;
      _materialId = saved['material'] as String?;
      _selectedLevelId = saved['level'] as String?;
      _documentRoute = saved['document'] as String?;
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
    if (route == null || _requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
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
      'section': _sectionId,
      'material': _materialId,
      'level': _selectedLevelId,
      'document': _documentRoute,
    }, identifier: 'playbook-library-selection');
  }

  void _overview() => _change(() {
    _pathwayId = null;
    _playlistId = null;
    _sectionId = null;
    _materialId = null;
    _documentRoute = null;
    _searching = false;
  });
  void _selectPathway(LibraryWorkspacePathway pathway) => _change(() {
    _pathwayId = pathway.pathwayId;
    _playlistId = null;
    _sectionId = null;
    _materialId = null;
    _documentRoute = null;
    _searching = false;
  });
  void _selectPlaylist(
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
  ) {
    _change(() {
      _pathwayId = pathway.pathwayId;
      _playlistId = playlist.playlistId;
      _sectionId = playlist.sections.firstOrNull?.sectionId;
      _materialId = null;
      _documentRoute = null;
      _searching = false;
    });
    _selectSection(_sectionId);
  }

  void _selectSection(String? id) {
    _change(() {
      _sectionId = id;
      _selectedLevelId = null;
      _materialId = null;
      _documentRoute = null;
    });
    if (id == 'teach' || id == 'learn') {
      final first = _section?.items
          .map(_materialFor)
          .whereType<LibraryWorkspaceMaterial>()
          .firstOrNull;
      if (first != null) _readMaterial(first);
    }
  }

  void _readMaterial(LibraryWorkspaceMaterial material) {
    _change(() {
      _materialId = material.materialId;
      _documentRoute = null;
    });
    if (material.routePath != null) widget.onOpenDocument(material.routePath!);
  }

  void _openDocument(String route) {
    for (final pathway in widget.library.pathways) {
      for (final playlist in pathway.playlists) {
        for (final section in playlist.sections) {
          for (final item in section.items) {
            final material = playlist.sessions
                .where((s) => s.sessionIndex == item.sessionIndex)
                .firstOrNull
                ?.materials
                .where(
                  (m) =>
                      m.materialId == item.materialId && m.routePath == route,
                )
                .firstOrNull;
            if (material == null) continue;
            _change(() {
              _pathwayId = pathway.pathwayId;
              _playlistId = playlist.playlistId;
              _sectionId = section.sectionId;
              _searching = false;
            });
            _readMaterial(material);
            return;
          }
        }
      }
    }
    _change(() {
      _documentRoute = route;
      _searching = false;
    });
    widget.onOpenDocument(route);
  }

  Widget _outline({VoidCallback? afterSelection}) => LearningLibraryOutline(
    pathways: widget.library.pathways,
    selectedPathwayId: _pathwayId,
    selectedPlaylistId: _playlistId,
    onOverview: () {
      _overview();
      afterSelection?.call();
    },
    onPathway: (p) {
      _selectPathway(p);
      afterSelection?.call();
    },
    onPlaylist: (p, b) {
      _selectPlaylist(p, b);
      afterSelection?.call();
    },
  );
  void _showOutline() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: _outline(afterSelection: () => Navigator.pop(context)),
    ),
  );

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
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 8, children: actions),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Learning library',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!wide)
                  IconButton(
                    onPressed: _showOutline,
                    tooltip: 'Learning map',
                    icon: const Icon(Icons.account_tree_outlined),
                  ),
                IconButton(
                  onPressed: () => _change(() => _searching = !_searching),
                  tooltip: _searching
                      ? 'Close search'
                      : 'Search playbooks and materials',
                  icon: Icon(_searching ? Icons.close : Icons.search),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) SizedBox(width: 230, child: _outline()),
                if (wide) const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(
                    key: ValueKey(
                      'library-$_pathwayId-$_playlistId-$_sectionId-$_searching',
                    ),
                    padding: EdgeInsets.all(wide ? 28 : 18),
                    children: [
                      if (!_searching && _pathway != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: _overview,
                                child: const Text('All pathways'),
                              ),
                              const Icon(Icons.chevron_right, size: 16),
                              TextButton(
                                onPressed: () => _selectPathway(_pathway!),
                                child: Text(_pathway!.title),
                              ),
                            ],
                          ),
                        ),
                      ...(_searching ? _searchContent() : _scopeContent()),
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
