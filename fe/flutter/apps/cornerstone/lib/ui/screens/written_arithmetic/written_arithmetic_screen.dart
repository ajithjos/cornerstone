import 'package:flutter/material.dart';

import '../../../models/written_arithmetic.dart';
import '../../../services/api_service.dart';
import '../../../services/learning_material_print.dart';
import 'written_problem_grid.dart';

class WrittenArithmeticScreen extends StatefulWidget {
  const WrittenArithmeticScreen({
    super.key,
    required this.apiClient,
    required this.canPrintAnswers,
  });
  final CornerstoneApiClient apiClient;
  final bool canPrintAnswers;

  @override
  State<WrittenArithmeticScreen> createState() =>
      _WrittenArithmeticScreenState();
}

class _WrittenArithmeticScreenState extends State<WrittenArithmeticScreen> {
  List<WrittenLevel> _levels = [];
  String? _levelId;
  String _mode = 'assisted';
  int _questionCount = 6;
  bool _loading = true;
  bool _busy = false;
  bool _submitted = false;
  String? _error;
  WrittenWorksheet? _worksheet;
  WrittenCheckResult? _result;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, WrittenCellFeedback> _feedback = {};

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLevels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final levels = await widget.apiClient.fetchWrittenLevels();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _levelId = levels.firstOrNull?.id;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final levelId = _levelId;
    if (levelId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sheet = await widget.apiClient.generateWrittenWorksheet(
        WrittenWorksheetRequest(
          levelId: levelId,
          questionCount: _questionCount,
          mode: _mode,
        ),
      );
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      for (final problem in sheet.problems) {
        for (final row in problem.rows) {
          for (final cell in row.cells) {
            if (cell.id != null) {
              _controllers[cell.id!] = TextEditingController();
            }
          }
        }
      }
      setState(() {
        _worksheet = sheet;
        _feedback.clear();
        _result = null;
        _submitted = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check({required bool finish, WrittenProblem? problem}) async {
    final sheet = _worksheet;
    if (sheet == null) return;
    final problemCellIds = problem?.rows
        .expand((row) => row.cells)
        .map((cell) => cell.id)
        .whereType<String>()
        .toSet();
    final responses = <String, String>{
      for (final entry in _controllers.entries)
        if ((problemCellIds == null || problemCellIds.contains(entry.key)) &&
            (finish || entry.value.text.trim().isNotEmpty))
          entry.key: entry.value.text.trim(),
    };
    if (!finish && responses.isEmpty) {
      setState(() => _error = 'Enter a digit in a box, then check your work.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.checkWrittenWorksheet(
        worksheet: sheet.request,
        responses: responses,
        finish: finish,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitted = finish;
        if (problemCellIds == null) {
          _feedback.clear();
        } else {
          _feedback.removeWhere((id, _) => problemCellIds.contains(id));
        }
        _feedback.addEntries(
          result.feedback.map((item) => MapEntry(item.cellId, item)),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print({required bool includeAnswers}) async {
    final sheet = _worksheet;
    if (sheet == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await printGeneratedWorksheet(
        widget.apiClient.writtenWorksheetHtml(
          worksheet: sheet.request,
          includeAnswers: includeAnswers,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = _worksheet;
    final selectedLevel = _levels
        .where((level) => level.id == _levelId)
        .firstOrNull;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Written arithmetic', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Practise the same column methods on screen and on paper. Start with a short set. Correct mistakes before moving to larger numbers.',
        ),
        const SizedBox(height: 6),
        Text(
          'Extra practice • Results are not saved to pathway progress.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        if (_levels.isEmpty)
          OutlinedButton(
            onPressed: _loadLevels,
            child: const Text('Reload practice levels'),
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _levelId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Skill and level'),
            items: _levels
                .map(
                  (level) => DropdownMenuItem(
                    value: level.id,
                    child: Text(level.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _levelId = value),
          ),
          if (selectedLevel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Before starting: ${selectedLevel.prerequisite}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _mode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(
                      value: 'assisted',
                      child: Text(
                        'Assisted practice',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'assessment',
                      child: Text('Assessment'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _mode = value!),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                  initialValue: _questionCount,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Questions'),
                  items: [4, 6, 12]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _questionCount = value!),
                ),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.refresh),
                label: Text(
                  sheet == null ? 'Create practice' : 'Create new practice',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _mode == 'assisted'
                ? 'Assisted: check entered boxes whenever you need help. Explanations appear beside the exercise.'
                : 'Assessment: work independently. Corrections appear only after you submit.',
          ),
          if (sheet != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Create new practice applies the settings above and replaces your current work.',
              ),
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        if (sheet != null) ...[
          const Divider(height: 32),
          Text(sheet.level.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(sheet.level.instructions),
          const SizedBox(height: 8),
          Text(
            '${sheet.request.mode == 'assisted' ? 'Assisted practice' : 'Assessment'} • ${sheet.problems.length} questions • Sheet ${sheet.request.seed}',
            style: theme.textTheme.bodySmall,
          ),
          if (learningMaterialPrintingSupported) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _print(includeAnswers: false),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print worksheet'),
                ),
                if (widget.canPrintAnswers)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _print(includeAnswers: true),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Print with answer key'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (var index = 0; index < sheet.problems.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: WrittenProblemGrid(
                problem: sheet.problems[index],
                number: index + 1,
                controllers: _controllers,
                feedback: _feedback,
                enabled: !_busy && !_submitted,
                onCheck: sheet.request.mode == 'assisted'
                    ? () =>
                          _check(finish: false, problem: sheet.problems[index])
                    : null,
                onChanged: (id) => setState(() {
                  _feedback.remove(id);
                  _result = null;
                }),
              ),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _submitted
                      ? '${_result!.correctCount} of ${_result!.totalCount} boxes correct. Review the corrections above, then create a new set.'
                      : '${_result!.correctCount} boxes correct. Correct the highlighted boxes and continue.',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          if (!_submitted)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (sheet.request.mode == 'assisted')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _check(finish: false),
                    child: const Text('Check entered boxes'),
                  ),
                FilledButton(
                  onPressed: _busy ? null : () => _check(finish: true),
                  child: Text(
                    sheet.request.mode == 'assessment'
                        ? 'Submit assessment'
                        : 'Finish practice',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
