class LearningMaterialPrintPayload {
  const LearningMaterialPrintPayload({
    required this.sessionTitle,
    required this.materialTitle,
    required this.kindLabel,
    required this.estimatedMinutes,
    required this.body,
  });

  final String sessionTitle;
  final String materialTitle;
  final String kindLabel;
  final int estimatedMinutes;
  final String body;
}

class LearningMaterialPrintSetPayload {
  const LearningMaterialPrintSetPayload({
    required this.title,
    required this.materials,
  });

  final String title;
  final List<LearningMaterialPrintPayload> materials;
}
