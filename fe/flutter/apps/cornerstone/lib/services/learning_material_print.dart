import 'learning_material_print_impl_stub.dart'
    if (dart.library.js_interop) 'learning_material_print_impl_web.dart'
    as impl;
import 'learning_material_print_payload.dart';

export 'learning_material_print_payload.dart';

bool get learningMaterialPrintingSupported =>
    impl.learningMaterialPrintingSupported;

/// Opens the print window immediately, then loads trusted backend print HTML.
Future<void> printGeneratedWorksheet(Future<String> html) =>
    impl.printGeneratedWorksheet(html);

Future<void> printLearningMaterial(LearningMaterialPrintPayload payload) async {
  await impl.printLearningMaterial(payload);
}

Future<void> printLearningMaterialSet(
  LearningMaterialPrintSetPayload payload,
) async {
  await impl.printLearningMaterialSet(payload);
}
