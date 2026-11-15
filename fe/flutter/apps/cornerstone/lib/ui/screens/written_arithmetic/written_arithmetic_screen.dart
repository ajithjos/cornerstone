import 'package:flutter/material.dart';
import '../../../models/written_arithmetic.dart';
import '../../../services/api_service.dart';
import '../../../services/learning_material_print.dart';
import '../../widgets/activity_package/activity_package_player.dart';

class WrittenArithmeticScreen extends StatefulWidget {
  const WrittenArithmeticScreen({
    super.key,
    required this.apiClient,
    required this.canPrintAnswers,
    this.initialLevelId,
  });
  final CornerstoneApiClient apiClient;
  final bool canPrintAnswers;
  final String? initialLevelId;
  @override
  State<WrittenArithmeticScreen> createState() =>
      _WrittenArithmeticScreenState();
}

class _WrittenArithmeticScreenState extends State<WrittenArithmeticScreen> {
  List<WrittenLevel> _levels = [];
  String? _levelId;
  String _mode = 'assisted';
  String _layout = 'guided';
  int _questionCount = 6;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  WrittenWorksheet? _worksheet;
  ActivityPackageRun? _practice;
  final _practiceKey = GlobalKey<ActivityPackagePageState>();

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final levels = await widget.apiClient.fetchWrittenLevels();
      if (mounted) {
        setState(() {
          _levels = levels;
          _levelId = levels.any((level) => level.id == widget.initialLevelId)
              ? widget.initialLevelId
              : levels.firstOrNull?.id;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_levelId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sheet = await widget.apiClient.generateWrittenWorksheet(
        WrittenWorksheetRequest(
          levelId: _levelId!,
          questionCount: _questionCount,
          mode: _mode,
        ),
      );
      if (mounted) setState(() => _worksheet = sheet);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPractice() async {
    final sheet = _worksheet;
    if (sheet == null) return;
    Future<Map<String, dynamic>> submit(
      List<Map<String, String>> responses,
      bool finish,
    ) => widget.apiClient.checkWrittenWorksheet(
      worksheet: sheet.request,
      responses: {
        for (final response in responses)
          response['item_id']!: response['value']!,
      },
      finish: finish,
    );
    setState(
      () => _practice = ActivityPackageRun(
        id: 'worksheet-${sheet.request.seed}',
        title: sheet.level.title,
        presentation: sheet.presentation,
        onCheck: (responses, _) => submit(responses, false),
        onComplete: (responses, _) => submit(responses, true),
      ),
    );
  }

  Future<void> _print(bool answers) async {
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
          includeAnswers: answers,
          layout: _layout,
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
    final selected = _levels.where((level) => level.id == _levelId).firstOrNull;
    final sheet = _worksheet;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _practice == null ? 'Create a worksheet' : 'Written practice',
        ),
        leading: _practice == null
            ? null
            : IconButton(
                tooltip: 'Back to worksheet',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _practiceKey.currentState?.requestClose(),
              ),
      ),
      body: _practice != null
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ActivityPackagePage(
                    key: _practiceKey,
                    run: _practice!,
                    apiBaseUrl: widget.apiClient.baseUrl,
                    closeLabel: 'Back to worksheet',
                    onClose: (_) => setState(() => _practice = null),
                  ),
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Fresh practice, on paper or on screen',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a skill and create as many new sets as you need. For recorded progress, use Practice in an assigned playbook.',
                    ),
                    const SizedBox(height: 24),
                    if (_levels.isEmpty)
                      OutlinedButton(
                        onPressed: _loadLevels,
                        child: const Text('Reload levels'),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _levelId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Skill and level',
                        ),
                        items: _levels
                            .map(
                              (level) => DropdownMenuItem(
                                value: level.id,
                                child: Text(
                                  level.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _levelId = value),
                      ),
                      if (selected != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Before starting: ${selected.prerequisite}',
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              initialValue: _mode,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'On-screen mode',
                              ),
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
                              decoration: const InputDecoration(
                                labelText: 'Questions',
                              ),
                              items: [4, 6, 12, 20, 24]
                                  .map(
                                    (count) => DropdownMenuItem(
                                      value: count,
                                      child: Text('$count'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _questionCount = value!),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              initialValue: _layout,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Print format',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'guided',
                                  child: Text(
                                    'Guided — working boxes',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'compact',
                                  child: Text(
                                    'Compact — more practice',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() => _layout = value!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _generate,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            sheet == null
                                ? 'Create worksheet'
                                : 'Create a new set',
                          ),
                        ),
                      ),
                    ],
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (sheet != null) ...[
                      const Divider(height: 40),
                      Text(
                        sheet.level.title,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(sheet.level.instructions),
                      const SizedBox(height: 8),
                      Text(
                        '${sheet.request.questionCount} questions • ${sheet.request.mode == 'assisted' ? 'Assisted practice' : 'Assessment'} • Sheet ${sheet.request.seed}',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy ? null : _openPractice,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Open practice'),
                          ),
                          if (learningMaterialPrintingSupported)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _print(false),
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Print worksheet'),
                            ),
                          if (learningMaterialPrintingSupported &&
                              widget.canPrintAnswers)
                            OutlinedButton(
                              onPressed: _busy ? null : () => _print(true),
                              child: const Text('Print with answer key'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
