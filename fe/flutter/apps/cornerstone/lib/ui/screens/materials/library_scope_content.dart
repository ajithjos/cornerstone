part of '../../../main.dart';

extension _LearningLibraryContent on _MaterialsWorkspaceViewState {
  List<Widget> _scopeContent() {
    if (_scope == _LibraryScope.material || _scope == _LibraryScope.document) {
      return _previewContent();
    }
    final pathway = _pathway;
    if (_scope == _LibraryScope.overview || pathway == null) {
      return _overviewContent();
    }
    if (_scope == _LibraryScope.extraPractice) return _extraContent(pathway);
    final playlist = _playlist;
    if (_scope == _LibraryScope.pathway || playlist == null) {
      return _pathwayContent(pathway);
    }
    final session = _session;
    if (_scope == _LibraryScope.playlist || session == null) {
      return _playlistContent(pathway, playlist);
    }
    return _sessionContent(pathway, playlist, session);
  }

  List<Widget> _overviewContent() => [
    _heading(
      'Start with a pathway',
      'What will you teach next?',
      'Each pathway connects playlists, ordered sessions, lessons and practice. Explore the sequence before choosing work for a student.',
    ),
    LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final pathway in widget.library.pathways)
              SizedBox(
                width: width,
                child: _LibraryPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pathway.areaTitle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pathway.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pathway.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      for (
                        var index = 0;
                        index < pathway.playlists.length;
                        index++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}.',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(pathway.playlists[index].title),
                              ),
                            ],
                          ),
                        ),
                      if (pathway.extraPracticeGroups.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Plus extra practice by skill',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        key: ValueKey('explore-${pathway.pathwayId}'),
                        onPressed: () => _selectPathway(pathway),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Explore pathway'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
    if (widget.library.pathways.isEmpty)
      const Text(
        'No pathways are available yet. Use Find a material to see individual resources.',
      ),
  ];

  List<Widget> _pathwayContent(LibraryWorkspacePathway pathway) => [
    _heading(
      'Pathway · ${pathway.areaTitle}',
      pathway.title,
      pathway.description,
      actions: [
        if (pathway.routePath != null)
          TextButton.icon(
            onPressed: () => _openDocument(pathway.routePath!),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Read pathway overview'),
          ),
      ],
    ),
    _sectionTitle(
      'Learning sequence',
      'Open a playlist to see its sessions in order.',
    ),
    for (var index = 0; index < pathway.playlists.length; index++)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LibraryStepRow(
          number: '${index + 1}',
          title: pathway.playlists[index].title,
          description: pathway.playlists[index].description,
          detail:
              '${pathway.playlists[index].sessions.length} sessions · ${pathway.playlists[index].deliveryShape.estimatedTotalMinutes} min',
          actionLabel: 'View sessions',
          onTap: () => _selectPlaylist(pathway, pathway.playlists[index]),
        ),
      ),
    if (pathway.entryPoints.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _LibraryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested starting points',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Age is a guide. Choose a starting point that matches what the student can already do.',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in pathway.entryPoints)
                    ActionChip(
                      label: Text('Age ${entry.age} · ${entry.playlistTitle}'),
                      onPressed: () {
                        final playlist = pathway.playlists
                            .where(
                              (item) => item.playlistId == entry.playlistId,
                            )
                            .firstOrNull;
                        if (playlist != null) {
                          _selectPlaylist(pathway, playlist);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    if (pathway.extraPracticeGroups.isNotEmpty) ...[
      const SizedBox(height: 28),
      _sectionTitle(
        'Extra practice',
        'Choose a specific skill alongside the main learning sequence.',
      ),
      _LibraryPanel(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final group in pathway.extraPracticeGroups)
              OutlinedButton(
                onPressed: () => _extra(pathway, group.title),
                child: Text(
                  '${group.title} · ${group.materialIds.length} levels',
                ),
              ),
          ],
        ),
      ),
    ],
  ];

  List<Widget> _playlistContent(
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
  ) => [
    _heading(
      'Playlist · ${playlist.sessions.length} sessions',
      playlist.title,
      playlist.description,
      actions: [
        if (widget.canAssign)
          FilledButton.icon(
            key: ValueKey('assign-playlist-${playlist.playlistId}'),
            onPressed: () => widget.onAssignPlaylist(playlist),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Assign this playlist'),
          ),
        if (playlist.routePath != null)
          TextButton(
            onPressed: () => _openDocument(playlist.routePath!),
            child: const Text('Read playlist notes'),
          ),
      ],
    ),
    _sectionTitle(
      'Sessions in order',
      'Each session brings its lesson, practice and checks together.',
    ),
    for (final session in playlist.sessions)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LibraryStepRow(
          number: '${session.sessionIndex}',
          title: session.title,
          description: session.materialsByKind
              .map((group) => _groupTitle(group.kind, group.audience))
              .toSet()
              .join(' → '),
          detail:
              '${session.estimatedMinutes} min · ${session.materialCount} materials${session.requiresAdultSupport ? ' · Parent guidance included' : ''}',
          actionLabel: 'Open session',
          onTap: () => _selectSession(pathway, playlist, session),
        ),
      ),
  ];

  List<Widget> _sessionContent(
    LibraryWorkspacePathway pathway,
    LibraryWorkspacePlaylist playlist,
    LibraryWorkspaceSession session,
  ) => [
    _heading(
      'Session ${session.sessionIndex} · ${session.estimatedMinutes} min',
      session.title,
      'Work through the materials below. Keep the explanation and practice together.',
      actions: [
        if (widget.canAssign)
          TextButton.icon(
            onPressed: () => widget.onAssignPlaylist(playlist),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Assign full playlist'),
          ),
      ],
    ),
    for (final group in session.materialsByKind) ...[
      _sectionTitle(
        _groupTitle(group.kind, group.audience),
        _groupDescription(group.kind, group.audience),
      ),
      for (final material in group.materials)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _materialRow(material),
        ),
      const SizedBox(height: 16),
    ],
    if (session.materialsByKind.isEmpty)
      for (final material in session.materials)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _materialRow(material),
        ),
    const SizedBox(height: 12),
    TextButton.icon(
      onPressed: () => _selectPlaylist(pathway, playlist),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Back to all sessions'),
    ),
  ];

  List<Widget> _extraContent(LibraryWorkspacePathway pathway) => [
    _heading(
      'Extra practice · ${pathway.title}',
      'Practise one skill at a time',
      'Choose a level to read its guidance and assign a short activity. Follow the listed order as the student becomes ready.',
      actions: [
        OutlinedButton.icon(
          onPressed: widget.onCreateWorksheet,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Create fresh printable practice'),
        ),
      ],
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All skills'),
          selected: _extraGroupTitle == null,
          onSelected: (_) => _extra(pathway),
        ),
        for (final group in pathway.extraPracticeGroups)
          ChoiceChip(
            label: Text(group.title),
            selected: _extraGroupTitle == group.title,
            onSelected: (_) => _extra(pathway, group.title),
          ),
      ],
    ),
    const SizedBox(height: 24),
    for (final group in pathway.extraPracticeGroups.where(
      (group) => _extraGroupTitle == null || group.title == _extraGroupTitle,
    )) ...[
      _sectionTitle(group.title, ''),
      for (final id in group.materialIds)
        if (_catalog(id) != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _materialRow(_catalog(id)!),
          ),
      const SizedBox(height: 18),
    ],
    if (pathway.extraPracticeGroups.isEmpty)
      const Text('No extra practice is listed for this pathway yet.'),
  ];

  Widget _materialRow(LibraryWorkspaceMaterial material) => _LibraryStepRow(
    key: ValueKey('material-row-${material.materialId}'),
    number: null,
    icon: CornerstoneIcons.materialKind(material.kind),
    title: material.title,
    description: '',
    detail:
        '${_materialKindLabel(material.kind)} · ${material.estimatedMinutes} min${material.executable ? ' · Interactive' : ''}',
    actionLabel: 'Open',
    onTap: () => _openMaterial(material),
  );

  List<Widget> _previewContent() {
    final material = _material;
    final document = widget.activeDocument;
    return [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: _returnToMap,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(
              _previewOrigin == _LibraryScope.extraPractice
                  ? 'Back to ${_extraGroupTitle ?? 'extra practice'}'
                  : _session != null
                  ? 'Back to session'
                  : _playlist != null
                  ? 'Back to playlist'
                  : 'Back to learning map',
            ),
          ),
          if (widget.canAssign && material?.assignable == true)
            FilledButton.icon(
              key: ValueKey('assign-material-${material!.materialId}'),
              onPressed: () => widget.onAssignMaterial(material),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Assign this material'),
            ),
        ],
      ),
      if (material?.contextLabel.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 16),
          child: Text(
            material!.contextLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 16),
      if (widget.documentBusy)
        const LinearProgressIndicator()
      else if (document != null && document.routePath == _previewRoute)
        _LibraryPanel(
          child: _LibraryDocumentReader(
            document: document,
            busy: false,
            routeBySourcePath: {
              for (final doc
                  in widget.documents?.documents ?? <LibraryDocumentSummary>[])
                doc.sourcePath: doc.routePath,
            },
            onOpenLibraryRoute: _openDocument,
          ),
        )
      else
        _LibraryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                material?.title ?? 'Material preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                material?.description ?? 'Choose a lesson or resource to read.',
              ),
              if (_previewRoute != null)
                TextButton(
                  onPressed: () => widget.onOpenDocument(_previewRoute!),
                  child: const Text('Load preview'),
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _searchContent() {
    final query = _search.text.trim().toLowerCase();
    final matches = widget.library.materials
        .where(
          (item) =>
              (_kindFilter == null || item.kind == _kindFilter) &&
              '${item.title} ${item.description} ${item.contextLabel}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final kinds = widget.library.materials
        .map((item) => item.kind)
        .toSet()
        .toList();
    return [
      _heading(
        'Find a material',
        'Search without losing the learning route',
        'Open a result or return to its session to see what comes before and after it.',
      ),
      TextField(
        controller: _search,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search a skill, lesson or material',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => _change(() {}),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          ChoiceChip(
            label: const Text('All types'),
            selected: _kindFilter == null,
            onSelected: (_) => _change(() => _kindFilter = null),
          ),
          for (final kind in kinds)
            ChoiceChip(
              label: Text(_materialKindLabel(kind)),
              selected: _kindFilter == kind,
              onSelected: (_) => _change(() => _kindFilter = kind),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '${matches.length} ${matches.length == 1 ? 'material' : 'materials'}',
        ),
      ),
      for (final material in matches)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LibraryPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_materialKindLabel(material.kind)} · ${material.estimatedMinutes} min${material.executable ? ' · Interactive' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (material.contextLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(material.contextLabel),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    TextButton(
                      onPressed: () => _openMaterial(
                        material,
                        location: material.contexts.firstOrNull,
                      ),
                      child: const Text('Open material'),
                    ),
                    for (final location in material.contexts)
                      TextButton.icon(
                        onPressed: () => _context(location),
                        icon: const Icon(Icons.account_tree_outlined, size: 16),
                        label: Text(
                          location.sessionIndex != null
                              ? 'Session ${location.sessionIndex} · ${location.playlistTitle}'
                              : 'Extra practice · ${location.pathwayTitle}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (matches.isEmpty)
        const Text(
          'No matching materials. Try a shorter search or another type.',
        ),
    ];
  }

  Widget _sectionTitle(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
  String _groupTitle(String kind, String audience) => audience == 'adult'
      ? 'Parent guidance'
      : switch (kind) {
          'lesson_note' => 'Learn',
          'worksheet' => 'Practise',
          'drill' => 'Fluency practice',
          'quick_check' => 'Check',
          _ => _materialKindLabel(kind),
        };
  String _groupDescription(String kind, String audience) => audience == 'adult'
      ? 'Notes to prepare or support this session.'
      : switch (kind) {
          'lesson_note' => 'Read the explanation and worked examples.',
          'worksheet' => 'Apply the method and correct mistakes.',
          'drill' => 'Build accuracy and fluency with repeated practice.',
          'quick_check' => 'Check what the student can do independently.',
          _ => '',
        };
}
