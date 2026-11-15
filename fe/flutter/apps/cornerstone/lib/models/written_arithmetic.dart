import 'activity_presentation.dart';

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

/// The host owns worksheet setup and printing. The package owns its rendering.
class WrittenWorksheet {
  const WrittenWorksheet({
    required this.request,
    required this.level,
    required this.presentation,
  });
  final WrittenWorksheetRequest request;
  final WrittenLevel level;
  final ActivityPresentation presentation;
  factory WrittenWorksheet.fromJson(Map<String, dynamic> json) =>
      WrittenWorksheet(
        request: WrittenWorksheetRequest.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
        level: WrittenLevel.fromJson(json['level'] as Map<String, dynamic>),
        presentation: ActivityPresentation.fromJson(
          json['presentation'] as Map<String, dynamic>,
        ),
      );
}
