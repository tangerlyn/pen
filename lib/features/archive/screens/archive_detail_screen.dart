import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/archive_detail_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/wishlist_providers.dart';
import '../../../shared/widgets/wishlist_toast.dart';
import '../../../shared/widgets/center_toast.dart';
import '../../../data/models/ink_model.dart';
import '../../../data/models/pen_model.dart';
import '../../../shared/widgets/review/review_feed_card.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart'
    show InkColorPicker;
import '../providers/archive_provider.dart';
part '../widgets/archive_detail_content.dart';
part '../widgets/archive_detail_sheets.dart';
// import 'ink_compare_screen.dart'; // 색상 비교 — 구현 완료, 적용 보류

class ArchiveDetailScreen extends ConsumerWidget {
  const ArchiveDetailScreen({
    super.key,
    required this.type,
    required this.productId,
  });
  final String type;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      archiveDetailProvider((type: type, productId: productId)),
    );
    final data = state.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: data == null
            ? null
            : Text(
                type == 'ink' ? (data as InkModel).name : data.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: data == null
            ? []
            : [
                _WishlistButton(
                  type: type,
                  productId: productId,
                  productName: type == 'ink'
                      ? (data as InkModel).name
                      : data.displayName,
                  brand: data.brand,
                  hexColor: type == 'ink' ? (data as InkModel).hexColor : '',
                ),
                _ReportButton(
                  type: type,
                  productId: productId,
                  targetName: data.displayName,
                ),
              ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('오류: $e')),
        data: (data) => data == null
            ? const Center(child: Text('제품을 찾을 수 없습니다.'))
            : _DetailBody(type: type, data: data, productId: productId),
      ),
    );
  }
}

// ── 본문 (SingleChildScrollView — Viewport 없음, 너비 항상 유한) ──────────────
