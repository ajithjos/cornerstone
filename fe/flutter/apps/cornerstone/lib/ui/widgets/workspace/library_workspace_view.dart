part of '../../../main.dart';

class _LibraryWorkspaceView extends StatelessWidget {
  const _LibraryWorkspaceView({
    required this.libraryWorkspace,
    required this.documents,
    required this.activeDocument,
    required this.libraryDocumentBusy,
    required this.viewerCanManage,
    required this.onCreateAssignment,
    required this.onOpenLibraryRoute,
  });

  final LibraryWorkspacePayload libraryWorkspace;
  final LibraryDocumentsPayload? documents;
  final LibraryDocumentData? activeDocument;
  final bool libraryDocumentBusy;
  final bool viewerCanManage;
  final Future<void> Function(String learnerId, String playlistId)
  onCreateAssignment;
  final ValueChanged<String> onOpenLibraryRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeBySourcePath = {
      for (final document
          in documents?.documents ?? const <LibraryDocumentSummary>[])
        document.sourcePath: document.routePath,
    };
    final totalMaterials = libraryWorkspace.pathways.fold<int>(
      0,
      (count, pathway) =>
          count +
          pathway.playlists.fold<int>(
            0,
            (playlistCount, playlist) => playlistCount + playlist.materialCount,
          ),
    );

    if (MediaQuery.sizeOf(context).width > 1180) {
      return _LibraryPlanningDesktop(
        libraryWorkspace: libraryWorkspace,
        documents: documents,
        activeDocument: activeDocument,
        libraryDocumentBusy: libraryDocumentBusy,
        viewerCanManage: viewerCanManage,
        onCreateAssignment: onCreateAssignment,
        onOpenLibraryRoute: onOpenLibraryRoute,
        totalMaterials: totalMaterials,
      );
    }

    Widget buildNavigatorPanel() {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pathway browser', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Browse the backend-owned pathway contract, inspect delivery shape by canonical material kind, and assign the right playlist directly from each learner target.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (libraryWorkspace.pathways.isEmpty)
              Text(
                'No pathways are available yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...libraryWorkspace.pathways.map((pathway) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pathway.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          pathway.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PillBadge(
                              text: pathway.areaTitle,
                              color: theme.colorScheme.secondaryContainer,
                              textColor: theme.colorScheme.onSecondaryContainer,
                            ),
                            _PillBadge(
                              text:
                                  'Ages ${pathway.recommendedAgeMin}-${pathway.recommendedAgeMax}',
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              textColor: theme.colorScheme.primary,
                            ),
                            _PillBadge(
                              text: '${pathway.playlistCount} playlists',
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              textColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (pathway.routePath != null)
                              FilledButton.icon(
                                onPressed: () =>
                                    onOpenLibraryRoute(pathway.routePath!),
                                icon: const Icon(
                                  CornerstoneIcons.document,
                                  size: 18,
                                ),
                                label: const Text('Open route document'),
                              ),
                            if (pathway.entryPoints.isNotEmpty)
                              _PillBadge(
                                text:
                                    'Recommended start: ${pathway.entryPoints.first.playlistTitle}',
                                color: theme.colorScheme.tertiaryContainer,
                                textColor:
                                    theme.colorScheme.onTertiaryContainer,
                              ),
                          ],
                        ),
                        if (pathway.playlists.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          ...pathway.playlists.map((playlist) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.58,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playlist.title,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              playlist.description,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      _ContractChip(
                                        domain: 'status',
                                        value:
                                            playlist
                                                .deliveryShape
                                                .requiresAdultSupport
                                            ? 'adult_guided'
                                            : 'learner_ready',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _PillBadge(
                                        text: 'Age ${playlist.recommendedAge}',
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.12),
                                        textColor: theme.colorScheme.primary,
                                      ),
                                      _PillBadge(
                                        text: '${playlist.durationDays} days',
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.12),
                                        textColor: theme.colorScheme.primary,
                                      ),
                                      _PillBadge(
                                        text:
                                            '${playlist.materialCount} materials',
                                        color: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        textColor: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                      if (playlist
                                              .deliveryShape
                                              .lessonNoteCount >
                                          0)
                                        _PillBadge(
                                          text:
                                              '${playlist.deliveryShape.lessonNoteCount} lesson notes',
                                          color: _materialKindBackgroundColor(
                                            theme,
                                            'lesson_note',
                                          ),
                                          textColor:
                                              _materialKindForegroundColor(
                                                theme,
                                                'lesson_note',
                                              ),
                                        ),
                                      if (playlist
                                              .deliveryShape
                                              .teachingNoteCount >
                                          0)
                                        _PillBadge(
                                          text:
                                              '${playlist.deliveryShape.teachingNoteCount} teaching notes',
                                          color: _materialKindBackgroundColor(
                                            theme,
                                            'teaching_note',
                                          ),
                                          textColor:
                                              _materialKindForegroundColor(
                                                theme,
                                                'teaching_note',
                                              ),
                                        ),
                                      if (playlist
                                              .deliveryShape
                                              .worksheetCount >
                                          0)
                                        _PillBadge(
                                          text:
                                              '${playlist.deliveryShape.worksheetCount} worksheets',
                                          color: _materialKindBackgroundColor(
                                            theme,
                                            'worksheet',
                                          ),
                                          textColor:
                                              _materialKindForegroundColor(
                                                theme,
                                                'worksheet',
                                              ),
                                        ),
                                      if (playlist.deliveryShape.drillCount > 0)
                                        _PillBadge(
                                          text:
                                              '${playlist.deliveryShape.drillCount} drills',
                                          color: _materialKindBackgroundColor(
                                            theme,
                                            'drill',
                                          ),
                                          textColor:
                                              _materialKindForegroundColor(
                                                theme,
                                                'drill',
                                              ),
                                        ),
                                      if (playlist
                                              .deliveryShape
                                              .quickCheckCount >
                                          0)
                                        _PillBadge(
                                          text:
                                              '${playlist.deliveryShape.quickCheckCount} quick checks',
                                          color: _materialKindBackgroundColor(
                                            theme,
                                            'quick_check',
                                          ),
                                          textColor:
                                              _materialKindForegroundColor(
                                                theme,
                                                'quick_check',
                                              ),
                                        ),
                                      _PillBadge(
                                        text:
                                            '${playlist.deliveryShape.estimatedTotalMinutes} min total',
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        textColor:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                  if (playlist
                                      .assignmentTargets
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      'Assignment targets',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: playlist.assignmentTargets
                                          .map((target) {
                                            return ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                minWidth: 220,
                                                maxWidth: 320,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.32),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                target
                                                                    .displayName,
                                                                style: theme
                                                                    .textTheme
                                                                    .titleSmall,
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                'Age ${target.currentAge} · ${target.currentLevel}',
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (target.recommended)
                                                          _PillBadge(
                                                            text: 'Recommended',
                                                            color: theme
                                                                .colorScheme
                                                                .secondaryContainer,
                                                            textColor: theme
                                                                .colorScheme
                                                                .onSecondaryContainer,
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      target.statusLabel,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                    if (target
                                                        .assignedAssignmentTitles
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Assigned: ${target.assignedAssignmentTitles.join(', ')}',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                    if (viewerCanManage) ...[
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      FilledButton.tonal(
                                                        onPressed:
                                                            target.assignedHere
                                                            ? null
                                                            : () => onCreateAssignment(
                                                                target
                                                                    .learnerId,
                                                                playlist
                                                                    .playlistId,
                                                              ),
                                                        child: Text(
                                                          target.assignedHere
                                                              ? 'Already assigned here'
                                                              : 'Assign to ${target.displayName}',
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(growable: false),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  ...playlist.sessions.map((session) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.32),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${session.sessionIndex}. ${session.title}',
                                              style: theme.textTheme.titleSmall,
                                            ),
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
                                                  text:
                                                      '${session.estimatedMinutes} min',
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  textColor: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                if (session
                                                    .requiresAdultSupport)
                                                  _PillBadge(
                                                    text: 'Adult support',
                                                    color: theme
                                                        .colorScheme
                                                        .tertiaryContainer,
                                                    textColor: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ...session.materialsByKind.map(
                                              (group) =>
                                                  _WorkspaceMaterialGroupPanel(
                                                    group: group,
                                                    onOpenLibraryRoute:
                                                        onOpenLibraryRoute,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      if (playlist.routePath != null)
                                        TextButton(
                                          onPressed: () => onOpenLibraryRoute(
                                            playlist.routePath!,
                                          ),
                                          child: const Text('Open playlist'),
                                        ),
                                      if (playlist.assignmentTargets.isEmpty)
                                        Text(
                                          'No learner targets are available for this playlist yet.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    }

    Widget buildReaderPanel() {
      return _SurfaceCard(
        child: _LibraryDocumentReader(
          document: activeDocument,
          busy: libraryDocumentBusy,
          routeBySourcePath: routeBySourcePath,
          onOpenLibraryRoute: onOpenLibraryRoute,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1240;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            _PageHeroCard(
              eyebrow: 'Library',
              title: 'Pathway planning workspace',
              description:
                  'Browse the backend-derived pathway catalog, inspect delivery shape and assignment targets, then read the authored markdown without leaving the app.',
              chips: [
                _StatChip(
                  label: 'Pathways',
                  value: '${libraryWorkspace.pathways.length}',
                  icon: CornerstoneIcons.pathway,
                ),
                _StatChip(
                  label: 'Documents',
                  value: '${documents?.documents.length ?? 0}',
                  icon: CornerstoneIcons.document,
                ),
                _StatChip(
                  label: 'Materials',
                  value: '$totalMaterials',
                  icon: CornerstoneIcons.lessonNote,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: buildNavigatorPanel()),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: buildReaderPanel()),
                ],
              )
            else ...[
              buildNavigatorPanel(),
              const SizedBox(height: 20),
              buildReaderPanel(),
            ],
          ],
        );
      },
    );
  }
}
