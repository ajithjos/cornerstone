part of '../../../main.dart';

class AssignmentSelection {
  const AssignmentSelection(this.learnerId);
  final String learnerId;
}

class AssignMaterialDialog extends StatefulWidget {
  const AssignMaterialDialog({
    super.key,
    required this.title,
    required this.targets,
  });
  final String title;
  final List<PlaylistAssignmentTarget> targets;
  @override
  State<AssignMaterialDialog> createState() => _AssignMaterialDialogState();
}

class _AssignMaterialDialogState extends State<AssignMaterialDialog> {
  String? _learnerId;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Assign playbook'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          if (widget.targets.every((target) => target.assignedHere))
            const Text('This is already assigned to every available student.')
          else
            DropdownButtonFormField<String>(
              initialValue: _learnerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Student'),
              hint: const Text('Choose a student'),
              items: widget.targets
                  .map(
                    (target) => DropdownMenuItem(
                      value: target.learnerId,
                      enabled: !target.assignedHere,
                      child: Text(
                        '${target.displayName}${target.assignedHere ? ' — already assigned' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _learnerId = value),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _learnerId == null
            ? null
            : () => Navigator.pop(context, AssignmentSelection(_learnerId!)),
        child: const Text('Assign'),
      ),
    ],
  );
}
