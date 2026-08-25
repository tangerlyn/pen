import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../widgets/notebook_card.dart';

class InkBookListScreen extends ConsumerWidget {
  const InkBookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final booksAsync = ref.watch(inkBookListProvider(uid));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Text('내 잉크 차트'),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (books) => books.isEmpty
            ? _EmptyState(uid: uid)
            : _BookGrid(books: books, uid: uid),
      ),
    );
  }
}

// ── 그리드 ─────────────────────────────────────────────────────────────
class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.uid});
  final List<InkBookModel> books;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: books.length + 1,
      itemBuilder: (_, i) {
        if (i == books.length) {
          return _NewBookCell(uid: uid);
        }
        return _NotebookCard(book: books[i], uid: uid);
      },
    );
  }
}

// ── 공책 카드 ──────────────────────────────────────────────────────────
class _NotebookCard extends ConsumerWidget {
  const _NotebookCard({required this.book, required this.uid});
  final InkBookModel book;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotebookCard(
      book: book,
      uid: uid,
      onTap: () => context.push('/ink-chart/${book.id}'),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showBookOptions(context, ref);
      },
    );
  }

  void _showBookOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _BookOptionsSheet(book: book, uid: uid),
    );
  }
}

// ── + 새 공책 셀 ──────────────────────────────────────────────────────
class _NewBookCell extends StatelessWidget {
  const _NewBookCell({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => _showCreateSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0EBE0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFD4C5A9),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 32, color: Color(0xFFB8A98A)),
            const SizedBox(height: 8),
            Text(
              '새 공책 만들기',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B7355),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CreateBookSheet(uid: uid),
    );
  }
}

// ── 공책 생성 바텀시트 ─────────────────────────────────────────────────
class _CreateBookSheet extends ConsumerStatefulWidget {
  const _CreateBookSheet({required this.uid});
  final String uid;

  @override
  ConsumerState<_CreateBookSheet> createState() => _CreateBookSheetState();
}

class _CreateBookSheetState extends ConsumerState<_CreateBookSheet> {
  final _nameCtrl = TextEditingController();
  String _selectedColor = kPastelColors.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showCenterToast(context, message: '공책 이름을 입력해주세요');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(inkBookRepoProvider)
          .createBook(widget.uid, name, _selectedColor);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        showCenterToast(
          context,
          message: '저장 실패: $e',
          icon: Icons.error_outline,
          iconColor: AppColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4C5A9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '새 공책 만들기',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '공책 이름',
              filled: true,
              fillColor: const Color(0xFFFFFDF7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: const BorderSide(color: Color(0xFFD4C5A9)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: const BorderSide(color: Color(0xFFD4C5A9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '표지 색상',
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kPastelColors.map((hex) {
              final selected = hex == _selectedColor;
              final hex6 = hex.replaceFirst('#', '');
              final color = Color(int.parse('FF$hex6', radix: 16));
              return TapScale(
                onTap: () => setState(() => _selectedColor = hex),
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
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '만들기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공책 옵션 바텀시트 (이름 변경 / 삭제) ──────────────────────────────
class _BookOptionsSheet extends ConsumerStatefulWidget {
  const _BookOptionsSheet({required this.book, required this.uid});
  final InkBookModel book;
  final String uid;

  @override
  ConsumerState<_BookOptionsSheet> createState() => _BookOptionsSheetState();
}

class _BookOptionsSheetState extends ConsumerState<_BookOptionsSheet> {
  bool _isEditing = false;
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.book.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(inkBookRepoProvider)
        .updateBook(widget.uid, widget.book.id, name: name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공책 삭제'),
        content: Text(
          '"${widget.book.name}" 공책을 삭제할까요?\n안에 있는 잉크 기록도 모두 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final entries = await ref
        .read(inkBookRepoProvider)
        .deleteBook(widget.uid, widget.book.id);
    // Delete storage photos
    for (final e in entries) {
      try {
        await ref.read(storageServiceProvider).deleteByUrl(e.photoUrl);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4C5A9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // _isEditing 전환 시 이 위치의 위젯 타입이 통째로 바뀌는데(ListTile ↔
          // TextField/Row), 서로 다른 branch에 고유 Key를 주지 않으면 Flutter가
          // 이전 위젯의 semantics 노드를 재사용하려다 parentData가 어긋나서
          // "!semantics.parentDataDirty" 크래시가 난다 (archive_screen.dart의
          // CustomScrollView 고정 패턴과 동일한 종류의 이슈). Column에 각각
          // 다른 Key를 줘서 완전히 새 서브트리로 교체되게 한다.
          if (_isEditing) ...[
            Column(
              key: const ValueKey('book_options_editing'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '공책 이름',
                filled: true,
                fillColor: const Color(0xFFFFFDF7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: const BorderSide(color: Color(0xFFD4C5A9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('저장'),
                  ),
                ),
              ],
            ),
              ],
            ),
          ] else ...[
            Column(
              key: const ValueKey('book_options_default'),
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('이름 변경'),
                  onTap: () => setState(() => _isEditing = true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    '삭제',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7D6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_album_outlined,
              size: 44,
              color: Color(0xFFB8A98A),
            ),
          ),
          const SizedBox(height: 20),
          const Text('공책이 없어요', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            '잉크 스와치를 담을 공책을 만들어보세요',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              builder: (_) => _CreateBookSheet(uid: uid),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('첫 번째 공책 만들기'),
          ),
        ],
      ),
    );
  }
}
