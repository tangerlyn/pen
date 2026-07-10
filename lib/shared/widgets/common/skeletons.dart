import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ── 내부 헬퍼 ─────────────────────────────────────────────────
Widget _sBox({double? w, double? h, double r = 6, EdgeInsets? m}) => Container(
      width: w,
      height: h,
      margin: m,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
      ),
    );

Widget _circle(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );

Widget _shimmer(Widget child) => Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );

// ── 홈 최신 리뷰 가로 스크롤 카드 ──────────────────────────────
class HomeReviewCardSkeleton extends StatelessWidget {
  const HomeReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Container(
          width: 150,
          height: 210,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}

// ── 리뷰 탭 그리드 셀 ─────────────────────────────────────────
class ReviewGridSkeleton extends StatelessWidget {
  const ReviewGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Container(color: Colors.white),
      );
}

// ── 리뷰 탭 목록 아이템 ───────────────────────────────────────
class ReviewListTileSkeleton extends StatelessWidget {
  const ReviewListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sBox(h: 18, w: 34, r: 4),
                        const SizedBox(width: 6),
                        _sBox(h: 13, w: 100),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _sBox(h: 12, w: 160, m: const EdgeInsets.only(bottom: 8)),
                    _sBox(h: 12, w: 100),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _sBox(w: 72, h: 72, r: 8),
            ],
          ),
        ),
      );
}

// ── 커뮤니티 포스트 카드 ──────────────────────────────────────
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sBox(h: 15, m: const EdgeInsets.only(bottom: 8)),
                    _sBox(h: 12, w: 200, m: const EdgeInsets.only(bottom: 12)),
                    _sBox(h: 11, w: 140),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _sBox(w: 72, h: 72, r: 8),
            ],
          ),
        ),
      );
}

// ── 아카이브 잉크 원형 ────────────────────────────────────────
class InkCircleSkeleton extends StatelessWidget {
  const InkCircleSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circle(56),
            const SizedBox(height: 6),
            _sBox(h: 10, w: 48, m: const EdgeInsets.only(bottom: 3)),
            _sBox(h: 10, w: 36),
          ],
        ),
      );
}

// ── 아카이브 만년필 목록 ──────────────────────────────────────
class PenListTileSkeleton extends StatelessWidget {
  const PenListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _shimmer(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _sBox(w: 44, h: 44, r: 8),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sBox(h: 14, w: 140, m: const EdgeInsets.only(bottom: 6)),
                    _sBox(h: 12, w: 100),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _sBox(h: 12, w: 36, m: const EdgeInsets.only(bottom: 4)),
                  _sBox(h: 11, w: 40),
                ],
              ),
            ],
          ),
        ),
      );
}

// ── 상세 페이지 (리뷰/게시글) ────────────────────────────────
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _shimmer(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: w, height: w, color: Colors.white),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _circle(40),
                    const SizedBox(width: 12),
                    _sBox(h: 14, w: 100),
                  ],
                ),
                const SizedBox(height: 16),
                _sBox(h: 20, w: 200, m: const EdgeInsets.only(bottom: 12)),
                _sBox(h: 13, m: const EdgeInsets.only(bottom: 8)),
                _sBox(h: 13, w: 260, m: const EdgeInsets.only(bottom: 8)),
                _sBox(h: 13, w: 180),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _sBox(w: 60, h: 22, r: 4),
                    const SizedBox(width: 8),
                    _sBox(w: 60, h: 22, r: 4),
                    const SizedBox(width: 8),
                    _sBox(w: 60, h: 22, r: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
