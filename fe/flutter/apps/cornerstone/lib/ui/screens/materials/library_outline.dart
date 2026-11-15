part of '../../../main.dart';

/// The map is deliberately only pathway → playbook. Study sections live inside
/// the selected playbook, alongside the materials they contain.
class LearningLibraryOutline extends StatelessWidget {
  const LearningLibraryOutline({
    super.key,
    required this.pathways,
    required this.selectedPathwayId,
    required this.selectedPlaylistId,
    required this.onOverview,
    required this.onPathway,
    required this.onPlaylist,
  });
  final List<LibraryWorkspacePathway> pathways;
  final String? selectedPathwayId;
  final String? selectedPlaylistId;
  final VoidCallback onOverview;
  final ValueChanged<LibraryWorkspacePathway> onPathway;
  final void Function(LibraryWorkspacePathway, LibraryWorkspacePlaylist)
  onPlaylist;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Text('LEARNING MAP'),
      ),
      ListTile(
        dense: true,
        title: const Text('All pathways'),
        leading: const Icon(Icons.route_outlined, size: 20),
        selected: selectedPathwayId == null,
        onTap: onOverview,
      ),
      const SizedBox(height: 12),
      for (final pathway in pathways) ...[
        ListTile(
          key: ValueKey('map-pathway-${pathway.pathwayId}'),
          dense: true,
          title: Text(pathway.title),
          trailing: Icon(
            selectedPathwayId == pathway.pathwayId
                ? Icons.expand_more
                : Icons.chevron_right,
            size: 18,
          ),
          selected:
              selectedPathwayId == pathway.pathwayId &&
              selectedPlaylistId == null,
          onTap: () => onPathway(pathway),
        ),
        if (selectedPathwayId == pathway.pathwayId)
          for (var i = 0; i < pathway.playlists.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ListTile(
                key: ValueKey(
                  'map-playlist-${pathway.playlists[i].playlistId}',
                ),
                dense: true,
                leading: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                minLeadingWidth: 12,
                title: Text(
                  pathway.playlists[i].title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                selected: selectedPlaylistId == pathway.playlists[i].playlistId,
                onTap: () => onPlaylist(pathway, pathway.playlists[i]),
              ),
            ),
      ],
    ],
  );
}
