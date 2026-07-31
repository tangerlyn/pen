import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/ink_chart_model.dart';
import '../../../shared/widgets/image_viewer_screen.dart';

/// 잉크 상세의 "메모" 카드 내용 — 텍스트와 추가로 첨부한 사진을 순서대로 표시.
/// contentBlocks가 없으면(예전 데이터) 기존처럼 memo 텍스트만 표시.
class InkMemoContent extends StatelessWidget {
  const InkMemoContent({super.key, required this.entry});
  final InkChartModel entry;

  static const _textStyle =
      TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6);

  @override
  Widget build(BuildContext context) {
    final blocks = entry.contentBlocks;
    if (blocks == null || blocks.isEmpty) {
      return Text(entry.memo, style: _textStyle);
    }

    final imageUrls = blocks
        .where((b) => b['type'] == 'image')
        .map((b) => b['url'] as String? ?? '')
        .where((u) => u.isNotEmpty)
        .toList();

    final children = <Widget>[];
    for (final block in blocks) {
      if (block['type'] == 'text') {
        final text = block['content'] as String? ?? '';
        if (text.isNotEmpty) children.add(Text(text, style: _textStyle));
      } else if (block['type'] == 'image') {
        final url = block['url'] as String? ?? '';
        if (url.isEmpty) continue;
        final index = imageUrls.indexOf(url);
        children.add(
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  imageUrls: imageUrls,
                  initialIndex: index >= 0 ? index : 0,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
