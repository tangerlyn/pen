import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_book_model.dart';
import '../../../shared/widgets/ink_drop_circle.dart';
import '../../../shared/widgets/tap_scale.dart';
import '../../mypage/widgets/ink_swatch_shape.dart';
import '../controllers/swatch_record_controller.dart';

/// 스와치 사진 영역 — 고르기 전엔 촬영 안내, 고른 뒤엔 모양대로 클리핑해서 보여준다.
class SwatchPhotoField extends StatelessWidget {
  const SwatchPhotoField({
    super.key,
    required this.photo,
    required this.photoUrl,
    required this.shape,
    required this.onTap,
  });

  final File? photo;
  final String? photoUrl;
  final InkSwatchShape shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null || photoUrl != null;
    return Semantics(
      button: true,
      label: hasPhoto ? '스와치 사진 변경' : '스와치 사진 추가',
      child: TapScale(
        onTap: onTap,
        scale: 0.97,
        child: AspectRatio(
          aspectRatio: 1.4,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: hasPhoto ? AppColors.primary : AppColors.divider,
                width: 1.5,
              ),
              boxShadow: AppShadows.card,
            ),
            child: hasPhoto
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: InkShapeClip(
                            shape: shape,
                            child: photo != null
                                ? Image.file(photo!, fit: BoxFit.cover)
                                : CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Text(
                            '사진 변경',
                            style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 44, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '스와치 사진 찍기',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('카메라 또는 갤러리에서 선택', style: AppTextStyles.labelMedium),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 잉크 선택 칸 — 탭하면 매칭 시트를 연다
class SwatchInkField extends StatelessWidget {
  const SwatchInkField({super.key, required this.ink, required this.onTap});

  final SwatchInk? ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = ink;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected == null ? AppColors.divider : AppColors.primary,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (selected == null)
                  const Icon(Icons.search, color: AppColors.textSecondary)
                else
                  InkDropCircle(color: _inkColor(selected.hexColor), size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: selected == null
                      ? const Text('아카이브에서 잉크 찾기', style: AppTextStyles.bodyMedium)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selected.name, style: AppTextStyles.titleSmall),
                            if (selected.brand.isNotEmpty)
                              Text(selected.brand, style: AppTextStyles.labelMedium),
                            if (selected.inkId == null)
                              const Text('직접 입력한 잉크', style: AppTextStyles.caption),
                          ],
                        ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _inkColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length != 6) return AppColors.chipBackground;
    final value = int.tryParse('FF$clean', radix: 16);
    return value == null ? AppColors.chipBackground : Color(value);
  }
}

class SwatchSectionLabel extends StatelessWidget {
  const SwatchSectionLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(text: ' 필수', style: TextStyle(color: AppColors.primary)),
        ],
      ),
      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class SwatchTextField extends StatelessWidget {
  const SwatchTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.maxLength = 100,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}

/// 기록 날짜 — 비워두면 저장 시각이 기록 날짜
class SwatchDateTile extends StatelessWidget {
  const SwatchDateTile({super.key, required this.date, required this.onChanged});

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = date;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(
        d == null ? '기록 날짜: 오늘' : '기록 날짜: ${d.year}.${d.month}.${d.day}',
        style: AppTextStyles.bodyMedium,
      ),
      trailing: d == null
          ? null
          : IconButton(
              tooltip: '날짜 지우기',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: d ?? now,
          firstDate: DateTime(1990),
          lastDate: now,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// 저장할 공책 — 공책이 없으면 기본 공책이 만들어진다고 알려준다
class SwatchBookTile extends StatelessWidget {
  const SwatchBookTile({
    super.key,
    required this.books,
    required this.selectedId,
    required this.onSelect,
  });

  final List<InkBookModel> books;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.menu_book_outlined),
        title: Text('저장할 공책: $kDefaultRecordBookName', style: AppTextStyles.bodyMedium),
        subtitle: Text('첫 기록이라 비공개 공책을 새로 만들어요', style: AppTextStyles.labelMedium),
      );
    }
    final selected = books.where((b) => b.id == selectedId).firstOrNull ?? books.first;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text('저장할 공책: ${selected.name}', style: AppTextStyles.bodyMedium),
      trailing: books.length > 1 ? const Icon(Icons.expand_more) : null,
      onTap: books.length < 2
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                ),
                builder: (ctx) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in books)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: b.color, radius: 10),
                          title: Text(b.name),
                          trailing: b.id == selected.id
                              ? const Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () => Navigator.pop(ctx, b.id),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null) onSelect(picked);
            },
    );
  }
}
