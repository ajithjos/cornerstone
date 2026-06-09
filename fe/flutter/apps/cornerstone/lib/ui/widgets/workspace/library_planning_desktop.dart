part of '../../../main.dart';

class _LibraryPlanningDesktop extends StatefulWidget {
  const _LibraryPlanningDesktop({
    required this.libraryWorkspace,
    required this.documents,
    required this.activeDocument,
    required this.libraryDocumentBusy,
    required this.viewerCanManage,
    required this.onCreateAssignment,
    required this.onOpenLibraryRoute,
    required this.totalMaterials,
  });

  final LibraryWorkspacePayload libraryWorkspace;
  final LibraryDocumentsPayload? documents;
  final LibraryDocumentData? activeDocument;
  final bool libraryDocumentBusy;
  final bool viewerCanManage;
  final Future<void> Function(String learnerId, String playlistId)
  onCreateAssignment;
  final ValueChanged<String> onOpenLibraryRoute;
  final int totalMaterials;

  @override
  State<_LibraryPlanningDesktop> createState() =>
      _LibraryPlanningDesktopState();
}

enum _PlanningFocus { pathway, playlist, session, material }

class _LibraryPlanningDesktopState extends State<_LibraryPlanningDesktop> {
  String? _selectedPathwayId;
  String? _selectedPlaylistId;
  int _selectedSessionIndex = 0;
  String? _selectedMaterialId;
  _PlanningFocus _focus = _PlanningFocus.pathway;
  bool _navigatorExpanded = true;

  @override
  void initState() {
    super.initState();
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant _LibraryPlanningDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  void _syncSelection() {
    final pathways = widget.libraryWorkspace.pathways;
    if (pathways.isEmpty) {
      _selectedPathwayId = null;
      _selectedPlaylistId = null;
      _selectedSessionIndex = 0;
      return;
    }
    final pathway = pathways.firstWhere(
      (item) => item.pathwayId == _selectedPathwayId,
      orElse: () => pathways.first,
    );
    _selectedPathwayId = pathway.pathwayId;
    if (pathway.playlists.isEmpty) {
      _selectedPlaylistId = null;
      _selectedSessionIndex = 0;
      return;
    }
    final playlist = pathway.playlists.firstWhere(
      (item) => item.playlistId == _selectedPlaylistId,
      orElse: () => pathway.playlists.first,
    );
    _selectedPlaylistId = playlist.playlistId;
    if (playlist.sessions.isEmpty) {
      _selectedSessionIndex = 0;
      return;
    }
    if (_selectedSessionIndex >= playlist.sessions.length) {
      _selectedSessionIndex = 0;
    }

    final selectedSession = _selectedSession;
    if (selectedSession == null || selectedSession.materials.isEmpty) {
      _selectedMaterialId = null;
      return;
    }
    final hasMaterial = selectedSession.materials.any(
      (material) => material.materialId == _selectedMaterialId,
    );
    if (!hasMaterial) {
      _selectedMaterialId = selectedSession.materials.first.materialId;
    }
  }

  LibraryWorkspacePathway? get _selectedPathway {
    for (final pathway in widget.libraryWorkspace.pathways) {
      if (pathway.pathwayId == _selectedPathwayId) {
        return pathway;
      }
    }
    return widget.libraryWorkspace.pathways.isEmpty
        ? null
        : widget.libraryWorkspace.pathways.first;
  }

  LibraryWorkspacePlaylist? get _selectedPlaylist {
    final pathway = _selectedPathway;
    if (pathway == null || pathway.playlists.isEmpty) {
      return null;
    }
    for (final playlist in pathway.playlists) {
      if (playlist.playlistId == _selectedPlaylistId) {
        return playlist;
      }
    }
    return pathway.playlists.first;
  }

  LibraryWorkspaceSession? get _selectedSession {
    final playlist = _selectedPlaylist;
    if (playlist == null || playlist.sessions.isEmpty) {
      return null;
    }
    if (_selectedSessionIndex >= playlist.sessions.length) {
      return playlist.sessions.first;
    }
    return playlist.sessions[_selectedSessionIndex];
  }

  LibraryWorkspaceMaterial? get _selectedMaterial {
    final session = _selectedSession;
    if (session == null || session.materials.isEmpty) {
      return null;
    }
    for (final material in session.materials) {
      if (material.materialId == _selectedMaterialId) {
        return material;
      }
    }
    return session.materials.first;
  }

  String? _preferredRouteForSession(LibraryWorkspaceSession session) {
    for (final material in session.materials) {
      final routePath = material.routePath;
      if (routePath != null && routePath.isNotEmpty) {
        return routePath;
      }
    }
    return null;
  }

  String? _preferredRouteForPlaylist(LibraryWorkspacePlaylist playlist) {
    final routePath = playlist.routePath;
    if (routePath != null && routePath.isNotEmpty) {
      return routePath;
    }
    for (final session in playlist.sessions) {
      final sessionRoute = _preferredRouteForSession(session);
      if (sessionRoute != null) {
        return sessionRoute;
      }
    }
    return null;
  }

  String? _preferredRouteForPathway(LibraryWorkspacePathway pathway) {
    final routePath = pathway.routePath;
    if (routePath != null && routePath.isNotEmpty) {
      return routePath;
    }
    for (final playlist in pathway.playlists) {
      final playlistRoute = _preferredRouteForPlaylist(playlist);
      if (playlistRoute != null) {
        return playlistRoute;
      }
    }
    return null;
  }

  void _openPreferredRoute(String? routePath) {
    if (routePath == null || routePath.isEmpty) {
      return;
    }
    widget.onOpenLibraryRoute(routePath);
  }

  void _selectPathway(LibraryWorkspacePathway pathway) {
    setState(() {
      _selectedPathwayId = pathway.pathwayId;
      _selectedPlaylistId = pathway.playlists.isEmpty
          ? null
          : pathway.playlists.first.playlistId;
      _selectedSessionIndex = 0;
      _focus = _PlanningFocus.pathway;
    });
    _openPreferredRoute(_preferredRouteForPathway(pathway));
  }

  void _selectPlaylist(LibraryWorkspacePlaylist playlist) {
    setState(() {
      _selectedPlaylistId = playlist.playlistId;
      _selectedSessionIndex = 0;
      _focus = _PlanningFocus.playlist;
    });
    _openPreferredRoute(_preferredRouteForPlaylist(playlist));
  }

  void _selectSession(int index) {
    final playlist = _selectedPlaylist;
    setState(() {
      _selectedSessionIndex = index;
      _focus = _PlanningFocus.session;
      if (playlist != null && index < playlist.sessions.length) {
        final materials = playlist.sessions[index].materials;
        _selectedMaterialId = materials.isEmpty
            ? null
            : materials.first.materialId;
      } else {
        _selectedMaterialId = null;
      }
    });
    if (playlist == null || index >= playlist.sessions.length) {
      return;
    }
    _openPreferredRoute(_preferredRouteForSession(playlist.sessions[index]));
  }

  void _selectMaterial(LibraryWorkspaceMaterial material) {
    setState(() {
      _selectedMaterialId = material.materialId;
      _focus = _PlanningFocus.material;
    });
    final routePath = material.routePath;
    if (routePath != null && routePath.isNotEmpty) {
      widget.onOpenLibraryRoute(routePath);
    }
  }

  String _focusLabel(_PlanningFocus focus) {
    switch (focus) {
      case _PlanningFocus.pathway:
        return 'Pathway';
      case _PlanningFocus.playlist:
        return 'Playlist';
      case _PlanningFocus.session:
        return 'Session';
      case _PlanningFocus.material:
        return 'Material';
    }
  }

  InputDecoration _dropdownDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surface.withValues(alpha: 0.66),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
      ),
    );
  }

  TextStyle? _dropdownTextStyle(ThemeData theme) {
    return theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildStickySelectors(
    ThemeData theme,
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
  ) {
    final session = _selectedSession;
    final material = _selectedMaterial;

    Widget boundedDropdown(Widget child) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 250, maxWidth: 360),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_PlanningFocus>(
          segments: _PlanningFocus.values
              .map(
                (focus) => ButtonSegment<_PlanningFocus>(
                  value: focus,
                  label: Text(_focusLabel(focus)),
                ),
              )
              .toList(growable: false),
          selected: {_focus},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            setState(() {
              _focus = selection.first;
            });
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            boundedDropdown(
              DropdownButtonFormField<String>(
                initialValue: _selectedPathwayId,
                isExpanded: true,
                menuMaxHeight: 420,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surface,
                style: _dropdownTextStyle(theme),
                iconEnabledColor: theme.colorScheme.primary,
                decoration: _dropdownDecoration(theme, 'Pathway'),
                items: widget.libraryWorkspace.pathways
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.pathwayId,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  for (final item in widget.libraryWorkspace.pathways) {
                    if (item.pathwayId == value) {
                      _selectPathway(item);
                      return;
                    }
                  }
                },
              ),
            ),
            boundedDropdown(
              DropdownButtonFormField<String>(
                initialValue: _selectedPlaylistId,
                isExpanded: true,
                menuMaxHeight: 420,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surface,
                style: _dropdownTextStyle(theme),
                iconEnabledColor: theme.colorScheme.primary,
                decoration: _dropdownDecoration(theme, 'Playlist'),
                items: pathway.playlists
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.playlistId,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  for (final item in pathway.playlists) {
                    if (item.playlistId == value) {
                      _selectPlaylist(item);
                      return;
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            boundedDropdown(
              DropdownButtonFormField<int>(
                initialValue: session == null ? null : _selectedSessionIndex,
                isExpanded: true,
                menuMaxHeight: 420,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surface,
                style: _dropdownTextStyle(theme),
                iconEnabledColor: theme.colorScheme.primary,
                decoration: _dropdownDecoration(theme, 'Session'),
                items: playlist.sessions
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(
                          '${entry.value.sessionIndex}. ${entry.value.title}',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _selectSession(value);
                },
              ),
            ),
            boundedDropdown(
              DropdownButtonFormField<String>(
                initialValue: material?.materialId,
                isExpanded: true,
                menuMaxHeight: 420,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surface,
                style: _dropdownTextStyle(theme),
                iconEnabledColor: theme.colorScheme.primary,
                decoration: _dropdownDecoration(theme, 'Material'),
                items:
                    (session?.materials ?? const <LibraryWorkspaceMaterial>[])
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.materialId,
                            child: Text(item.title),
                          ),
                        )
                        .toList(growable: false),
                onChanged: (value) {
                  if (value == null || session == null) {
                    return;
                  }
                  for (final item in session.materials) {
                    if (item.materialId == value) {
                      _selectMaterial(item);
                      return;
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildSelectionBreadcrumb(
          theme,
          pathway: pathway,
          playlist: playlist,
          session: session,
          material: material,
        ),
      ],
    );
  }

  Widget _buildSelectionBreadcrumb(
    ThemeData theme, {
    required LibraryWorkspacePathway pathway,
    required LibraryWorkspacePlaylist playlist,
    LibraryWorkspaceSession? session,
    LibraryWorkspaceMaterial? material,
  }) {
    const sep = Icon(CornerstoneIcons.chevronRight, size: 16);

    Widget crumb(String label, String value, {bool active = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final focusLevel = switch (_focus) {
      _PlanningFocus.pathway => 0,
      _PlanningFocus.playlist => 1,
      _PlanningFocus.session => 2,
      _PlanningFocus.material => 3,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.26,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          crumb('Pathway', pathway.title, active: focusLevel == 0),
          const SizedBox(width: 6),
          sep,
          const SizedBox(width: 6),
          crumb('Playlist', playlist.title, active: focusLevel == 1),
          if (session != null) ...[
            const SizedBox(width: 6),
            sep,
            const SizedBox(width: 6),
            crumb('Session', session.title, active: focusLevel == 2),
          ],
          if (material != null) ...[
            const SizedBox(width: 6),
            sep,
            const SizedBox(width: 6),
            crumb('Material', material.title, active: focusLevel == 3),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusDetail(
    ThemeData theme,
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
  ) {
    final session = _selectedSession;
    final material = _selectedMaterial;

    switch (_focus) {
      case _PlanningFocus.pathway:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pathway.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pathway.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pathway.routePath != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () =>
                        widget.onOpenLibraryRoute(pathway.routePath!),
                    icon: const Icon(CornerstoneIcons.document, size: 16),
                    label: const Text('Open document'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _ContractChipRow(
              children: [
                const _ContractChip(domain: 'entity', value: 'pathway'),
                _PillBadge(
                  text: pathway.areaTitle,
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
                _PillBadge(
                  text: 'playlists:${pathway.playlistCount}',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
                _PillBadge(
                  text:
                      'age:${pathway.recommendedAgeMin}-${pathway.recommendedAgeMax}',
                  color: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        );
      case _PlanningFocus.playlist:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playlist.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (playlist.routePath != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () =>
                        widget.onOpenLibraryRoute(playlist.routePath!),
                    icon: const Icon(CornerstoneIcons.library, size: 16),
                    label: const Text('Open document'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _ContractChipRow(
              children: [
                const _ContractChip(domain: 'entity', value: 'playlist'),
                _PillBadge(
                  text: 'sessions:${playlist.sessions.length}',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
                _PillBadge(
                  text: 'materials:${playlist.materialCount}',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
                _PillBadge(
                  text:
                      'minutes:${playlist.deliveryShape.estimatedTotalMinutes}',
                  color: theme.colorScheme.tertiaryContainer,
                  textColor: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ),
            if (playlist.assignmentTargets.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Assignment targets', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: playlist.assignmentTargets
                      .map(
                        (target) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 244),
                            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.70),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        target.displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                    ),
                                    if (target.recommended) ...[
                                      const SizedBox(width: 6),
                                      _PillBadge(
                                        text: 'recommended',
                                        color: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        textColor: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  target.statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (widget.viewerCanManage) ...[
                                  const SizedBox(height: 8),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: target.assignedHere
                                        ? null
                                        : () => widget.onCreateAssignment(
                                            target.learnerId,
                                            playlist.playlistId,
                                          ),
                                    child: Text(
                                      target.assignedHere
                                          ? 'Assigned here'
                                          : 'Assign playlist',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        );
      case _PlanningFocus.session:
        if (session == null) {
          return Text(
            'No session available for this playlist.',
            style: theme.textTheme.bodyLarge,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _ContractChipRow(
              children: [
                const _ContractChip(domain: 'entity', value: 'session'),
                _ContractChip(
                  domain: 'material_kind',
                  value: session.dominantKind,
                ),
                if (session.requiresAdultSupport)
                  const _ContractChip(domain: 'status', value: 'adult_guided'),
                _PillBadge(
                  text: 'materials:${session.materialCount}',
                  color: theme.colorScheme.secondaryContainer,
                  textColor: theme.colorScheme.onSecondaryContainer,
                ),
                _PillBadge(
                  text: '${session.estimatedMinutes} min',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ContractChipRow(
              children: session.materialsByKind
                  .map(
                    (group) => _PillBadge(
                      text:
                          '${group.audience}:${group.kind}:${group.materialCount}',
                      color: _materialKindBackgroundColor(theme, group.kind),
                      textColor: _materialKindForegroundColor(
                        theme,
                        group.kind,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      case _PlanningFocus.material:
        if (session == null || material == null) {
          return Text(
            'No material selected in this session.',
            style: theme.textTheme.bodyLarge,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (material.routePath != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () =>
                        widget.onOpenLibraryRoute(material.routePath!),
                    icon: const Icon(CornerstoneIcons.document, size: 16),
                    label: const Text('Open material'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _ContractChipRow(
              children: [
                const _ContractChip(
                  domain: 'entity',
                  value: 'session_material',
                ),
                _ContractChip(domain: 'material_kind', value: material.kind),
                _ContractChip(domain: 'audience', value: material.audience),
                if (material.executable)
                  const _ContractChip(domain: 'status', value: 'live'),
                _PillBadge(
                  text: '${material.estimatedMinutes} min',
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  textColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildCompactStudioHeader(ThemeData theme) {
    final pathways = widget.libraryWorkspace.pathways;
    final pathway = _selectedPathway;
    final playlist = _selectedPlaylist;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _PillBadge(
                      text: 'library',
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pathway planning studio',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pathway != null && playlist != null) ...[
            const SizedBox(height: 12),
            _buildStickySelectors(theme, pathway, playlist),
          ] else ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPathwayId,
                isExpanded: true,
                menuMaxHeight: 420,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: theme.colorScheme.surface,
                style: _dropdownTextStyle(theme),
                iconEnabledColor: theme.colorScheme.primary,
                decoration: _dropdownDecoration(theme, 'Pathway'),
                items: pathways
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.pathwayId,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  for (final item in pathways) {
                    if (item.pathwayId == value) {
                      _selectPathway(item);
                      return;
                    }
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Tooltip(
            message: _navigatorExpanded ? 'Hide navigator' : 'Show navigator',
            child: IconButton(
              onPressed: () =>
                  setState(() => _navigatorExpanded = !_navigatorExpanded),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _navigatorExpanded
                    ? CornerstoneIcons.menuOpen
                    : CornerstoneIcons.menu,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyNavigator(ThemeData theme) {
    final pathway = _selectedPathway;
    final playlist = _selectedPlaylist;
    if (pathway == null || playlist == null) {
      return _SurfaceCard(
        child: Text(
          'Select a playlist to inspect it.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final session = _selectedSession;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Navigator', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DesktopSidebarButton(
                    label: pathway.title,
                    icon: CornerstoneIcons.pathway,
                    level: 0,
                    selected: true,
                    onTap: () {
                      _selectPathway(pathway);
                    },
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: pathway.playlists
                          .map((item) {
                            final isSelectedPlaylist =
                                item.playlistId == _selectedPlaylistId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DesktopSidebarButton(
                                    label: item.title,
                                    icon: CornerstoneIcons.playlist,
                                    level: 1,
                                    selected: isSelectedPlaylist,
                                    onTap: () {
                                      _selectPlaylist(item);
                                    },
                                  ),
                                  if (isSelectedPlaylist) ...[
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: item.sessions
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              final isSelectedSession =
                                                  entry.key ==
                                                  _selectedSessionIndex;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _DesktopSidebarButton(
                                                      label:
                                                          '${entry.value.sessionIndex}. ${entry.value.title}',
                                                      icon: Icons
                                                          .fact_check_rounded,
                                                      level: 2,
                                                      selected:
                                                          isSelectedSession,
                                                      onTap: () {
                                                        _selectSession(
                                                          entry.key,
                                                        );
                                                      },
                                                    ),
                                                    if (isSelectedSession) ...[
                                                      const SizedBox(height: 6),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 12,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: entry
                                                              .value
                                                              .materials
                                                              .map((material) {
                                                                final isSelectedMaterial =
                                                                    material
                                                                        .materialId ==
                                                                    _selectedMaterialId;
                                                                return Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        bottom:
                                                                            6,
                                                                      ),
                                                                  child: _DesktopSidebarButton(
                                                                    label: material
                                                                        .title,
                                                                    icon: Icons
                                                                        .description_rounded,
                                                                    level: 3,
                                                                    selected:
                                                                        isSelectedMaterial,
                                                                    onTap: () {
                                                                      _selectMaterial(
                                                                        material,
                                                                      );
                                                                    },
                                                                  ),
                                                                );
                                                              })
                                                              .toList(
                                                                growable: false,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            })
                                            .toList(growable: false),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  if (session == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Select a session to expand materials.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentWorkspace(ThemeData theme) {
    final pathway = _selectedPathway;
    final playlist = _selectedPlaylist;
    if (pathway == null || playlist == null) {
      return _SurfaceCard(
        child: Text(
          'Select a pathway and playlist from the navigator.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final routeBySourcePath = {
      for (final document
          in widget.documents?.documents ?? const <LibraryDocumentSummary>[])
        document.sourcePath: document.routePath,
    };

    return Column(
      children: [
        _SurfaceCard(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 164),
            alignment: Alignment.topLeft,
            child: _buildFocusDetail(theme, pathway, playlist),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _SurfaceCard(
            child: SingleChildScrollView(
              child: _LibraryDocumentReader(
                document: widget.activeDocument,
                busy: widget.libraryDocumentBusy,
                routeBySourcePath: routeBySourcePath,
                onOpenLibraryRoute: widget.onOpenLibraryRoute,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        _buildCompactStudioHeader(theme),
        const SizedBox(height: 20),
        SizedBox(
          height: _desktopStudioHeight(
            context,
            subtract: 200,
            minHeight: 760,
            maxHeight: 980,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_navigatorExpanded)
                Expanded(flex: 4, child: _buildHierarchyNavigator(theme)),
              if (_navigatorExpanded) const SizedBox(width: 20),
              Expanded(
                flex: _navigatorExpanded ? 7 : 11,
                child: _buildContentWorkspace(theme),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
