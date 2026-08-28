import 'package:flutter_test/flutter_test.dart';
import 'package:nibpen/features/archive/controllers/archive_filter_draft_controller.dart';

void main() {
  test('filter edits stay in a draft until the caller commits them', () {
    final originalBrands = ['Pilot'];
    final controller = ArchiveFilterDraftController()
      ..reset(
        colorFamilies: const ['파랑'],
        inkTypes: const ['normal'],
        brands: originalBrands,
        fillTypes: const [],
      );

    controller.toggle(ArchiveFilterDraftField.brand, 'Sailor');
    controller.clear(ArchiveFilterDraftField.color);

    expect(controller.brands, ['Pilot', 'Sailor']);
    expect(controller.colorFamilies, isEmpty);
    expect(originalBrands, ['Pilot']);
  });
}
