part of '../../../main.dart';

/// A compact view of the authored hierarchy; selections never assign work.
class LearningLibraryOutline extends StatelessWidget {
  const LearningLibraryOutline({
    super.key,
    required this.pathways,
    required this.selectedPathwayId,
    required this.selectedPlaylistId,
    required this.selectedSessionIndex,
    required this.selectedMaterialId,
    required this.overviewSelected,
    required this.extraSelected,
    required this.onOverview,
    required this.onPathway,
    required this.onPlaylist,
    required this.onSession,
    required this.onExtraPractice,
    required this.onMaterial,
  });
  final List<LibraryWorkspacePathway> pathways;
  final String? selectedPathwayId;
  final String? selectedPlaylistId;
  final int? selectedSessionIndex;
  final String? selectedMaterialId;
  final bool overviewSelected;
  final bool extraSelected;
  final VoidCallback onOverview;
  final ValueChanged<LibraryWorkspacePathway> onPathway;
  final void Function(LibraryWorkspacePathway, LibraryWorkspacePlaylist)
  onPlaylist;
  final void Function(
    LibraryWorkspacePathway,
    LibraryWorkspacePlaylist,
    LibraryWorkspaceSession,
  )
  onSession;
  final ValueChanged<LibraryWorkspacePathway> onExtraPractice;
  final void Function(
    LibraryWorkspacePathway,
    LibraryWorkspacePlaylist,
    LibraryWorkspaceSession,
    LibraryWorkspaceMaterial,
  )
  onMaterial;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEARNING MAP',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pathways → playlists → sessions',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      _LibraryOutlineRow(
        label: 'All pathways',
        icon: Icons.route_outlined,
        selected: overviewSelected,
        onTap: onOverview,
      ),
      const SizedBox(height: 10),
      for (final pathway in pathways) ...[
        _LibraryOutlineRow(
          key: ValueKey('map-pathway-${pathway.pathwayId}'),
          label: pathway.title,
          icon: selectedPathwayId == pathway.pathwayId
              ? Icons.keyboard_arrow_down
              : Icons.chevron_right,
          selected:
              selectedPathwayId == pathway.pathwayId &&
              selectedPlaylistId == null &&
              !extraSelected &&
              selectedMaterialId == null,
          onTap: () => onPathway(pathway),
        ),
        if (selectedPathwayId == pathway.pathwayId) ...[
          for (
            var playlistIndex = 0;
            playlistIndex < pathway.playlists.length;
            playlistIndex++
          ) ...[
            _LibraryOutlineRow(
              key: ValueKey(
                'map-playlist-${pathway.playlists[playlistIndex].playlistId}',
              ),
              label: pathway.playlists[playlistIndex].title,
              number: '${playlistIndex + 1}',
              depth: 1,
              selected:
                  selectedPlaylistId ==
                      pathway.playlists[playlistIndex].playlistId &&
                  selectedSessionIndex == null,
              onTap: () =>
                  onPlaylist(pathway, pathway.playlists[playlistIndex]),
            ),
            if (selectedPlaylistId ==
                pathway.playlists[playlistIndex].playlistId)
              for (final session
                  in pathway.playlists[playlistIndex].sessions) ...[
                _LibraryOutlineRow(
                  key: ValueKey(
                    'map-session-${pathway.playlists[playlistIndex].playlistId}-${session.sessionIndex}',
                  ),
                  label: session.title,
                  number: '${session.sessionIndex}',
                  depth: 2,
                  selected:
                      selectedSessionIndex == session.sessionIndex &&
                      selectedMaterialId == null,
                  onTap: () => onSession(
                    pathway,
                    pathway.playlists[playlistIndex],
                    session,
                  ),
                ),
                if (selectedSessionIndex == session.sessionIndex)
                  for (final material in session.materials)
                    _LibraryOutlineRow(
                      label: material.title,
                      icon: CornerstoneIcons.materialKind(material.kind),
                      depth: 3,
                      selected: selectedMaterialId == material.materialId,
                      onTap: () => onMaterial(
                        pathway,
                        pathway.playlists[playlistIndex],
                        session,
                        material,
                      ),
                    ),
              ],
          ],
          if (pathway.extraPracticeGroups.isNotEmpty)
            _LibraryOutlineRow(
              key: ValueKey('map-extra-${pathway.pathwayId}'),
              label: 'Extra practice by skill',
              icon: Icons.edit_note_outlined,
              depth: 1,
              selected: extraSelected,
              onTap: () => onExtraPractice(pathway),
            ),
        ],
        const SizedBox(height: 6),
      ],
    ],
  );
}

class _LibraryOutlineRow extends StatelessWidget {
  const _LibraryOutlineRow({
    super.key,
    required this.label,
    this.icon,
    this.number,
    this.depth = 0,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final String? number;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 19,
                  child: number != null
                      ? Text(
                          number!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 17,
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w700
                          : depth == 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
