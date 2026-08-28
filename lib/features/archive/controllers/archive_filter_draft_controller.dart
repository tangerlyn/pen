enum ArchiveFilterDraftField { color, inkType, brand, fillType }

class ArchiveFilterDraftController {
  List<String> colorFamilies = [];
  List<String> inkTypes = [];
  List<String> brands = [];
  List<String> fillTypes = [];

  void reset({
    required Iterable<String> colorFamilies,
    required Iterable<String> inkTypes,
    required Iterable<String> brands,
    required Iterable<String> fillTypes,
  }) {
    this.colorFamilies = [...colorFamilies];
    this.inkTypes = [...inkTypes];
    this.brands = [...brands];
    this.fillTypes = [...fillTypes];
  }

  List<String> selection(ArchiveFilterDraftField field) => switch (field) {
    ArchiveFilterDraftField.color => colorFamilies,
    ArchiveFilterDraftField.inkType => inkTypes,
    ArchiveFilterDraftField.brand => brands,
    ArchiveFilterDraftField.fillType => fillTypes,
  };

  void toggle(ArchiveFilterDraftField field, String value) {
    final values = selection(field);
    values.contains(value) ? values.remove(value) : values.add(value);
  }

  void clear(ArchiveFilterDraftField field) {
    selection(field).clear();
  }
}
