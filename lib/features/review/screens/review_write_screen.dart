import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/providers.dart';
import '../../archive/providers/archive_detail_provider.dart';
import '../providers/review_write_provider.dart';
import '../../../shared/widgets/archive/add_product_bottom_sheet.dart';
import '../../../shared/widgets/common/star_rating.dart';
import '../../../data/models/review_model.dart';

class ReviewWriteScreen extends ConsumerStatefulWidget {
  const ReviewWriteScreen({super.key, this.reviewToEdit, this.initialType, this.initialProductId});
  final ReviewModel? reviewToEdit;
  final String? initialType;        // 'ink' | 'pen' | 'paper'
  final String? initialProductId;

  @override
  ConsumerState<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends ConsumerState<ReviewWriteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.reviewToEdit != null) {
        ref.read(reviewWriteProvider.notifier).initForEdit(widget.reviewToEdit!);
      } else if (widget.initialType != null && widget.initialProductId != null) {
        // 제품 상세에서 진입 시 해당 제품 자동 태깅
        switch (widget.initialType) {
          case 'ink':
            ref.read(reviewWriteProvider.notifier).addInk(widget.initialProductId!);
          case 'pen':
            ref.read(reviewWriteProvider.notifier).addPen(widget.initialProductId!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewWriteProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reviewToEdit != null ? '리뷰 수정' : '리뷰 작성'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: state.isLoading || (state.editingReviewId == null && state.images.isEmpty) ? null : () => _submit(context),
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('완료'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 사진 ──────────────────────────────────
            _SectionHeader(title: '사진', required: true),
            _PhotoSection(
              images: state.images,
              existingImageUrls: state.existingImageUrls,
              onAdd: _pickImages,
              onRemove: (i) => ref.read(reviewWriteProvider.notifier).removeImage(i),
              onRemoveExisting: (i) => ref.read(reviewWriteProvider.notifier).removeExistingImage(i),
              onReorder: (oldIdx, newIdx) =>
                  ref.read(reviewWriteProvider.notifier).reorderImage(oldIdx, newIdx),
            ),

            _Divider(),

            // ── 2. 장비 태깅 ─────────────────────────────
            _SectionHeader(title: '장비 태깅', subtitle: '선택'),
            _GearSection(),

            _Divider(),

            // ── 3. 리뷰 내용 ─────────────────────────────
            _SectionHeader(title: '리뷰 내용', subtitle: '선택'),
            const _TitleSection(),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 4),
            const _TextSection(),

            // ── 5. 별점 (맨 아래) ─────────────────────────
            _SectionHeader(title: '별점'),
            _RatingSection(rating: state.rating),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final xfiles = await picker.pickMultiImage(imageQuality: 85);
    if (xfiles.isEmpty) return;
    ref.read(reviewWriteProvider.notifier).addImages(xfiles.map((f) => File(f.path)).toList());
  }

  Future<void> _submit(BuildContext context) async {
    try {
      final reviewId = await ref.read(reviewWriteProvider.notifier).submit();
      if (context.mounted) {
        context.pushReplacement('/review/$reviewId');
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('storage')
            ? '이미지 업로드에 실패했어요. 다시 시도해주세요.'
            : '저장에 실패했어요. 다시 시도해주세요.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── 공통 헤더 ────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.required = false});
  final String title;
  final String? subtitle;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (required)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('필수',
                  style: TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(subtitle!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 8, color: Color(0xFFF4F4F4));
}

// ── 1. 사진 (드래그 순서 변경) ──────────────────────────────
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.images,
    this.existingImageUrls = const [],
    required this.onAdd,
    required this.onRemove,
    required this.onRemoveExisting,
    required this.onReorder,
  });
  final List<File> images;
  final List<String> existingImageUrls;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onRemoveExisting;
  final void Function(int oldIdx, int newIdx) onReorder;

  @override
  Widget build(BuildContext context) {
    final max = AppConstants.maxReviewImages;
    final totalCount = images.length + existingImageUrls.length;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalCount == 0)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.textTertiary),
                    SizedBox(height: 8),
                    Text('사진을 추가해주세요',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 108, // 썸네일(100) + 여유(8)
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                onReorder: onReorder,
                itemCount: totalCount,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (_, _) {
                      final scale = 1.0 + animation.value * 0.08;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: child,
                  );
                },
                itemBuilder: (_, i) {
                  if (i < existingImageUrls.length) {
                    final url = existingImageUrls[i];
                    return ReorderableDragStartListener(
                      key: ValueKey(url),
                      index: i,
                      child: _PhotoThumb(
                        url: url,
                        isFirst: i == 0,
                        onRemove: () => onRemoveExisting(i),
                      ),
                    );
                  }
                  final fileIndex = i - existingImageUrls.length;
                  final file = images[fileIndex];
                  return ReorderableDragStartListener(
                    key: ValueKey(file.path),
                    index: i,
                    child: _PhotoThumb(
                      file: file,
                      isFirst: i == 0,
                      onRemove: () => onRemove(fileIndex),
                    ),
                  );
                },
              ),
            ),
          // 카운터 — 썸네일 밖에 배치
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$totalCount / $max',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              if (totalCount < max) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAdd,
                  child: Row(
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text('사진 추가',
                          style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({this.file, this.url, required this.isFirst, required this.onRemove});
  final File? file;
  final String? url;
  final bool isFirst;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null
                ? CachedNetworkImage(
                    imageUrl: url!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Image.file(file!, width: 100, height: 100, fit: BoxFit.cover),
          ),
          // 삭제 버튼
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration:
                    const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
          // 대표 뱃지
          if (isFirst)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: const Text('대표',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          // 드래그 힌트 아이콘
          Positioned(
            bottom: isFirst ? 24 : 4,
            left: 4,
            child: const Icon(Icons.drag_indicator, color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── 2. 장비 태깅 ─────────────────────────────────────────────
class _GearSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewWriteProvider);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GearRow(
            type: 'ink',
            icon: Icons.water_drop_outlined,
            label: '잉크 추가',
            items: state.inkIds,
            onAdd: () => _showSearch(context, ref, 'ink'),
            onRemove: (id) => ref.read(reviewWriteProvider.notifier).removeInk(id),
          ),
          const SizedBox(height: 10),
          _GearRow(
            type: 'pen',
            icon: Icons.edit_outlined,
            label: '만년필 추가',
            items: state.penIds,
            onAdd: () => _showSearch(context, ref, 'pen'),
            onRemove: (id) => ref.read(reviewWriteProvider.notifier).removePen(id),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref, String type) {
    if (!ref.read(reviewWriteProvider.notifier).canAddTag) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('태그는 최대 5개까지 추가할 수 있어요')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSearchSheet(
        type: type,
        onSelected: (id, _) {
          switch (type) {
            case 'ink': ref.read(reviewWriteProvider.notifier).addInk(id);
            case 'pen': ref.read(reviewWriteProvider.notifier).addPen(id);
          }
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _GearRow extends StatelessWidget {
  const _GearRow({
    required this.type,
    required this.icon,
    required this.label,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });
  final String type;
  final IconData icon;
  final String label;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: items.map((id) => _GearChip(type: type, id: id, onRemove: () => onRemove(id))).toList(),
          ),
        ],
      ],
    );
  }
}

class _GearChip extends ConsumerWidget {
  const _GearChip({required this.type, required this.id, required this.onRemove});
  final String type;
  final String id;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(archiveDetailProvider((type: type, productId: id)));
    final label = state.when(
      data: (data) {
        if (data == null) return id;
        if (type == 'ink') return '${data.brand} ${data.name}';
        if (type == 'pen') return '${data.brand} ${data.modelName}';
        return '${data.brand} ${data.productName}';
      },
      loading: () => id,
      error: (_, _) => id,
    );

    return Chip(
      label: Text(label,
          style: const TextStyle(
              fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
      onDeleted: onRemove,
      backgroundColor: AppColors.primary,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── 3-a. 제목 ────────────────────────────────────────────────
class _TitleSection extends ConsumerStatefulWidget {
  const _TitleSection();

  @override
  ConsumerState<_TitleSection> createState() => _TitleSectionState();
}

class _TitleSectionState extends ConsumerState<_TitleSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(reviewWriteProvider).title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '제목을 입력하세요',
          border: InputBorder.none,
          counterText: '',
        ),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        maxLength: 50,
        onChanged: (v) => ref.read(reviewWriteProvider.notifier).setTitle(v),
      ),
    );
  }
}

// ── 3-b. 본문 ────────────────────────────────────────────────
class _TextSection extends ConsumerStatefulWidget {
  const _TextSection();

  @override
  ConsumerState<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends ConsumerState<_TextSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(reviewWriteProvider).body);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: TextField(
        controller: _controller,
        maxLines: 6,
        maxLength: AppConstants.maxReviewBody,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: '잉크 색상, 종이와의 궁합, 닙의 느낌 등을 자유롭게 작성해보세요.',
          alignLabelWithHint: true,
        ),
        onChanged: (v) => ref.read(reviewWriteProvider.notifier).setBody(v),
      ),
    );
  }
}

// ── 5. 별점 (맨 아래) ────────────────────────────────────────
class _RatingSection extends ConsumerWidget {
  const _RatingSection({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          StarRatingInput(
            rating: rating,
            onChanged: (r) => ref.read(reviewWriteProvider.notifier).setRating(r),
            size: 36,
          ),
          const SizedBox(width: 12),
          Text(
            rating == 0.0 ? '별점을 선택해주세요' : _label(rating),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: rating == 0.0 ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _label(double r) {
    if (r >= 4.5) return '최고예요! ★ ${r.toStringAsFixed(1)}';
    if (r >= 4.0) return '좋아요 ★ ${r.toStringAsFixed(1)}';
    if (r >= 3.0) return '보통이에요 ★ ${r.toStringAsFixed(1)}';
    if (r >= 2.0) return '별로예요 ★ ${r.toStringAsFixed(1)}';
    return '최악이에요 ★ ${r.toStringAsFixed(1)}';
  }
}

// ── 제품 검색 시트 ────────────────────────────────────────────
class _ProductSearchSheet extends ConsumerStatefulWidget {
  const _ProductSearchSheet({required this.type, required this.onSelected});
  final String type;
  final void Function(String id, String name) onSelected;

  @override
  ConsumerState<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<_ProductSearchSheet> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    final repo = ref.read(archiveRepoProvider);
    try {
      switch (widget.type) {
        case 'ink': _results = await repo.searchInks(query);
        case 'pen': _results = await repo.searchPens(query);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = {'ink': '잉크', 'pen': '만년필'}[widget.type] ?? '';
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '$typeLabel 검색',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _controller.text.isEmpty
                              ? '$typeLabel 이름을 검색해보세요'
                              : '검색 결과가 없습니다.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (_controller.text.isNotEmpty && !_isLoading) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text('+ "${_controller.text}" 직접 등록하기'),
                            onPressed: () => showAddProductSheet(
                              context,
                              initialType: widget.type,
                              initialName: _controller.text,
                              onAdded: (id, name) {
                                widget.onSelected(id, name);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final item = _results[i];
                      return ListTile(
                        title: Text(item.displayName),
                        onTap: () => widget.onSelected(item.id, item.displayName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
