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

  Future<String> submit() async {
    final authState = _ref.read(authUserProvider);
    if (authState.isLoading) throw Exception('잠시 후 다시 시도해주세요.');
    final uid = authState.value;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    
    // 수정 모드가 아니고 이미지가 없으면 에러
    if (state.editingReviewId == null && state.images.isEmpty) {
      throw Exception('사진을 1장 이상 추가해주세요.');
    }

    state = state.copyWith(isLoading: true);
    try {
      if (state.editingReviewId != null) {
        // 수정 모드: 새 이미지만 업로드하고 기존 URL + 새 URL 합쳐서 업데이트
        final newImageUrls = state.images.isNotEmpty
            ? await withRetry(() => _ref.read(storageServiceProvider).uploadReviewImages(state.images, state.editingReviewId!))
            : [];
        final allImageUrls = [...state.existingImageUrls, ...newImageUrls];

        final categories = <String>[];
        if (state.inkIds.isNotEmpty) categories.add('잉크');
        if (state.penIds.isNotEmpty) categories.add('만년필');

        await withRetry(() => _ref.read(reviewRepoProvider).updateReview(state.editingReviewId!, {
          'title': state.title,
          'body': state.body,
          'rating': state.rating,
          'inkIds': state.inkIds,
          'penIds': state.penIds,
          'categories': categories,
          'imageUrls': allImageUrls,
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
      debugPrint('[ReviewWrite] 이미지 업로드 시작: ${state.images.length}장');
      final imageUrls = await withRetry(
        () => _ref.read(storageServiceProvider).uploadReviewImages(state.images, reviewId),
      );
      debugPrint('[ReviewWrite] 이미지 업로드 완료: $imageUrls');

      final review = ReviewModel(
        id: reviewId,
        authorId: uid,
        imageUrls: imageUrls,
        title: state.title,
        body: state.body,
        rating: state.rating,
        inkIds: state.inkIds,
        penIds: state.penIds,
        createdAt: DateTime.now(),
      );

      debugPrint('[ReviewWrite] Firestore 저장 시작');
      await withRetry(() => _ref.read(reviewRepoProvider).createReview(review));
      debugPrint('[ReviewWrite] Firestore 저장 완료');

      // 리뷰 작성 경험치 부여 + 레벨업 체크
      final levelUp = await _ref.read(userRepoProvider).addExpAndCheck(uid, LevelSystem.expReview);
      if (levelUp != null) {
        _ref.read(levelUpProvider.notifier).state = levelUp;
      }
      debugPrint('[ReviewWrite] 경험치 부여 완료');

      _ref.invalidate(feedProvider);
      debugPrint('[ReviewWrite] 홈 피드 새로고침 요청됨');

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
