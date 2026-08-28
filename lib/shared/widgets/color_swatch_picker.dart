import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'tap_scale.dart';

/// 표지색 등 고정 팔레트에서 하나를 고르는 원형 스와치 목록.
/// 공책 만들기/표지색 변경 시트에서 공유한다.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.colors,
    required this.selectedHex,
    required this.onSelect,
  });

  /// '#RRGGBB' 형식 hex 문자열 목록.
  final List<String> colors;
  final String selectedHex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        final selected = hex == selectedHex;
        final hex6 = hex.replaceFirst('#', '');
        final color = Color(int.parse('FF$hex6', radix: 16));
        return TapScale(
          onTap: () => onSelect(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
