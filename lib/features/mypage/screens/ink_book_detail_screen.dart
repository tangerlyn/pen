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
import '../widgets/ink_swatch_shape.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum _SortOption { defaultOrder, brand, color }
enum _PageStyle { lines, grid, plain }
enum _ViewMode { pageView, scroll }

extension _SortOptionX on _SortOption {
  String get label => switch (this) {
        _SortOption.defaultOrder => '기본순',
        _SortOption.brand => '브랜드순',
        _SortOption.color => '색상순',
      };
  String get description => switch (this) {
        _SortOption.defaultOrder => '추가한 순서대로',
        _SortOption.brand => '브랜드명 가나다순',
        _SortOption.color => '사진의 주요 색상 기준',
      };
}

extension _PageStyleX on _PageStyle {
  String get label => switch (this) {
        _PageStyle.lines => '실선',
        _PageStyle.grid => '격자',
        _PageStyle.plain => '민무늬',
      };
}

extension _ViewModeX on _ViewMode {
  String get label => switch (this) {
        _ViewMode.pageView => '좌우 스와이프',
        _ViewMode.scroll => '위아래 스와이프',
      };
  String get description => switch (this) {
        _ViewMode.pageView => '좌우 스와이프, 3×3 페이지',
        _ViewMode.scroll => '위아래 스와이프, 3×3 페이지',
      };
}

// ── Screen ─────────────────────────────────────────────────────────────────

class InkBookDetailScreen extends ConsumerStatefulWidget {
  const InkBookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<InkBookDetailScreen> createState() =>
      _InkBookDetailScreenState();
}

class _InkBookDetailScreenState extends ConsumerState<InkBookDetailScreen> {
  _SortOption _sort = _SortOption.defaultOrder;
  _PageStyle _pageStyle = _PageStyle.lines;
  _ViewMode _viewMode = _ViewMode.pageView;
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
    final id = widget.bookId;
    if (!mounted) return;
    setState(() {
      final s = prefs.getString('inkBook_sort_$id');
      if (s != null) {
        _sort = _SortOption.values.firstWhere(
          (v) => v.name == s,
          orElse: () => _SortOption.defaultOrder,
        );
      }
      final p = prefs.getString('inkBook_style_$id');
      if (p != null) {
        _pageStyle = _PageStyle.values.firstWhere(
          (v) => v.name == p,
          orElse: () => _PageStyle.lines,
        );
      }
      final vm = prefs.getString('inkBook_view_$id');
      if (vm != null) {
        _viewMode = _ViewMode.values.firstWhere(
          (v) => v.name == vm,
          orElse: () => _ViewMode.pageView,
        );
      }
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.bookId;
    await Future.wait([
      prefs.setString('inkBook_sort_$id', _sort.name),
      prefs.setString('inkBook_style_$id', _pageStyle.name),
      prefs.setString('inkBook_view_$id', _viewMode.name),
    ]);
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
      await _pageCtrl.animateToPage(i,
          duration: const Duration(milliseconds: 1), curve: Curves.linear);
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 두 번째 패스: 이미지가 캐시된 상태에서 캡처
    for (int i = 0; i < pageCount; i++) {
      await _pageCtrl.animateToPage(i,
          duration: const Duration(milliseconds: 1), curve: Curves.linear);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.check_rounded,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                '저장 완료',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                '$saved장이 앨범에 저장됐어요',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('앨범에서 확인하기',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
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
        .where((e) =>
            e.brand.toLowerCase().contains(q) ||
            e.inkName.toLowerCase().contains(q))
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
    await Future.wait(entries.map((e) async {
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
    }));
    if (mounted) setState(() => _extractingColors = false);
  }

  Future<void> _saveReorder(String uid, List<InkChartModel> reordered) async {
    await ref.read(inkBookRepoProvider).reorderEntries(
      uid, widget.bookId, reordered,
    );
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
      BuildContext context, WidgetRef ref, String uid, InkBookModel book) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _VisibilitySheet(
        current: book.visibility,
        onSelect: (newVisibility) async {
          Navigator.pop(ctx);
          if (newVisibility == book.visibility) return;
          final currentUser = ref.read(currentUserProvider).value;
          await ref.read(inkBookRepoProvider).updateBookVisibility(
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

  void _showMenuSheet(
    BuildContext context,
    List<InkChartModel> entries,
    String uid,
    String bookName,
  ) {
    final shape = ref.read(inkSwatchShapeProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              subtitle: Text(_sort.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
              onTap: () {
                Navigator.pop(context);
                _showSortSubSheet(context, entries);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('페이지 스타일'),
              subtitle: Text(_pageStyle.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
              onTap: () {
                Navigator.pop(context);
                _showStyleSubSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_agenda_outlined),
              title: const Text('보기 방식'),
              subtitle: Text(_viewMode.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
              onTap: () {
                Navigator.pop(context);
                _showViewSubSheet(context);
              },
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
                        painter: ShapePreviewPainter(shape, AppColors.textSecondary),
                      ),
              ),
              title: const Text('스와치 모양'),
              subtitle: Text(shape.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
              onTap: () {
                Navigator.pop(context);
                _showShapeSubSheet(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('앨범에 저장'),
              onTap: () {
                Navigator.pop(context);
                final pageCount =
                    (entries.length / _NotebookPage._itemsPerPage).ceil();
                _saveToAlbum(pageCount.clamp(1, pageCount));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('공책 이름 변경'),
              onTap: () {
                Navigator.pop(context);
                _renameBook(context, uid, bookName);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('공책 삭제',
                  style: TextStyle(color: AppColors.error)),
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
  }

  void _showSortSubSheet(BuildContext context, List<InkChartModel> entries) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text('정렬',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ..._SortOption.values.map((opt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _sort == opt ? AppColors.primary : null)),
                    subtitle: Text(opt.description,
                        style: const TextStyle(fontSize: 12)),
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
                  )),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text('페이지 스타일',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ..._PageStyle.values.map((opt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                _pageStyle == opt ? AppColors.primary : null)),
                    trailing: _pageStyle == opt
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _pageStyle = opt);
                      _savePrefs();
                    },
                  )),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 12),
              const Text('보기 방식',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ..._ViewMode.values.map((opt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opt.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                _viewMode == opt ? AppColors.primary : null)),
                    subtitle: Text(opt.description,
                        style: const TextStyle(fontSize: 12)),
                    trailing: _viewMode == opt
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _viewMode = opt);
                      _savePrefs();
                    },
                  )),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(topPadding: 10),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      Text(entry.brand,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary)),
                      Text(entry.inkName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
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
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제',
                  style: TextStyle(color: AppColors.error)),
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
    await ref.read(inkBookRepoProvider).deleteEntry(uid, widget.bookId, entry.id);
    try {
      await ref.read(storageServiceProvider).deleteByUrl(entry.photoUrl);
    } catch (_) {}
  }

  void _renameBook(BuildContext context, String uid, String currentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RenameBottomSheet(
        initialName: currentName,
        onSave: (newName) async {
          Navigator.pop(context);
          if (!mounted) return;
          await ref
              .read(inkBookRepoProvider)
              .updateBook(uid, widget.bookId, name: newName);
        },
      ),
    );
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
    final deleted =
        await ref.read(inkBookRepoProvider).deleteBook(uid, widget.bookId);
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
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final booksAsync = ref.watch(inkBookListProvider(uid));
    final book = booksAsync.maybeWhen(
      data: (list) => list
          .cast<InkBookModel?>()
          .firstWhere((b) => b!.id == widget.bookId, orElse: () => null),
      orElse: () => null,
    );

    final chartAsync =
        ref.watch(inkChartInBookProvider((uid, widget.bookId)));

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
    final inkCount =
        chartAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);

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
                  style: const TextStyle(
                    fontSize: 14,
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
              child: const Text('완료',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
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
              icon:
                  Icon(_showSearch ? Icons.search_off : Icons.search, size: 22),
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
                (entries) => _showMenuSheet(
                    context, entries, uid, book?.name ?? ''),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _isReordering
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push('/ink-chart/${widget.bookId}/add'),
              backgroundColor: AppColors.primary,
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
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                  prefixIcon:
                      const Icon(Icons.search, size: 20),
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4C5A9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4C5A9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          Expanded(
            child: chartAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                        const Icon(Icons.search_off,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text('"$_searchQuery" 검색 결과 없음',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                final entries = _applySort(filtered);
                final pageCount =
                    (entries.length / _itemsPerPage).ceil();

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
                return Builder(builder: (ctx) {
                  final mq = MediaQuery.of(ctx);
                  const pageIndicatorH = 40.0;
                  const fabH = 80.0;
                  final pageViewHeight = mq.size.height
                      - mq.padding.top
                      - mq.padding.bottom
                      - kToolbarHeight
                      - pageIndicatorH
                      - fabH
                      - 16.0;

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
                                      onPageChanged: (p) => setState(
                                          () => _currentPage = p),
                                      itemBuilder: (_, pageIdx) {
                                        final start =
                                            pageIdx * _itemsPerPage;
                                        final end = math.min(
                                            start + _itemsPerPage,
                                            entries.length);
                                        final pageEntries =
                                            entries.sublist(start, end);
                                        // GlobalKey 동적 확장
                                        while (_pageKeys.length <= pageIdx) {
                                          _pageKeys.add(GlobalKey());
                                        }
                                        return RepaintBoundary(
                                          key: _pageKeys[pageIdx],
                                          child: _NotebookPage(
                                            pageEntries: pageEntries,
                                            allEntries: entries,
                                            baseIndex: start,
                                            uid: uid,
                                            bookId: widget.bookId,
                                            shape: shape,
                                            pageStyle: _pageStyle,
                                            onItemLongPress: (entry) =>
                                                _showInkContextMenu(
                                                    context, entry, uid),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (pageCount > 1)
                                    Text(
                                      '${_currentPage + 1} / $pageCount',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textTertiary),
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
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

Widget _sheetHandle({double topPadding = 6}) {
  return Container(
    margin: EdgeInsets.only(top: topPadding, bottom: 4),
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFFD4C5A9),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ── 공책 노트 페이지 ────────────────────────────────────────────────────────

class _NotebookPage extends StatelessWidget {
  const _NotebookPage({
    required this.pageEntries,
    required this.allEntries,
    required this.baseIndex,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.pageStyle,
    required this.onItemLongPress,
  });
  final List<InkChartModel> pageEntries;
  final List<InkChartModel> allEntries;
  final int baseIndex;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final _PageStyle pageStyle;
  final void Function(InkChartModel) onItemLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 10,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _NotebookLinePainter(pageStyle),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageStyle == _PageStyle.lines) const _LeftMargin(),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    pageStyle == _PageStyle.lines ? 56 : 16,
                    8,
                    8,
                  ),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _itemsPerPage,
                  itemBuilder: (_, i) {
                    if (i < pageEntries.length) {
                      final entry = pageEntries[i];
                      return _SwatchCard(
                        entry: entry,
                        uid: uid,
                        bookId: bookId,
                        shape: shape,
                        allEntries: allEntries,
                        absoluteIndex: baseIndex + i,
                        onLongPress: () => onItemLongPress(entry),
                      );
                    }
                    return const _EmptySlot();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _itemsPerPage = 9;
}

// ── 노트 왼쪽 여백 ──────────────────────────────────────────────────────────

class _LeftMargin extends StatelessWidget {
  const _LeftMargin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCCCCCC)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 노트 줄 배경 CustomPainter ────────────────────────────────────────────

class _NotebookLinePainter extends CustomPainter {
  const _NotebookLinePainter(this.style);
  final _PageStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == _PageStyle.plain) return;

    final linePaint = Paint()
      ..color = const Color(0xFFD0DCF0).withValues(alpha: 0.7)
      ..strokeWidth = 0.6;

    if (style == _PageStyle.lines) {
      final redPaint = Paint()
        ..color = const Color(0xFFE8A0A0)
        ..strokeWidth = 1.8;
      canvas.drawLine(const Offset(30, 48), Offset(size.width, 48), redPaint);
      canvas.drawLine(const Offset(30, 0), Offset(30, size.height), redPaint);
      for (double y = 76; y < size.height - 8; y += 26) {
        canvas.drawLine(Offset(38, y), Offset(size.width - 6, y), linePaint);
      }
    } else {
      // grid: 빨간 줄 없음, 격자만
      for (double y = 26; y < size.height - 8; y += 26) {
        canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), linePaint);
      }
      for (double x = 32; x < size.width - 6; x += 26) {
        canvas.drawLine(Offset(x, 6), Offset(x, size.height - 8), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookLinePainter old) =>
      old.style != style;
}

// ── 빈 슬롯 (점선 원) ──────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: CustomPaint(painter: const _DashedCirclePainter()),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4C5A9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const dashCount = 24;
    const dashAngle = 2 * math.pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        dashAngle * 0.65,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── 스와치 카드 ──────────────────────────────────────────────────────────

class _SwatchCard extends ConsumerWidget {
  const _SwatchCard({
    required this.entry,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.allEntries,
    required this.absoluteIndex,
    required this.onLongPress,
  });
  final InkChartModel entry;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final List<InkChartModel> allEntries;
  final int absoluteIndex;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: InkShapeClip(
              shape: shape,
              child: CachedNetworkImage(
                imageUrl: entry.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFFD4C5A9)),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFD4C5A9),
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Text(
                  entry.brand,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  entry.inkName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: _DetailSheet(
          charts: allEntries,
          initialIndex: absoluteIndex,
          uid: uid,
          bookId: bookId,
          shape: shape,
        ),
      ),
    );
  }
}


// ── 드래그 재정렬 뷰 ───────────────────────────────────────────────────────

class _ReorderView extends ConsumerWidget {
  const _ReorderView({
    required this.entries,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.onReorder,
  });
  final List<InkChartModel> entries;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final Future<void> Function(List<InkChartModel>) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutableList = [...entries];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFEDE7D6),
          child: Row(
            children: const [
              Icon(Icons.drag_indicator,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text(
                '드래그해서 순서를 변경하세요',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableGridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 80),
            onReorder: (oldIdx, newIdx) {
              final item = mutableList.removeAt(oldIdx);
              mutableList.insert(newIdx, item);
              onReorder(mutableList);
            },
            children: mutableList
                .asMap()
                .entries
                .map((me) => _ReorderCard(
                      key: ValueKey(me.value.id),
                      entry: me.value,
                      shape: shape,
                      index: me.key,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ReorderCard extends StatelessWidget {
  const _ReorderCard({
    super.key,
    required this.entry,
    required this.shape,
    required this.index,
  });
  final InkChartModel entry;
  final InkSwatchShape shape;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            children: [
              InkShapeClip(
                shape: shape,
                child: CachedNetworkImage(
                  imageUrl: entry.photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFD4C5A9)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFFD4C5A9)),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.drag_indicator,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          entry.inkName,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── 잉크 상세 바텀시트 ────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
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
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE4D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_currentIndex + 1} / ${widget.charts.length}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(builder: (ctx) {
              final imgH = MediaQuery.of(ctx).size.width * 0.68;
              const imgTop = 20.0;
              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: widget.charts.length,
                    onPageChanged: (i) =>
                        setState(() => _currentIndex = i),
                    itemBuilder: (_, i) => _DetailPage(
                      entry: widget.charts[i],
                      uid: widget.uid,
                      bookId: widget.bookId,
                      shape: widget.shape,
                      onDeleted: () => Navigator.pop(context),
                    ),
                  ),
                  if (_currentIndex > 0)
                    Positioned(
                      left: 8,
                      top: imgTop,
                      height: imgH,
                      child: Center(
                        child: _NavBtn(
                          icon: Icons.chevron_left,
                          onPressed: () => _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                  if (_currentIndex < widget.charts.length - 1)
                    Positioned(
                      right: 8,
                      top: imgTop,
                      height: imgH,
                      child: Center(
                        child: _NavBtn(
                          icon: Icons.chevron_right,
                          onPressed: () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── 상세 페이지 ───────────────────────────────────────────────────────────

class _DetailPage extends ConsumerWidget {
  const _DetailPage({
    required this.entry,
    required this.uid,
    required this.bookId,
    required this.shape,
    required this.onDeleted,
  });
  final InkChartModel entry;
  final String uid;
  final String bookId;
  final InkSwatchShape shape;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenW = MediaQuery.of(context).size.width;
    final dateStr =
        DateFormat('yyyy년 M월 d일').format(entry.createdAt);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: screenW * 0.68,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: InkShapeClip(
                  shape: shape,
                  child: CachedNetworkImage(
                    imageUrl: entry.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFECE4D4)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFECE4D4),
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 1.5, color: const Color(0xFFECE4D4)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.brand,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(entry.inkName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ]),
              if (entry.memo.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFECE4D4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('메모',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(entry.memo,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.6)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => _confirmDelete(context, ref),
                  child: const Text('잉크 삭제',
                      style: TextStyle(
                          color: AppColors.error, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
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

// ── 화살표 버튼 ───────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      ),
    );
  }
}

// ── 빈 상태 ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.bookId});
  final String bookId;

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
            child: const Icon(Icons.water_drop_outlined,
                size: 44, color: Color(0xFFB8A98A)),
          ),
          const SizedBox(height: 20),
          const Text('아직 잉크가 없어요',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('+ 버튼으로 첫 번째 잉크를 추가해보세요',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.push('/ink-chart/$bookId/add'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('잉크 추가'),
          ),
        ],
      ),
    );
  }
}

// ── 공책 이름 변경 바텀시트 ────────────────────────────────────────────────

class _RenameBottomSheet extends StatefulWidget {
  const _RenameBottomSheet(
      {required this.initialName, required this.onSave});
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _sheetHandle()),
              const SizedBox(height: 16),
              const Text('공책 이름 변경',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '공책 이름',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: const Color(0xFFFFFDF7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4C5A9)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD4C5A9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      widget.onSave(name);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            const Text('스와치 모양',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: InkSwatchShape.values.map((shape) {
                final selected = shape == current;
                return TapScale(
                  onTap: () {
                    ref
                        .read(inkSwatchShapeProvider.notifier)
                        .setShape(shape);
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
                      Text(shape.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
