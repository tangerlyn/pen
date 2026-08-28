part of '../screens/ink_book_detail_screen.dart';

class _DetailSheet extends ConsumerWidget {
  const _DetailSheet({
    required this.charts,
    required this.initialIndex,
    required this.uid,
    required this.bookId,
    required this.shape,
  });
  final List<InkChartModel> charts;
  final int initialIndex;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // charts는 바텀시트를 열 때의 스냅샷이라 순서/필터는 그대로 유지하되,
    // 각 항목 내용은 실시간 provider 데이터로 덮어써서 수정 사항이 바로 반영되게 함
    final liveEntries = ref
        .watch(inkChartInBookProvider((uid, bookId)))
        .valueOrNull;
    final liveById = {
      for (final e in liveEntries ?? const <InkChartModel>[]) e.id: e,
    };
    final liveCharts = charts.map((e) => liveById[e.id] ?? e).toList();

    return InkDetailCarousel(
      itemCount: liveCharts.length,
      initialIndex: initialIndex,
      pageBuilder: (ctx, i) => _DetailPage(
        entry: liveCharts[i],
        uid: uid,
        bookId: bookId,
        shape: shape,
        onDeleted: () => Navigator.pop(context),
      ),
      menuBuilder: (ctx, i) => _DetailMenuButton(
        entry: liveCharts[i],
        uid: uid,
        bookId: bookId,
        onDeleted: () => Navigator.pop(context),
      ),
    );
  }
}

// ── 잉크 상세 ⋮ 메뉴 (수정/삭제) ─────────────────────────────────────────
class _DetailMenuButton extends ConsumerWidget {
  const _DetailMenuButton({
    required this.entry,
    required this.uid,
    required this.bookId,
    required this.onDeleted,
  });
  final InkChartModel entry;
  final String uid;
  final String bookId;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      onPressed: () => _showMenu(context, ref),
    );
  }

  // 앱 전체에서 쓰는 "⋮ 더보기" 바텀시트와 동일한 형태로 통일
  // (PopupMenuButton은 이 앱 다른 곳에서 안 쓰는, 어울리지 않는 형태였음)
  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('잉크 수정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InkChartAddScreen(bookId: bookId, entryToEdit: entry),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                '잉크 삭제',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('잉크 삭제'),
        content: Text('"${entry.brand} ${entry.inkName}"을 삭제할까요?'),
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
    if (ok != true || !context.mounted) return;
    await ref.read(inkBookRepoProvider).deleteEntry(uid, bookId, entry.id);
    try {
      await ref.read(storageServiceProvider).deleteByUrl(entry.photoUrl);
    } catch (_) {}
    onDeleted();
  }
}

// ── 상세 페이지 ───────────────────────────────────────────────────────────


class _RenameBottomSheet extends StatefulWidget {
  const _RenameBottomSheet({required this.initialName, required this.onSave});
  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_RenameBottomSheet> createState() => _RenameBottomSheetState();
}

class _RenameBottomSheetState extends State<_RenameBottomSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // autofocus TextField 때문에 시트가 올라오는 애니메이션과 키보드가 뜨는
    // 애니메이션이 동시에 진행되면서, showModalBottomSheet 내부의 크기
    // 감지용 렌더 오브젝트(_RenderBottomSheetLayoutWithSizeListener)가
    // 특정 프레임에 폭 제약을 무한대로 내려보내 ElevatedButton이
    // "BoxConstraints forces an infinite width"로 크래시하는 경우가 있다.
    // LayoutBuilder로 실제 가용 폭을 재서, 폭 제약이 무한(비정상)이면
    // 화면 폭으로 대체해 항상 유한한 폭을 자식에게 내려주도록 방어한다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        return SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _sheetHandle()),
              const SizedBox(height: 16),
              const Text(
                '공책 이름 변경',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: '공책 이름',
                  hintStyle: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
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
              Row(
                children: [
                  // 전역 ElevatedButtonTheme의 minimumSize가
                  // Size.fromHeight(52) = Size(double.infinity, 52)라서,
                  // Expanded 없이 Row의 평범한 자식으로 두면 폭이 무한대를
                  // 요구하게 된다. 평소엔 Row가 느슨하게(loose) 폭을 내려줘서
                  // 문제 없어 보이지만, 이 화면처럼 바텀시트 크기 감지
                  // 렌더러(_RenderBottomSheetLayoutWithSizeListener) 아래에서
                  // 조상이 진짜 무제한 폭을 내려주는 경우와 만나면
                  // "BoxConstraints forces an infinite width"로 크래시한다.
                  // Expanded로 감싸면 Row가 항상 유한한 폭을 배분해줘서
                  // 이 조합 자체가 발생하지 않는다 (ink_book_list_screen.dart의
                  // 옵션 시트도 동일한 이유로 Expanded를 쓰고 있음).
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final name = _ctrl.text.trim();
                        if (name.isEmpty) return;
                        widget.onSave(name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
          ),
        );
      },
    );
  }
}

// ── 모양 선택 바텀시트 ─────────────────────────────────────────────────────

class _ShapePickerSheet extends StatelessWidget {
  const _ShapePickerSheet({required this.current, required this.ref});
  final InkSwatchShape current;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _sheetHandle()),
            const SizedBox(height: 16),
            const Text(
              '스와치 모양',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: InkSwatchShape.values.map((shape) {
                final selected = shape == current;
                return TapScale(
                  onTap: () {
                    ref.read(inkSwatchShapeProvider.notifier).setShape(shape);
                    // 다른 유저가 읽기 전용으로 볼 때도 동일한 모양이 보이도록
                    // 계정(users/{uid}) 문서에도 저장 — 스와치 모양은 책별이 아니라
                    // 계정 전체에 적용되는 설정이라 여기 저장한다.
                    final uid = ref.read(currentUidProvider);
                    if (uid != null) {
                      ref
                          .read(userRepoProvider)
                          .updateUser(uid, {'inkSwatchShape': shape.name})
                          .then(
                            (_) => debugPrint(
                              '[InkBook] inkSwatchShape 저장 완료: ${shape.name}',
                            ),
                          )
                          .catchError(
                            (e) => debugPrint(
                              '[InkBook] inkSwatchShape 저장 실패: $e',
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : const Color(0xFFEDE8DF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFD4C5A9),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: shape == InkSwatchShape.bottle
                            ? Image.asset(
                                'assets/shapes/ink_jar.png',
                                fit: BoxFit.contain,
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xFF8B7355),
                                colorBlendMode: BlendMode.srcIn,
                              )
                            : CustomPaint(
                                painter: ShapePreviewPainter(
                                  shape,
                                  selected
                                      ? AppColors.primary
                                      : const Color(0xFF8B7355),
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shape.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공개 범위 선택 바텀 시트 ──────────────────────────────────────────────────

class _VisibilitySheet extends StatelessWidget {
  const _VisibilitySheet({required this.current, required this.onSelect});
  final String current;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                '공개 범위 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            _VisibilityOption(
              icon: Icons.public,
              label: '모든 사람에게 공개',
              description: '누구든지 이 잉크 차트를 볼 수 있어요',
              isSelected: current == 'public',
              onTap: () => onSelect('public'),
            ),
            _VisibilityOption(
              icon: Icons.group_outlined,
              label: '팔로워에게만 공개',
              description: '나를 팔로우한 사람만 볼 수 있어요',
              isSelected: current == 'followers',
              onTap: () => onSelect('followers'),
            ),
            _VisibilityOption(
              icon: Icons.lock_outlined,
              label: '비공개',
              description: '나만 볼 수 있어요',
              isSelected: current == 'private',
              onTap: () => onSelect('private'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
