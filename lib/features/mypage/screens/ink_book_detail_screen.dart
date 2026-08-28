import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/ink_book_providers.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../providers/ink_shape_provider.dart';
import '../controllers/ink_book_display_controller.dart';
import 'ink_chart_add_screen.dart';
import '../widgets/ink_detail_carousel.dart';
import '../widgets/ink_swatch_shape.dart';
import '../widgets/ink_memo_content.dart';
import '../widgets/notebook_page.dart';
part '../widgets/ink_book_reorder_widgets.dart';
part '../widgets/ink_book_page_widgets.dart';
part '../widgets/ink_book_settings_widgets.dart';

typedef _SortOption = InkBookSortOption;
typedef _PageStyle = InkBookPageStyle;
typedef _ViewMode = InkBookViewMode;

// ── Screen ─────────────────────────────────────────────────────────────────

class InkBookDetailScreen extends ConsumerStatefulWidget {
  const InkBookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<InkBookDetailScreen> createState() =>
      _InkBookDetailScreenState();
}

class _InkBookDetailScreenState extends ConsumerState<InkBookDetailScreen> {
  late final InkBookDisplayController _displayController;
  _SortOption get _sort => _displayController.sort;
  set _sort(_SortOption value) => _displayController.sort = value;
  _PageStyle get _pageStyle => _displayController.pageStyle;
  set _pageStyle(_PageStyle value) => _displayController.pageStyle = value;
  _ViewMode get _viewMode => _displayController.viewMode;
  set _viewMode(_ViewMode value) => _displayController.viewMode = value;
  bool _isReordering = false;
  bool _extractingColors = false;
  bool _savingPages = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final Map<String, double> _hueCache = {};
  late final PageController _pageCtrl;
  int _currentPage = 0;
  final List<GlobalKey> _pageKeys = [];

  static const _itemsPerPage = 9;

  @override
  void initState() {
    super.initState();
    _displayController = InkBookDisplayController(widget.bookId);
    _pageCtrl = PageController();
    _loadPrefs();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Prefs ────────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _displayController.load(prefs));
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.bookId;
    await _displayController.save(prefs);
    // 다른 유저가 읽기 전용으로 볼 때도 동일하게 보이도록 book 문서에도 저장
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      ref
          .read(inkBookRepoProvider)
          .updateBookDisplaySettings(
            uid,
            id,
            pageStyle: _pageStyle.name,
            viewMode: _viewMode.name,
          )
          .then((_) => debugPrint('[InkBook] displaySettings 저장 완료: $id'))
          .catchError((e) => debugPrint('[InkBook] displaySettings 저장 실패: $e'));
    }
  }

  // ── 앨범 저장 ─────────────────────────────────────────────────────────────

  Future<void> _saveToAlbum(int pageCount) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        if (mounted) {
          showCenterToast(context, message: '사진 접근 권한이 필요합니다.');
        }
        return;
      }
    }

    setState(() => _savingPages = true);
    int saved = 0;

    // 첫 번째 패스: 모든 페이지를 방문해 이미지를 메모리 캐시에 올림
    for (int i = 0; i < pageCount; i++) {
      await _pageCtrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 두 번째 패스: 이미지가 캐시된 상태에서 캡처
    for (int i = 0; i < pageCount; i++) {
      await _pageCtrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 1),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(milliseconds: 300));

      if (i >= _pageKeys.length) continue;
      final ctx = _pageKeys[i].currentContext;
      if (ctx == null) continue;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) continue;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) continue;

      await Gal.putImageBytes(byteData.buffer.asUint8List());
      saved++;
    }

    if (mounted) {
      setState(() => _savingPages = false);
      _showSaveCompleteDialog(saved);
    }
  }

  void _showSaveCompleteDialog(int saved) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: const Color(0xFFFFFCF5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text('저장 완료', style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              Text(
                '$saved장이 앨범에 저장됐어요',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('photos-redirect://');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    '앨범에서 확인하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '닫기',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter / Sort ────────────────────────────────────────────────────────

  List<InkChartModel> _applySearch(List<InkChartModel> raw) {
    if (_searchQuery.isEmpty) return raw;
    final q = _searchQuery.toLowerCase();
    return raw
        .where(
          (e) =>
              e.brand.toLowerCase().contains(q) ||
              e.inkName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<InkChartModel> _applySort(List<InkChartModel> list) {
    final sorted = [...list];
    switch (_sort) {
      case _SortOption.defaultOrder:
        sorted.sort((a, b) => a.order.compareTo(b.order));
      case _SortOption.brand:
        sorted.sort((a, b) {
          final bc = a.brand.compareTo(b.brand);
          return bc != 0 ? bc : a.inkName.compareTo(b.inkName);
        });
      case _SortOption.color:
        double normalizedHue(double hue) => hue > 300 ? hue - 360 : hue;
        sorted.sort((a, b) {
          final ha = normalizedHue(_hueCache[a.photoUrl] ?? 0);
          final hb = normalizedHue(_hueCache[b.photoUrl] ?? 0);
          return ha.compareTo(hb);
        });
    }
    return sorted;
  }

  Future<void> _extractColors(List<InkChartModel> entries) async {
    setState(() => _extractingColors = true);
    await Future.wait(
      entries.map((e) async {
        if (_hueCache.containsKey(e.photoUrl)) return;
        try {
          final palette = await PaletteGenerator.fromImageProvider(
            CachedNetworkImageProvider(e.photoUrl),
            size: const Size(80, 80),
            timeout: const Duration(seconds: 6),
          );
          final c = palette.dominantColor?.color ?? Colors.grey;
          _hueCache[e.photoUrl] = HSVColor.fromColor(c).hue;
        } catch (_) {
          _hueCache[e.photoUrl] = 0.0;
        }
      }),
    );
    if (mounted) setState(() => _extractingColors = false);
  }

  Future<void> _saveReorder(String uid, List<InkChartModel> reordered) async {
    await ref
        .read(inkBookRepoProvider)
        .reorderEntries(uid, widget.bookId, reordered);
  }

  // ── Visibility ───────────────────────────────────────────────────────────

  IconData _visibilityIcon(String? visibility) => switch (visibility) {
    'public' => Icons.public,
    'followers' => Icons.group_outlined,
    _ => Icons.lock_outlined,
  };

  String _visibilityLabel(String? visibility) => switch (visibility) {
    'public' => '모든 사람에게 공개',
    'followers' => '팔로워에게만 공개',
    _ => '비공개',
  };

  void _showVisibilitySheet(
    BuildContext context,
    WidgetRef ref,
    String uid,
    InkBookModel book,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _VisibilitySheet(
        current: book.visibility,
        onSelect: (newVisibility) async {
          Navigator.pop(ctx);
          if (newVisibility == book.visibility) return;
          final currentUser = ref.read(currentUserProvider).value;
          await ref
              .read(inkBookRepoProvider)
              .updateBookVisibility(
                uid,
                widget.bookId,
                visibility: newVisibility,
                ownerNickname: currentUser?.nickname ?? '',
              );
          if (mounted) {
            final msg = switch (newVisibility) {
              'public' => '모든 사람에게 공개됐어요',
              'followers' => '팔로워에게만 공개됐어요',
              _ => '비공개로 변경됐어요',
            };
            showCenterToast(context, message: msg, icon: Icons.check_circle);
          }
        },
      ),
    );
  }

  // ── Menu ─────────────────────────────────────────────────────────────────

  Future<void> _showMenuSheet(
    BuildContext context,
    List<InkChartModel> entries,
    String uid,
  ) async {
    final shape = ref.read(inkSwatchShapeProvider);

    // 이 메뉴의 각 항목은 원래 Navigator.pop(context) 직후 같은 프레임에서
    // 바로 다음 showModalBottomSheet를 여는 방식이었는데, 이렇게 하면 닫히는
    // 시트의 퇴장 애니메이션과 새로 열리는 시트의 등장 애니메이션이 동시에
    // Overlay에 떠 있는 순간이 생겨서 Flutter의 BottomSheet 크기 감지 렌더
    // 오브젝트(_RenderBottomSheetLayoutWithSizeListener)가 "BoxConstraints
    // forces an infinite width"로 죽는 경우가 있다. 대신 이 시트를 결과값과
    // 함께 pop하고, showModalBottomSheet가 반환하는 Future(퇴장 애니메이션이
    // 완전히 끝난 뒤에만 resolve됨)를 기다렸다가 그 다음에 다음 시트를 연다.
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('정렬'),
                subtitle: Text(
                  _sort.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.pop(context, 'sort'),
              ),
              ListTile(
                leading: const Icon(Icons.grid_on_outlined),
                title: const Text('페이지 스타일'),
                subtitle: Text(
                  _pageStyle.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.pop(context, 'style'),
              ),
              ListTile(
                leading: const Icon(Icons.view_agenda_outlined),
                title: const Text('보기 방식'),
                subtitle: Text(
                  _viewMode.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.pop(context, 'view'),
              ),
              ListTile(
                leading: SizedBox(
                  width: 24,
                  height: 24,
                  child: shape == InkSwatchShape.bottle
                      ? Image.asset(
                          'assets/shapes/ink_jar.png',
                          color: AppColors.textSecondary,
                          colorBlendMode: BlendMode.srcIn,
                        )
                      : CustomPaint(
                          painter: ShapePreviewPainter(
                            shape,
                            AppColors.textSecondary,
                          ),
                        ),
                ),
                title: const Text('스와치 모양'),
                subtitle: Text(
                  shape.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.pop(context, 'shape'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('앨범에 저장'),
                onTap: () {
                  Navigator.pop(context);
                  final pageCount = (entries.length / NotebookPage.itemsPerPage)
                      .ceil();
                  _saveToAlbum(pageCount.clamp(1, pageCount));
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  '공책 삭제',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteBook(context, uid, entries);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted) return;
    switch (action) {
      case 'sort':
        _showSortSubSheet(context, entries);
      case 'style':
        _showStyleSubSheet(context);
      case 'view':
        _showViewSubSheet(context);
      case 'shape':
        _showShapeSubSheet(context);
    }
  }

  void _showSortSubSheet(BuildContext context, List<InkChartModel> entries) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text(
                '정렬',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ..._SortOption.values.map(
                (opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _sort == opt ? AppColors.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    opt.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _sort == opt
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    if (opt == _SortOption.color) {
                      await _extractColors(entries);
                    }
                    if (mounted) {
                      setState(() => _sort = opt);
                      _savePrefs();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStyleSubSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text(
                '페이지 스타일',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ..._PageStyle.values.map(
                (opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _pageStyle == opt ? AppColors.primary : null,
                    ),
                  ),
                  trailing: _pageStyle == opt
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _pageStyle = opt);
                    _savePrefs();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showViewSubSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text(
                '보기 방식',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ..._ViewMode.values.map(
                (opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _viewMode == opt ? AppColors.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    opt.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _viewMode == opt
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _viewMode = opt);
                    _savePrefs();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShapeSubSheet(BuildContext context) {
    final shape = ref.read(inkSwatchShapeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ShapePickerSheet(current: shape, ref: ref),
    );
  }

  // ── Ink Context Menu ─────────────────────────────────────────────────────

  void _showInkContextMenu(
    BuildContext context,
    InkChartModel entry,
    String uid,
  ) {
    final shape = ref.read(inkSwatchShapeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(topPadding: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  InkShapeClip(
                    shape: shape,
                    child: CachedNetworkImage(
                      imageUrl: entry.photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFD4C5A9)),
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFFD4C5A9)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.brand, style: AppTextStyles.labelSmall),
                      Text(
                        entry.inkName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drag_indicator),
              title: const Text('순서 변경'),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                setState(() {
                  _isReordering = true;
                  _sort = _SortOption.defaultOrder;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmDeleteEntry(context, entry, uid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('취소'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEntry(
    BuildContext context,
    InkChartModel entry,
    String uid,
  ) async {
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
    if (ok != true || !mounted) return;
    await ref
        .read(inkBookRepoProvider)
        .deleteEntry(uid, widget.bookId, entry.id);
    try {
      await ref.read(storageServiceProvider).deleteByUrl(entry.photoUrl);
    } catch (_) {}
  }

  Future<void> _deleteBook(
    BuildContext context,
    String uid,
    List<InkChartModel> entries,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공책 삭제'),
        content: const Text('공책과 모든 잉크 기록이 삭제됩니다.\n되돌릴 수 없습니다.'),
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
    if (ok != true || !mounted) return;
    final deleted = await ref
        .read(inkBookRepoProvider)
        .deleteBook(uid, widget.bookId);
    for (final e in deleted) {
      try {
        await ref.read(storageServiceProvider).deleteByUrl(e.photoUrl);
      } catch (_) {}
    }
    if (mounted) context.pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final booksAsync = ref.watch(inkBookListProvider(uid));
    final book = booksAsync.maybeWhen(
      data: (list) => list.cast<InkBookModel?>().firstWhere(
        (b) => b!.id == widget.bookId,
        orElse: () => null,
      ),
      orElse: () => null,
    );

    final chartAsync = ref.watch(inkChartInBookProvider((uid, widget.bookId)));

    // 새 잉크 추가 감지 → 마지막 페이지로 이동
    ref.listen<AsyncValue<List<InkChartModel>>>(
      inkChartInBookProvider((uid, widget.bookId)),
      (prev, next) {
        final prevCount = prev?.valueOrNull?.length ?? -1;
        next.whenData((entries) {
          if (prevCount >= 0 && entries.length > prevCount) {
            final lastPage = (entries.length - 1) ~/ _itemsPerPage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageCtrl.hasClients && lastPage != _currentPage) {
                _pageCtrl.animateToPage(
                  lastPage,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        });
      },
    );

    final shape = ref.watch(inkSwatchShapeProvider);
    final inkCount = chartAsync.maybeWhen(
      data: (l) => l.length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: book?.name ?? '잉크 차트',
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              if (inkCount > 0)
                TextSpan(
                  text: ' · $inkCount개',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (_isReordering)
            TextButton(
              onPressed: () => setState(() => _isReordering = false),
              child: const Text(
                '완료',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(
                _visibilityIcon(book?.visibility),
                size: 22,
                color: (book?.visibility ?? 'private') != 'private'
                    ? AppColors.primary
                    : null,
              ),
              tooltip: _visibilityLabel(book?.visibility),
              onPressed: () {
                if (book == null) return;
                _showVisibilitySheet(context, ref, uid, book);
              },
            ),
            IconButton(
              icon: Icon(
                _showSearch ? Icons.search_off : Icons.search,
                size: 22,
              ),
              tooltip: '검색',
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                }
              }),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: '메뉴',
              onPressed: () => chartAsync.whenData(
                (entries) => _showMenuSheet(context, entries, uid),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _isReordering
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/ink-chart/${widget.bookId}/add'),
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '브랜드 또는 잉크 이름 검색',
                  hintStyle: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _searchCtrl.clear();
                          }),
                        )
                      : null,
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
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          Expanded(
            child: chartAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (raw) {
                if (raw.isEmpty) {
                  return _EmptyState(bookId: widget.bookId);
                }
                final filtered = _applySearch(raw);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"$_searchQuery" 검색 결과 없음',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final entries = _applySort(filtered);
                final pageCount = (entries.length / _itemsPerPage).ceil();

                if (_isReordering) {
                  return _ReorderView(
                    entries: entries,
                    uid: uid,
                    bookId: widget.bookId,
                    shape: shape,
                    onReorder: (reordered) async {
                      setState(() {});
                      await _saveReorder(uid, reordered);
                    },
                  );
                }

                // ── PageView mode (좌우 or 위아래) ──────────────
                return Builder(
                  builder: (ctx) {
                    final mq = MediaQuery.of(ctx);
                    const pageIndicatorH = 40.0;
                    const fabH = 80.0;
                    final pageViewHeight =
                        mq.size.height -
                        mq.padding.top -
                        mq.padding.bottom -
                        kToolbarHeight -
                        pageIndicatorH -
                        fabH -
                        16.0;

                    return Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: const Alignment(0, -0.4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: pageViewHeight - 60,
                                      child: PageView.builder(
                                        scrollDirection:
                                            _viewMode == _ViewMode.scroll
                                            ? Axis.vertical
                                            : Axis.horizontal,
                                        controller: _pageCtrl,
                                        itemCount: pageCount,
                                        onPageChanged: (p) =>
                                            setState(() => _currentPage = p),
                                        itemBuilder: (_, pageIdx) {
                                          final start = pageIdx * _itemsPerPage;
                                          final end = math.min(
                                            start + _itemsPerPage,
                                            entries.length,
                                          );
                                          final pageEntries = entries.sublist(
                                            start,
                                            end,
                                          );
                                          // GlobalKey 동적 확장
                                          while (_pageKeys.length <= pageIdx) {
                                            _pageKeys.add(GlobalKey());
                                          }
                                          return RepaintBoundary(
                                            key: _pageKeys[pageIdx],
                                            child: NotebookPage(
                                              pageEntries: pageEntries,
                                              pageStyle:
                                                  notebookPageStyleFromString(
                                                    _pageStyle.name,
                                                  ),
                                              // 앨범 저장 중(_savingPages)엔
                                              // 빈 칸의 점선 원을 숨겨서, 캡처된
                                              // 이미지엔 실제로 채운 잉크만
                                              // 보이고 나머지는 빈 페이지처럼
                                              // 나오게 한다. 저장 중엔 화면
                                              // 전체가 딤 처리 오버레이로 덮여
                                              // 있어서 이 변화가 사용자 눈에
                                              // 보이지 않는다.
                                              showEmptySlotPlaceholder:
                                                  !_savingPages,
                                              itemBuilder: (ctx, entry, i) =>
                                                  _SwatchCard(
                                                    entry: entry,
                                                    uid: uid,
                                                    bookId: widget.bookId,
                                                    shape: shape,
                                                    allEntries: entries,
                                                    absoluteIndex: start + i,
                                                    onLongPress: () =>
                                                        _showInkContextMenu(
                                                          context,
                                                          entry,
                                                          uid,
                                                        ),
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (pageCount > 1)
                                      Text(
                                        '${_currentPage + 1} / $pageCount',
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: AppColors.textTertiary,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_extractingColors)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 12),
                                        Text('색상 분석 중...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_savingPages)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 12),
                                        Text('앨범에 저장 중...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────
