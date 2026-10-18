import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/ink_color_families.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../analytics/swatch_record_tracker.dart';
import '../controllers/swatch_record_controller.dart';
import '../providers/ink_catalog_provider.dart';

/// 잉크 매칭 시트의 결과. request면 화면이 등록 요청을 남긴 뒤 기록에 연결한다.
class InkMatchSelection {
  const InkMatchSelection({
    required this.ink,
    required this.matchType,
    required this.queryLength,
    required this.filterCount,
  });

  final SwatchInk ink;
  final SwatchMatchType matchType;
  final int queryLength;
  final int filterCount;
}

Future<InkMatchSelection?> showInkMatchSheet(BuildContext context) {
  return showModalBottomSheet<InkMatchSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.92,
      child: InkMatchSheet(),
    ),
  );
}

class InkMatchSheet extends ConsumerStatefulWidget {
  const InkMatchSheet({super.key});

  @override
  ConsumerState<InkMatchSheet> createState() => _InkMatchSheetState();
}

class _InkMatchSheetState extends ConsumerState<InkMatchSheet> {
  final _searchCtrl = TextEditingController();
  var _query = const InkMatchQuery();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(InkMatchQuery next) => setState(() => _query = next);

  void _toggleColor(String family) {
    final next = {..._query.colorFamilies};
    next.contains(family) ? next.remove(family) : next.add(family);
    _update(InkMatchQuery(text: _query.text, colorFamilies: next, brands: _query.brands));
  }

  void _toggleBrand(String brand) {
    final next = {..._query.brands};
    next.contains(brand) ? next.remove(brand) : next.add(brand);
    _update(InkMatchQuery(text: _query.text, colorFamilies: _query.colorFamilies, brands: next));
  }

  void _pick(InkModel ink) {
    Navigator.pop(
      context,
      InkMatchSelection(
        ink: SwatchInk.fromArchive(ink),
        matchType: SwatchMatchType.archive,
        queryLength: _query.text.trim().length,
        filterCount: _query.filterCount,
      ),
    );
  }

  /// 아카이브에 없는 잉크: 이름(필수)·브랜드(선택)를 받고, 등록 요청 여부를 고른다.
  Future<void> _enterManually() async {
    final result = await showDialog<(String, String, bool)>(
      context: context,
      builder: (_) => _ManualInkDialog(initialName: _query.text.trim()),
    );
    if (result == null || !mounted) return;
    final (brand, name, request) = result;
    Navigator.pop(
      context,
      InkMatchSelection(
        ink: SwatchInk(brand: brand, name: name),
        matchType: request ? SwatchMatchType.request : SwatchMatchType.freeText,
        queryLength: _query.text.trim().length,
        filterCount: _query.filterCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(inkCatalogProvider);
    final catalog = catalogAsync.valueOrNull ?? const <InkModel>[];
    final results = filterInks(catalog, _query);
    final brands = brandsByInkCount(catalog);
    // 선택한 브랜드는 순위와 상관없이 항상 칩에 보이게
    final brandChips = [
      ..._query.brands,
      ...brands.where((b) => !_query.brands.contains(b)).take(20),
    ];

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => _update(InkMatchQuery(
              text: v,
              colorFamilies: _query.colorFamilies,
              brands: _query.brands,
            )),
            decoration: InputDecoration(
              hintText: '잉크 이름이나 브랜드로 찾기',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.chipBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _ChipRow(
          children: [
            for (final e in kInkColorFamilySwatches.entries)
              FilterChip(
                selected: _query.colorFamilies.contains(e.key),
                onSelected: (_) => _toggleColor(e.key),
                avatar: CircleAvatar(backgroundColor: e.value, radius: 6),
                label: Text(e.key),
              ),
          ],
        ),
        if (brandChips.isNotEmpty)
          _ChipRow(
            children: [
              for (final b in brandChips)
                FilterChip(
                  selected: _query.brands.contains(b),
                  onSelected: (_) => _toggleBrand(b),
                  label: Text(b),
                ),
            ],
          ),
        const Divider(height: 1),
        Expanded(
          child: catalogAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (catalogAsync.hasError)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          '잉크 목록을 불러오지 못했어요. 이름을 직접 입력해 기록할 수 있어요.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    if (!catalogAsync.hasError && results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          _query.isEmpty ? '잉크를 검색해보세요' : '아카이브에서 찾지 못했어요',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    for (final ink in results)
                      ListTile(
                        contentPadding: AppSpacing.listItemPadding,
                        leading: InkDropCircle(color: ink.inkColor, size: 32),
                        title: Text(ink.name, style: AppTextStyles.titleSmall),
                        subtitle: Text(ink.brand, style: AppTextStyles.labelMedium),
                        onTap: () => _pick(ink),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: AppSpacing.listItemPadding,
                      leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      title: const Text('찾는 잉크가 없어요', style: AppTextStyles.titleSmall),
                      subtitle: const Text(
                        '이름을 직접 입력하고, 아카이브 추가를 요청할 수 있어요',
                        style: AppTextStyles.labelMedium,
                      ),
                      onTap: _enterManually,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// 직접 입력 다이얼로그 → (브랜드, 이름, 등록 요청 여부)
class _ManualInkDialog extends StatefulWidget {
  const _ManualInkDialog({required this.initialName});
  final String initialName;

  @override
  State<_ManualInkDialog> createState() => _ManualInkDialogState();
}

class _ManualInkDialogState extends State<_ManualInkDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  final _brandCtrl = TextEditingController();
  bool _request = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameCtrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('잉크 직접 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '잉크 이름 (필수)'),
          ),
          TextField(
            controller: _brandCtrl,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '브랜드 (선택)'),
          ),
          CheckboxListTile(
            value: _request,
            onChanged: (v) => setState(() => _request = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('아카이브에 이 잉크 추가 요청하기', style: AppTextStyles.bodySmall),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: canSubmit
              ? () => Navigator.pop(
                    context,
                    (_brandCtrl.text.trim(), _nameCtrl.text.trim(), _request),
                  )
              : null,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
