import 'learning_material_print_payload.dart';

bool get learningMaterialPrintingSupported => false;

Future<void> printLearningMaterial(LearningMaterialPrintPayload payload) async {
  throw UnsupportedError('Native browser printing is only available on web.');
}

Future<void> printLearningMaterialSet(
  LearningMaterialPrintSetPayload payload,
) async {
  throw UnsupportedError('Native browser printing is only available on web.');
}
