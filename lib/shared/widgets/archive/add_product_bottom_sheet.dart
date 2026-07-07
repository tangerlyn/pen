import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/providers.dart';
import '../../../features/archive/providers/archive_provider.dart';
import '../center_toast.dart';

// ── 상수 ─────────────────────────────────────────────────────────────────────

const _kInkTypeLabels = ['일반', '펄', '테'];
const _kInkTypeValues = ['normal', 'shimmer', 'sheen'];

const _kNibMaterials = ['금닙 14K', '금닙 18K', '금닙 21K', '스틸닙', '기타'];
const _kNibSizes = ['EF', 'F', 'M', 'B', 'BB'];
const _kFillTypes = ['카트리지·컨버터', '피스톤', '아이드로퍼', '진공'];

// ── 진입 함수 ─────────────────────────────────────────────────────────────────

void showAddProductSheet(
  BuildContext context, {
  String initialType = 'ink',
  String initialName = '',
  void Function(String id, String displayName)? onAdded,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddProductBottomSheet(
      initialType: initialType,
      initialName: initialName,
      onAdded: onAdded,
    ),
  );
}

// ── 메인 위젯 ─────────────────────────────────────────────────────────────────

class AddProductBottomSheet extends ConsumerStatefulWidget {
  const AddProductBottomSheet({
    super.key,
    this.initialType = 'ink',
    this.initialName = '',
    this.onAdded,
  });

  final String initialType;
  final String initialName;
  final void Function(String id, String displayName)? onAdded;

  @override
  ConsumerState<AddProductBottomSheet> createState() =>
      _AddProductBottomSheetState();
}

class _AddProductBottomSheetState extends ConsumerState<AddProductBottomSheet> {
  late String _type;
  bool _isSaving = false;

  // 공통
  final _brandCtrl = TextEditingController();

  // 잉크
  final _inkNameCtrl = TextEditingController();
  String? _inkTypeValue;
  Color _inkColor = const Color(0xFF1565C0);

  // 자동완성
  List<String> _allBrands = [];
  List<String> _allNames = [];
  bool _suggestionsLoaded = false;
  List<String> _brandSuggestions = [];
  List<String> _nameSuggestions = [];
  Timer? _brandDebounce;
  Timer? _nameDebounce;

  // 만년필
  final _penModelCtrl = TextEditingController();
  String? _nibMaterial;
  final Set<String> _nibSizes = {};
  String? _fillType;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (widget.initialName.isNotEmpty) {
      switch (_type) {
        case 'ink':
          _inkNameCtrl.text = widget.initialName;
        case 'pen':
          _penModelCtrl.text = widget.initialName;
      }
    }
    if (_type == 'ink') _loadSuggestions();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _inkNameCtrl.dispose();
    _penModelCtrl.dispose();
    _brandDebounce?.cancel();
    _nameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (_suggestionsLoaded) return;
    _suggestionsLoaded = true;
    try {
      final result =
          await ref.read(archiveRepoProvider).getInkFieldSuggestions();
      if (mounted) {
        setState(() {
          _allBrands = result.brands;
          _allNames = result.names;
        });
      }
    } catch (_) {}
  }

  void _onBrandChanged(String value) {
    _brandDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _brandSuggestions = []);
      return;
    }
    _brandDebounce = Timer(const Duration(milliseconds: 200), () {
      final lower = value.toLowerCase();
      final matches = _allBrands
          .where((b) => b.toLowerCase().contains(lower))
          .take(6)
          .toList();
      if (mounted) setState(() => _brandSuggestions = matches);
    });
  }

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _nameSuggestions = []);
      return;
    }
    _nameDebounce = Timer(const Duration(milliseconds: 200), () {
      final lower = value.toLowerCase();
      final matches = _allNames
          .where((n) => n.toLowerCase().contains(lower))
          .take(6)
          .toList();
      if (mounted) setState(() => _nameSuggestions = matches);
    });
  }

  void _selectBrand(String value) {
    _brandCtrl.text = value;
    _brandDebounce?.cancel();
    setState(() => _brandSuggestions = []);
  }

  void _selectName(String value) {
    _inkNameCtrl.text = value;
    _nameDebounce?.cancel();
    setState(() => _nameSuggestions = []);
  }

  bool get _isValid {
    final brand = _brandCtrl.text.trim();
    if (brand.isEmpty) return false;
    switch (_type) {
      case 'ink':
        return _inkNameCtrl.text.trim().isNotEmpty && _inkTypeValue != null;
      case 'pen':
        return _penModelCtrl.text.trim().isNotEmpty &&
            _nibMaterial != null &&
            _nibSizes.isNotEmpty &&
            _fillType != null;
    }
    return false;
  }

  Future<void> _submit() async {
    if (!_isValid || _isSaving) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(archiveRepoProvider);
      String id;
      String displayName;
      final brand = _brandCtrl.text.trim();

      switch (_type) {
        case 'ink':
          final name = _inkNameCtrl.text.trim();
          final exists = await repo.inkExists(brand, name);
          if (exists) {
            if (mounted) {
              showCenterToast(context, message: '이미 등록된 잉크입니다.');
            }
            return;
          }
          id = await repo.addInk(
            uid: uid,
            brand: brand,
            name: name,
            colorFamily: _colorFamilyFromColor(_inkColor),
            inkType: _inkTypeValue!,
            hexColor: _colorToHex(_inkColor),
          );
          displayName = '$brand $name';

        case 'pen':
          final model = _penModelCtrl.text.trim();
          id = await repo.addPen(
            uid: uid,
            brand: brand,
            modelName: model,
            nibMaterial: _nibMaterial!,
            nibSizes: _nibSizes.toList(),
            fillType: _fillType!,
          );
          displayName = '$brand $model';

        default:
          return;
      }

      ref.invalidate(archiveProvider);

      if (mounted) {
        Navigator.pop(context);
        widget.onAdded?.call(id, displayName);
      }
    } catch (e) {
      if (mounted) {
        showCenterToast(context,
            message: '등록 실패: $e', icon: Icons.error_outline, iconColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 색상 유틸 ─────────────────────────────────────────────────────────────

  static String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  static String _colorFamilyFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final h = hsv.hue;
    final s = hsv.saturation;
    final v = hsv.value;
    if (s < 0.12 || v < 0.12) return '무채색';
    if (h < 20 || h >= 340) return '레드';
    if (h < 45) return '오렌지';
    if (h < 70) return '옐로우';
    if (h < 160) return '그린';
    if (h < 200) return '시안';
    if (h < 260) return '블루';
    if (h < 290) return '퍼플';
    return '핑크';
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 16, bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              _header(),
              const Divider(height: 1),
              _typeSelector(),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: switch (_type) {
                    'pen' => _penForm(),
                    _ => _inkForm(),
                  },
                ),
              ),
              _submitBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 공통 UI ──────────────────────────────────────────────────────────────

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                '제품 등록',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _typeSelector() {
    const types = [('ink', '잉크'), ('pen', '만년필')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: types.map((t) {
          final selected = _type == t.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _type = t.$1;
                    _brandCtrl.clear();
                    _brandSuggestions = [];
                    _nameSuggestions = [];
                  });
                  if (t.$1 == 'ink') _loadSuggestions();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _submitBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isValid && !_isSaving ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.chipBackground,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('아카이브에 등록하기',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  // ── 잉크 폼 ──────────────────────────────────────────────────────────────

  Widget _inkForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('브랜드명', _brandCtrl, '예: PILOT, Sailor, Diamine',
              onChanged: _onBrandChanged),
          _suggestionRow(_brandSuggestions, _selectBrand),
          const SizedBox(height: 14),
          _field('잉크 이름', _inkNameCtrl, '예: Iroshizuku 쓰유쿠사',
              onChanged: _onNameChanged),
          _suggestionRow(_nameSuggestions, _selectName),
          const SizedBox(height: 16),
          _sectionLabel('잉크 타입 *'),
          _chipGroup(
            items: _kInkTypeLabels,
            selected: _inkTypeValue != null
                ? _kInkTypeLabels[_kInkTypeValues.indexOf(_inkTypeValue!)]
                : null,
            onTap: (label) {
              final idx = _kInkTypeLabels.indexOf(label);
              setState(() =>
                  _inkTypeValue = idx >= 0 ? _kInkTypeValues[idx] : label);
            },
          ),
          const SizedBox(height: 16),
          _sectionLabel('대표 색상 *'),
          const Text(
            '실제 잉크 색상과 최대한 비슷하게 선택해주세요',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          _InkColorPicker(
            color: _inkColor,
            onChanged: (c) => setState(() => _inkColor = c),
          ),
          const SizedBox(height: 8),
        ],
      );

  // ── 만년필 폼 ─────────────────────────────────────────────────────────────

  Widget _penForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('브랜드명', _brandCtrl, '예: PILOT, LAMY, Pelikan'),
          const SizedBox(height: 14),
          _field('모델명', _penModelCtrl, '예: Custom 74, Safari'),
          const SizedBox(height: 16),
          _sectionLabel('닙 소재 *'),
          _chipGroup(
            items: _kNibMaterials,
            selected: _nibMaterial,
            onTap: (v) => setState(() => _nibMaterial = v),
          ),
          const SizedBox(height: 16),
          _sectionLabel('닙 사이즈 * (복수 선택 가능)'),
          _multiChipGroup(
            items: _kNibSizes,
            selected: _nibSizes,
            onTap: (v) => setState(() {
              if (_nibSizes.contains(v)) {
                _nibSizes.remove(v);
              } else {
                _nibSizes.add(v);
              }
            }),
          ),
          const SizedBox(height: 16),
          _sectionLabel('충전 방식 *'),
          _chipGroup(
            items: _kFillTypes,
            selected: _fillType,
            onTap: (v) => setState(() => _fillType = v),
          ),
          const SizedBox(height: 8),
        ],
      );

  // ── 공통 빌더 ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 14),
            onChanged: (v) {
              setState(() {});
              onChanged?.call(v);
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.chipBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      );

  Widget _suggestionRow(List<String> items, ValueChanged<String> onSelect) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => onSelect(items[i]),
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(10) : Radius.zero,
                  bottom: i == items.length - 1
                      ? const Radius.circular(10)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(items[i],
                            style: const TextStyle(fontSize: 14)),
                      ),
                      const Icon(Icons.north_west,
                          size: 14, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 14, endIndent: 14),
            ],
          );
        }),
      ),
    );
  }

  Widget _chipGroup({
    required List<String> items,
    required String? selected,
    required void Function(String) onTap,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.chipBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _multiChipGroup({
    required List<String> items,
    required Set<String> selected,
    required void Function(String) onTap,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = selected.contains(item);
          return GestureDetector(
            onTap: () => onTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.chipBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── 잉크 색상 피커 ────────────────────────────────────────────────────────────

class _InkColorPicker extends StatefulWidget {
  const _InkColorPicker({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_InkColorPicker> createState() => _InkColorPickerState();
}

class _InkColorPickerState extends State<_InkColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  void _updateSV(Offset pos, double width, double height) {
    final s = (pos.dx / width).clamp(0.0, 1.0);
    final v = (1.0 - pos.dy / height).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
    widget.onChanged(_hsv.toColor());
  }

  void _updateHue(double dx, double width) {
    final h = (dx / width * 360.0).clamp(0.0, 360.0);
    setState(() => _hsv = _hsv.withHue(h));
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final previewColor = _hsv.toColor();
    final onPreview = previewColor.computeLuminance() > 0.35
        ? Colors.black87
        : Colors.white;

    return Column(
      children: [
        // SV 영역 — 가로 전체, 높이는 가로의 60%
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth;
          final h = w * 0.60;
          return GestureDetector(
            onPanStart: (d) => _updateSV(d.localPosition, w, h),
            onPanUpdate: (d) => _updateSV(d.localPosition, w, h),
            onTapDown: (d) => _updateSV(d.localPosition, w, h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(w, h),
                painter: _SvPainter(
                  hue: _hsv.hue,
                  s: _hsv.saturation,
                  v: _hsv.value,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        // 색조(H) 슬라이더
        LayoutBuilder(builder: (_, c) {
          final width = c.maxWidth;
          return GestureDetector(
            onPanStart: (d) => _updateHue(d.localPosition.dx, width),
            onPanUpdate: (d) => _updateHue(d.localPosition.dx, width),
            onTapDown: (d) => _updateHue(d.localPosition.dx, width),
            child: CustomPaint(
              size: Size(width, 28),
              painter: _HuePainter(hue: _hsv.hue),
            ),
          );
        }),
        const SizedBox(height: 14),
        // 선택된 색상 미리보기 — 풀 너비 박스
        Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            color: previewColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${previewColor.red.toRadixString(16).padLeft(2, '0')}'
                '${previewColor.green.toRadixString(16).padLeft(2, '0')}'
                '${previewColor.blue.toRadixString(16).padLeft(2, '0')}'
                    .toUpperCase(),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: onPreview),
              ),
              const SizedBox(height: 2),
              Text(
                '선택된 색상',
                style: TextStyle(fontSize: 11, color: onPreview.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── CustomPainter: SV 영역 ────────────────────────────────────────────────────

class _SvPainter extends CustomPainter {
  const _SvPainter({required this.hue, required this.s, required this.v});
  final double hue, s, v;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    // 흰색 → 순색 (좌→우, 채도)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );

    // 투명 → 검정 (위→아래, 명도)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    // 선택 위치 원
    final cx = s * size.width;
    final cy = (1 - v) * size.height;
    canvas
      ..drawCircle(Offset(cx, cy), 10,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5)
      ..drawCircle(Offset(cx, cy), 10,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_SvPainter old) =>
      old.hue != hue || old.s != s || old.v != v;
}

// ── CustomPainter: 색조 슬라이더 ──────────────────────────────────────────────

class _HuePainter extends CustomPainter {
  const _HuePainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // 레인보우 그라디언트
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );

    // Thumb
    final cx = (hue / 360 * size.width).clamp(10.0, size.width - 10.0);
    final cy = size.height / 2;
    canvas
      ..drawCircle(Offset(cx, cy), 12,
          Paint()..color = Colors.white)
      ..drawCircle(Offset(cx, cy), 12,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
