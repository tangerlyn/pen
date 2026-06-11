import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ink_swatch_shape.dart';

const _kShapeKey = 'ink_swatch_shape';

class InkSwatchShapeNotifier extends StateNotifier<InkSwatchShape> {
  InkSwatchShapeNotifier() : super(InkSwatchShape.circle) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kShapeKey);
    if (name != null) {
      state = InkSwatchShape.values.firstWhere(
        (s) => s.name == name,
        orElse: () => InkSwatchShape.circle,
      );
    }
  }

  Future<void> setShape(InkSwatchShape shape) async {
    state = shape;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShapeKey, shape.name);
  }
}

final inkSwatchShapeProvider =
    StateNotifierProvider<InkSwatchShapeNotifier, InkSwatchShape>(
  (ref) => InkSwatchShapeNotifier(),
);
