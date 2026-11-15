import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/written_arithmetic.dart';

class WrittenProblemGrid extends StatelessWidget {
  const WrittenProblemGrid({
    super.key,
    required this.problem,
    required this.number,
    required this.controllers,
    required this.feedback,
    required this.enabled,
    required this.onChanged,
    this.onCheck,
  });

  final WrittenProblem problem;
  final int number;
  final Map<String, TextEditingController> controllers;
  final Map<String, WrittenCellFeedback> feedback;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corrections = <({String label, WrittenCellFeedback feedback})>[];
    for (final row in problem.rows) {
      for (var column = 0; column < row.cells.length; column++) {
        final correction = feedback[row.cells[column].id];
        if (correction != null && !correction.correct) {
          corrections.add((
            label: '${row.label}, box ${column + 1}',
            feedback: correction,
          ));
        }
      }
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. ${problem.prompt}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in problem.rows)
                      Container(
                        decoration:
                            row.kind == 'answer' || row.kind == 'dividend'
                            ? BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: theme.colorScheme.onSurface,
                                    width: 1.5,
                                  ),
                                ),
                              )
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 128,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  row.label,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ),
                            for (
                              var column = 0;
                              column < row.cells.length;
                              column++
                            )
                              _cell(context, row, column),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onCheck != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: ValueKey('check-${problem.id}'),
                onPressed: enabled ? onCheck : null,
                child: const Text('Check this exercise'),
              ),
            ],
            if (corrections.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final correction in corrections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${correction.label}: ${correction.feedback.explanation}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, WrittenRow row, int column) {
    final theme = Theme.of(context);
    final cell = row.cells[column];
    final cellId = cell.id;
    final correction = feedback[cellId];
    final color = correction == null
        ? theme.colorScheme.outlineVariant
        : correction.correct
        ? Colors.green.shade700
        : theme.colorScheme.error;
    final font = TextStyle(
      fontFamily: 'monospace',
      fontSize: row.kind == 'annotation' ? 19 : 24,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: 50,
      height: 52,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: cellId == null
            ? Center(child: Text(cell.text, style: font))
            : Semantics(
                label:
                    'Question $number, ${row.label}, box ${column + 1}${correction == null
                        ? ''
                        : correction.correct
                        ? ', correct'
                        : ', needs correction'}',
                child: Stack(
                  children: [
                    TextField(
                      key: ValueKey(cellId),
                      controller: controllers[cellId],
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(cell.maxDigits),
                      ],
                      textAlign: TextAlign.center,
                      style: font,
                      onChanged: (_) => onChanged(cellId),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: correction == null
                            ? theme.colorScheme.surface
                            : color.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: color),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: color),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: color),
                        ),
                      ),
                    ),
                    if (correction != null)
                      Positioned(
                        top: 1,
                        right: 1,
                        child: IgnorePointer(
                          child: Icon(
                            correction.correct
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 13,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
