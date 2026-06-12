import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/level_system.dart';
import '../../../core/utils/network_utils.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/providers/feed_provider.dart';
import '../../home/providers/review_detail_provider.dart';

class ReviewWriteState {
  const ReviewWriteState({
    this.images = const [],
    this.inkIds = const [],
    this.penIds = const [],
    this.title = '',
    this.body = '',
    this.rating = 0.0,
    this.isLoading = false,
    this.editingReviewId,
    this.existingImageUrls = const [],
  });

  final List<File> images;
  final List<String> inkIds;
  final List<String> penIds;
  final String title;
  final String body;
  final double rating;
  final bool isLoading;
  final String? editingReviewId;
  final List<String> existingImageUrls;

  ReviewWriteState copyWith({
    List<File>? images,
    List<String>? inkIds,
    List<String>? penIds,
    String? title,
    String? body,
    double? rating,
    bool? isLoading,
    String? editingReviewId,
    List<String>? existingImageUrls,
  }) {
    return ReviewWriteState(
      images: images ?? this.images,
      inkIds: inkIds ?? this.inkIds,
      penIds: penIds ?? this.penIds,
      title: title ?? this.title,
      body: body ?? this.body,
      rating: rating ?? this.rating,
      isLoading: isLoading ?? this.isLoading,
      editingReviewId: editingReviewId ?? this.editingReviewId,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
    );
  }
}

class ReviewWriteNotifier extends StateNotifier<ReviewWriteState> {
  ReviewWriteNotifier(this._ref) : super(const ReviewWriteState());

  final Ref _ref;
  final _uuid = const Uuid();

  // 수정 모드 초기화 (기존 리뷰 데이터 로드)
  void initForEdit(ReviewModel review) {
    state = ReviewWriteState(
      inkIds: review.inkIds,
      penIds: review.penIds,
      title: review.title,
      body: review.body,
      rating: review.rating,
      editingReviewId: review.id,
      existingImageUrls: review.imageUrls,
    );
  }

  void addImages(List<File> files) {
    final current = List<File>.from(state.images);
    for (final f in files) {
      if (current.length >= AppConstants.maxReviewImages) break;
      current.add(f);
    }
    state = state.copyWith(images: current);
  }

  void removeImage(int index) {
    final current = List<File>.from(state.images)..removeAt(index);
    state = state.copyWith(images: current);
  }

  void removeExistingImage(int index) {
    final current = List<String>.from(state.existingImageUrls)..removeAt(index);
    state = state.copyWith(existingImageUrls: current);
  }

  void reorderImage(int oldIndex, int newIndex) {
    final current = List<File>.from(state.images);
    // ReorderableListView는 뒤로 이동 시 newIndex가 1 더 크게 옴
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = current.removeAt(oldIndex);
    current.insert(adjusted, item);
    state = state.copyWith(images: current);
  }

  static const _maxTags = 5;

  bool get canAddTag => state.inkIds.length + state.penIds.length < _maxTags;

  void addInk(String id) {
    if (!state.inkIds.contains(id) && canAddTag) {
      state = state.copyWith(inkIds: [...state.inkIds, id]);
    }
  }

  void removeInk(String id) => state = state.copyWith(inkIds: state.inkIds.where((i) => i != id).toList());

  void addPen(String id) {
    if (!state.penIds.contains(id) && canAddTag) {
      state = state.copyWith(penIds: [...state.penIds, id]);
    }
  }

  void removePen(String id) => state = state.copyWith(penIds: state.penIds.where((i) => i != id).toList());

  void setTitle(String title) => state = state.copyWith(title: title);
  void setBody(String body) => state = state.copyWith(body: body);
  void setRating(double rating) => state = state.copyWith(rating: rating);

  void reset() => state = const ReviewWriteState();

  /// 블로그 에디터로 빌드된 contentBlocks를 받아 저장.
  /// imageUrls: contentBlocks에서 추출한 이미지 URL 목록 (썸네일 등 하위호환용).
  /// body: 텍스트 블록들 합산 (검색/미리보기 하위호환용).
  Future<String> submitWithBlocks({
    required List<Map<String, dynamic>> contentBlocks,
    required List<String> imageUrls,
    required String body,
  }) async {
    final authState = _ref.read(authUserProvider);
    if (authState.isLoading) throw Exception('잠시 후 다시 시도해주세요.');
    final uid = authState.value;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    state = state.copyWith(isLoading: true);
    try {
      if (state.editingReviewId != null) {
        final categories = <String>[];
        if (state.inkIds.isNotEmpty) categories.add('잉크');
        if (state.penIds.isNotEmpty) categories.add('만년필');

        await withRetry(() => _ref.read(reviewRepoProvider).updateReview(state.editingReviewId!, {
          'title': state.title,
          'body': body,
          'rating': state.rating,
          'inkIds': state.inkIds,
          'penIds': state.penIds,
          'categories': categories,
          'imageUrls': imageUrls,
          'contentBlocks': contentBlocks,
          'updatedAt': FieldValue.serverTimestamp(),
        }));

        _ref.invalidate(feedProvider);
        _ref.invalidate(reviewDetailProvider(state.editingReviewId!));

        final resultId = state.editingReviewId!;
        state = const ReviewWriteState();
        return resultId;
      }

      // 작성 모드
      final reviewId = _uuid.v4();
      final review = ReviewModel(
        id: reviewId,
        authorId: uid,
        imageUrls: imageUrls,
        contentBlocks: contentBlocks,
        title: state.title,
        body: body,
        rating: state.rating,
        inkIds: state.inkIds,
        penIds: state.penIds,
        createdAt: DateTime.now(),
      );

      debugPrint('[ReviewWrite] Firestore 저장 시작');
      await withRetry(() => _ref.read(reviewRepoProvider).createReview(review));
      debugPrint('[ReviewWrite] Firestore 저장 완료');

      final levelUp = await _ref.read(userRepoProvider).addExpAndCheck(uid, LevelSystem.expReview);
      if (levelUp != null) {
        _ref.read(levelUpProvider.notifier).state = levelUp;
      }

      _ref.invalidate(feedProvider);
      state = const ReviewWriteState();
      return reviewId;
    } catch (e, stack) {
      debugPrint('[ReviewWrite] 에러 발생: $e\n$stack');
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

final reviewWriteProvider = StateNotifierProvider<ReviewWriteNotifier, ReviewWriteState>((ref) {
  return ReviewWriteNotifier(ref);
});
