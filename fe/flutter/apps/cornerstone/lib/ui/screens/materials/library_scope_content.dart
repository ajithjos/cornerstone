part of '../../../main.dart';

extension _LearningLibraryContent on _MaterialsWorkspaceViewState {
  List<Widget> _scopeContent() {
    if (_documentRoute != null) {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _change(() => _documentRoute = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to playbook'),
          ),
        ),
        _LibraryPanel(
          child: _LibraryDocumentReader(
            document: widget.activeDocument?.routePath == _documentRoute
                ? widget.activeDocument
                : null,
            busy: widget.documentBusy,
            routeBySourcePath: {
              for (final d
                  in widget.documents?.documents ?? <LibraryDocumentSummary>[])
                d.sourcePath: d.routePath,
            },
            onOpenLibraryRoute: _openDocument,
          ),
        ),
      ];
    }
    if (_playlist != null) return _playlistContent(_playlist!);
    if (_pathway != null) return _pathwayContent(_pathway!);
    return _overviewContent();
  }

  List<Widget> _overviewContent() => [
    _heading(
      'A clear path, one playbook at a time',
      'What will you teach next?',
      'Explore a pathway, open a playbook, and choose who will learn it.',
    ),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final pathway in widget.library.pathways)
            SizedBox(
              width: constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 18) / 2
                  : constraints.maxWidth,
              child: _LibraryPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pathway.areaTitle,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pathway.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      pathway.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${pathway.playlists.length} playbooks · Ages ${pathway.recommendedAgeMin}–${pathway.recommendedAgeMax}',
                    ),
                    const SizedBox(height: 18),
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
      ),
    ),
    if (widget.library.pathways.isEmpty)
      const Text('No pathways are available yet.'),
  ];

  List<Widget> _pathwayContent(LibraryWorkspacePathway pathway) => [
    _heading(
      pathway.areaTitle,
      pathway.title,
      pathway.description,
      actions: [
        if (pathway.routePath != null)
          TextButton.icon(
            onPressed: () => _openDocument(pathway.routePath!),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Read pathway guidance'),
          ),
      ],
    ),
    Text('Learning sequence', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6),
    const Text(
      'Choose a playbook at the right starting point. Age is a guide.',
    ),
    const SizedBox(height: 18),
    for (var i = 0; i < pathway.playlists.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _LibraryStepRow(
          key: ValueKey('playbook-${pathway.playlists[i].playlistId}'),
          number: '${i + 1}',
          title: pathway.playlists[i].title,
          description: pathway.playlists[i].description,
          detail: pathway.playlists[i].sections.map((s) => s.title).join(' · '),
          actionLabel: 'Open playbook',
          onTap: () => _selectPlaylist(pathway, pathway.playlists[i]),
        ),
      ),
    if (pathway.entryPoints.isNotEmpty) ...[
      const SizedBox(height: 16),
      Text(
        'Suggested starting points',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in pathway.entryPoints)
            ActionChip(
              label: Text('Age ${entry.age} · ${entry.playlistTitle}'),
              onPressed: () {
                final playlist = pathway.playlists
                    .where((p) => p.playlistId == entry.playlistId)
                    .firstOrNull;
                if (playlist != null) _selectPlaylist(pathway, playlist);
              },
            ),
        ],
      ),
    ],
  ];

  List<Widget> _playlistContent(LibraryWorkspacePlaylist playlist) {
    final section = _section;
    final materials =
        section?.items
            .map(_materialFor)
            .whereType<LibraryWorkspaceMaterial>()
            .toList() ??
        <LibraryWorkspaceMaterial>[];
    final material = _material;
    final assignedNames = playlist.assignmentTargets
        .where((t) => t.assignedHere)
        .map((t) => t.displayName)
        .toList();
    return [
      _heading(
        'Playbook',
        playlist.title,
        playlist.description,
        actions: [
          if (widget.canAssign)
            FilledButton.icon(
              key: ValueKey('assign-playlist-${playlist.playlistId}'),
              onPressed: () => widget.onAssignPlaylist(playlist),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Assign playbook'),
            ),
          if (assignedNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Assigned to ${assignedNames.join(', ')}'),
            ),
        ],
      ),
      _PlaybookSectionTabs(
        sections: playlist.sections,
        selectedId: _sectionId ?? '',
        onSelected: _selectSection,
      ),
      const SizedBox(height: 24),
      if (section != null) ...[
        Text(section.description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        if (materials.isEmpty)
          const _LibraryPanel(
            child: Text('No additional material is needed here.'),
          ),
        if (material != null &&
            materials.any((m) => m.materialId == material.materialId)) ...[
          if (materials.length > 1 &&
              (_sectionId == 'learn' || _sectionId == 'teach')) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in materials)
                  ChoiceChip(
                    label: Text(m.title),
                    selected: material.materialId == m.materialId,
                    onSelected: (_) => _readMaterial(m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionId != 'learn' && _sectionId != 'teach')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _change(() => _materialId = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text('Back to ${section.title.toLowerCase()}'),
              ),
            ),
          _materialReader(material),
        ] else
          _practiceMaterials(materials),
      ],
    ];
  }

  Widget _practiceMaterials(List<LibraryWorkspaceMaterial> materials) {
    final levels = materials.where((m) => m.executable).toList();
    final selected =
        levels.where((m) => m.materialId == _selectedLevelId).firstOrNull ??
        levels.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (levels.isNotEmpty) ...[
          Text(
            'Owner preview · Try the same activity without recording learner progress.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (levels.length > 1 && selected != null)
          _PracticeLevelPicker(
            levels: [
              for (final m in levels)
                (id: m.materialId, title: m.title, status: null),
            ],
            selectedId: selected.materialId,
            onSelected: (id) => _change(() => _selectedLevelId = id),
            detail: _materialCard(selected),
          )
        else if (selected != null)
          _materialCard(selected),
        for (final m in materials.where((m) => !m.executable))
          if (_sectionId == 'practice')
            ExpansionTile(
              title: Text(m.title),
              tilePadding: EdgeInsets.zero,
              children: [_materialCard(m)],
            )
          else
            _materialCard(m),
      ],
    );
  }

  Widget _materialButtons(
    LibraryWorkspaceMaterial material, {
    bool reading = false,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (material.executable && widget.onPreviewActivity != null)
        FilledButton.tonalIcon(
          onPressed: () => widget.onPreviewActivity!(material),
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: Text(
            _sectionId == 'checkpoint' ? 'Take checkpoint' : 'Start practice',
          ),
        ),
      if (material.routePath != null && _materialId != material.materialId)
        OutlinedButton.icon(
          onPressed: () => _readMaterial(material),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text(material.executable ? 'Instructions' : 'Read'),
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
              !material.executable ||
              material.activityLevelId == null ||
              widget.onCreateWorksheetForLevel == null) &&
          widget.activeDocument?.routePath == material.routePath)
        OutlinedButton.icon(
          onPressed: () => _runPrintAction(
            context,
            () => printLearningMaterial(
              LearningMaterialPrintPayload(
                sessionTitle: _playlist!.title,
                materialTitle: material.title,
                kindLabel: _section?.title ?? '',
                estimatedMinutes: material.estimatedMinutes,
                body: widget.activeDocument!.body,
              ),
            ),
          ),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: Text(material.executable ? 'Print instructions' : 'Print'),
        ),
    ],
  );

  Widget _materialCard(LibraryWorkspaceMaterial material) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _LibraryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(material.title, style: Theme.of(context).textTheme.titleMedium),
          if (material.checkpointPolicy != null)
            _CheckpointConditions(policy: material.checkpointPolicy!),
          const SizedBox(height: 14),
          _materialButtons(material),
        ],
      ),
    ),
  );

  Widget _materialReader(LibraryWorkspaceMaterial material) => _LibraryPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _materialButtons(material, reading: true),
        if (material.checkpointPolicy != null)
          _CheckpointConditions(policy: material.checkpointPolicy!),
        const Divider(height: 32),
        if (widget.documentBusy)
          const LinearProgressIndicator()
        else if (widget.activeDocument?.routePath == material.routePath)
          SelectionArea(
            child: MarkdownBody(
              data: widget.activeDocument!.body,
              selectable: true,
              styleSheet: _workspaceMarkdownStyle(Theme.of(context)),
            ),
          )
        else
          const Text('Loading material…'),
      ],
    ),
  );

  List<Widget> _searchContent() {
    final query = _search.text.trim().toLowerCase();
    final matches =
        <
          (
            LibraryWorkspacePathway,
            LibraryWorkspacePlaylist,
            PlaybookSection?,
            LibraryWorkspaceMaterial?,
          )
        >[];
    for (final pathway in widget.library.pathways) {
      for (final playlist in pathway.playlists) {
        if (query.isEmpty ||
            '${pathway.title} ${playlist.title}'.toLowerCase().contains(
              query,
            )) {
          matches.add((pathway, playlist, null, null));
        }
        if (query.isNotEmpty) {
          for (final section in playlist.sections) {
            for (final ref in section.items) {
              final material = playlist.sessions
                  .where((s) => s.sessionIndex == ref.sessionIndex)
                  .firstOrNull
                  ?.materials
                  .where((m) => m.materialId == ref.materialId)
                  .firstOrNull;
              if (material != null &&
                  material.title.toLowerCase().contains(query)) {
                matches.add((pathway, playlist, section, material));
              }
            }
          }
        }
      }
    }
    return [
      _heading(
        'Find your place',
        'Search learning',
        'Results stay connected to their playbook.',
      ),
      TextField(
        controller: _search,
        autofocus: true,
        onChanged: (_) => _change(() {}),
        decoration: const InputDecoration(
          labelText: 'Search playbooks and materials',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 20),
      for (final match in matches)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LibraryStepRow(
            number: null,
            icon: match.$4 == null
                ? Icons.auto_stories_outlined
                : Icons.article_outlined,
            title: match.$4?.title ?? match.$2.title,
            description: match.$1.title,
            detail: match.$3 == null
                ? 'Playbook'
                : '${match.$2.title} · ${match.$3!.title}',
            actionLabel: 'Open',
            onTap: () {
              _selectPlaylist(match.$1, match.$2);
              if (match.$3 != null) _selectSection(match.$3!.sectionId);
              if (match.$4 != null) _readMaterial(match.$4!);
            },
          ),
        ),
      if (matches.isEmpty)
        const Text('No matches. Try a skill or a playbook name.'),
    ];
  }
}
