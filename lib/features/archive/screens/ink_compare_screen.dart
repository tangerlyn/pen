import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/center_toast.dart';

class InkCompareScreen extends ConsumerStatefulWidget {
  const InkCompareScreen({super.key, required this.baseInk});
  final InkModel baseInk;

  @override
  ConsumerState<InkCompareScreen> createState() => _InkCompareScreenState();
}

class _InkCompareScreenState extends ConsumerState<InkCompareScreen> {
  final _searchCtrl = TextEditingController();
  List<InkModel> _searchResults = [];
  bool _isSearching = false;
  final List<InkModel> _selected = [];

  @override
  void initState() {
    super.initState();
    _selected.add(widget.baseInk);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(archiveRepoProvider).searchInks(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results
              .where((ink) => !_selected.any((s) => s.id == ink.id))
              .take(20)
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addInk(InkModel ink) {
    if (_selected.length >= 3) {
      showCenterToast(context, message: '최대 3개까지 비교할 수 있어요');
      return;
    }
    setState(() {
      _selected.add(ink);
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _removeInk(int index) {
    if (index == 0) return; // 기준 잉크는 제거 불가
    setState(() => _selected.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('잉크 색상 비교'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // 비교 패널
          _ComparePanel(selected: _selected, onRemove: _removeInk),
          const Divider(height: 1),
          // 검색
          if (_selected.length < 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '잉크 이름 또는 브랜드 검색',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.chipBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _search,
              ),
            ),
          // 검색 결과
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchCtrl.text.isNotEmpty
                    ? const Center(
                        child: Text('검색 결과가 없습니다',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (_, i) {
                          final ink = _searchResults[i];
                          return ListTile(
                            leading: InkDropCircle(color: ink.inkColor, size: 36),
                            title: Text(ink.name,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(ink.brand,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.add_circle_outline,
                                color: AppColors.primary),
                            onTap: () => _addInk(ink),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ComparePanel extends StatelessWidget {
  const _ComparePanel({required this.selected, required this.onRemove});
  final List<InkModel> selected;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...selected.asMap().entries.map((e) => _InkCompareCard(
                ink: e.value,
                isBase: e.key == 0,
                onRemove: () => onRemove(e.key),
              )),
          if (selected.length < 3)
            _EmptyCompareSlot(slotNumber: selected.length + 1),
        ],
      ),
    );
  }
}

class _InkCompareCard extends StatelessWidget {
  const _InkCompareCard({
    required this.ink,
    required this.isBase,
    required this.onRemove,
  });
  final InkModel ink;
  final bool isBase;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ink.inkColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ink.inkColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 88,
              child: Text(
                ink.displayName,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ink.hexColor.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontFamily: 'monospace'),
            ),
            if (ink.inkType != 'normal')
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ink.inkTypeLabel,
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
        if (!isBase)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCompareSlot extends StatelessWidget {
  const _EmptyCompareSlot({required this.slotNumber});
  final int slotNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.divider,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: const Center(
            child: Icon(Icons.add, color: AppColors.textTertiary, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '잉크 $slotNumber',
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
