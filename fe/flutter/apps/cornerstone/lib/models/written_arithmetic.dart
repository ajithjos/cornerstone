class WrittenLevel {
  const WrittenLevel({
    required this.id,
    required this.title,
    required this.operation,
    required this.instructions,
    required this.prerequisite,
  });
  final String id;
  final String title;
  final String operation;
  final String instructions;
  final String prerequisite;

  factory WrittenLevel.fromJson(Map<String, dynamic> json) => WrittenLevel(
    id: json['id'] as String,
    title: json['title'] as String,
    operation: json['operation'] as String,
    instructions: json['instructions'] as String,
    prerequisite: json['prerequisite'] as String,
  );
}

class WrittenWorksheetRequest {
  const WrittenWorksheetRequest({
    required this.levelId,
    required this.questionCount,
    required this.mode,
    this.seed,
  });
  final String levelId;
  final int questionCount;
  final String mode;
  final int? seed;

  factory WrittenWorksheetRequest.fromJson(Map<String, dynamic> json) =>
      WrittenWorksheetRequest(
        levelId: json['level_id'] as String,
        questionCount: json['question_count'] as int,
        mode: json['mode'] as String,
        seed: json['seed'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'level_id': levelId,
    'question_count': questionCount,
    'mode': mode,
    'seed': seed,
  };
}

class WrittenWorksheet {
  const WrittenWorksheet({
    required this.request,
    required this.level,
    required this.problems,
  });
  final WrittenWorksheetRequest request;
  final WrittenLevel level;
  final List<WrittenProblem> problems;

  factory WrittenWorksheet.fromJson(Map<String, dynamic> json) =>
      WrittenWorksheet(
        request: WrittenWorksheetRequest.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
        level: WrittenLevel.fromJson(json['level'] as Map<String, dynamic>),
        problems: (json['problems'] as List)
            .map(
              (item) => WrittenProblem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class WrittenProblem {
  const WrittenProblem({
    required this.id,
    required this.prompt,
    required this.columns,
    required this.rows,
  });
  final String id;
  final String prompt;
  final int columns;
  final List<WrittenRow> rows;

  factory WrittenProblem.fromJson(Map<String, dynamic> json) => WrittenProblem(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    columns: json['columns'] as int,
    rows: (json['rows'] as List)
        .map((item) => WrittenRow.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class WrittenRow {
  const WrittenRow({
    required this.label,
    required this.kind,
    required this.cells,
  });
  final String label;
  final String kind;
  final List<WrittenCell> cells;

  factory WrittenRow.fromJson(Map<String, dynamic> json) => WrittenRow(
    label: json['label'] as String,
    kind: json['kind'] as String,
    cells: (json['cells'] as List)
        .map((item) => WrittenCell.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class WrittenCell {
  const WrittenCell({
    required this.id,
    required this.text,
    required this.maxDigits,
  });
  final String? id;
  final String text;
  final int maxDigits;

  factory WrittenCell.fromJson(Map<String, dynamic> json) => WrittenCell(
    id: json['id'] as String?,
    text: json['text'] as String,
    maxDigits: json['max_digits'] as int,
  );
}

class WrittenCellFeedback {
  const WrittenCellFeedback({
    required this.cellId,
    required this.correct,
    required this.expected,
    required this.explanation,
  });
  final String cellId;
  final bool correct;
  final String? expected;
  final String explanation;

  factory WrittenCellFeedback.fromJson(Map<String, dynamic> json) =>
      WrittenCellFeedback(
        cellId: json['cell_id'] as String,
        correct: json['correct'] as bool,
        expected: json['expected'] as String?,
        explanation: json['explanation'] as String,
      );
}

class WrittenCheckResult {
  const WrittenCheckResult({
    required this.correctCount,
    required this.totalCount,
    required this.complete,
    required this.feedback,
  });
  final int correctCount;
  final int totalCount;
  final bool complete;
  final List<WrittenCellFeedback> feedback;

  factory WrittenCheckResult.fromJson(Map<String, dynamic> json) =>
      WrittenCheckResult(
        correctCount: json['correct_count'] as int,
        totalCount: json['total_count'] as int,
        complete: json['complete'] as bool,
        feedback: (json['feedback'] as List)
            .map(
              (item) =>
                  WrittenCellFeedback.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
