part of '../../../main.dart';

class AssignmentSelection {
  const AssignmentSelection(this.learnerId, this.activityMode);
  final String learnerId;
  final String? activityMode;
}

class AssignMaterialDialog extends StatefulWidget {
  const AssignMaterialDialog({
    super.key,
    required this.title,
    required this.targets,
    this.offerActivityMode = false,
  });
  final String title;
  final List<PlaylistAssignmentTarget> targets;
  final bool offerActivityMode;
  @override
  State<AssignMaterialDialog> createState() => _AssignMaterialDialogState();
}

class _AssignMaterialDialogState extends State<AssignMaterialDialog> {
  String? _learnerId;
  String _mode = 'assisted';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Assign to a student'),
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
          if (widget.offerActivityMode) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: const [
                DropdownMenuItem(
                  value: 'assisted',
                  child: Text('Assisted practice'),
                ),
                DropdownMenuItem(
                  value: 'assessment',
                  child: Text('Assessment'),
                ),
              ],
              onChanged: (value) => setState(() => _mode = value!),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == 'assisted'
                  ? 'The student can check working and receive explanations.'
                  : 'The student works independently and sees corrections after submitting.',
            ),
          ],
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
            : () => Navigator.pop(
                context,
                AssignmentSelection(
                  _learnerId!,
                  widget.offerActivityMode ? _mode : null,
                ),
              ),
        child: const Text('Assign'),
      ),
    ],
  );
}
