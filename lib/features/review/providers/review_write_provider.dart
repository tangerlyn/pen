import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/level_system.dart';
import '../../../core/utils/network_utils.dart';
import '../../../data/models/review_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/providers/feed_provider.dart';
import '../../home/providers/review_detail_provider.dart';
import '../analytics/review_write_tracker.dart';

/// 저장 실패를 단계와 함께 전달한다. 화면은 [message]를 토스트로 보여주고,
/// [stage]로 실패 로그를 남긴다.
class ReviewSubmitException implements Exception {
  const ReviewSubmitException(this.stage, this.message, [this.cause]);
  final ReviewErrorStage stage;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

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
  /// draftReviewId: 작성 화면 진입 시 정해 둔 문서 ID. 같은 화면에서 다시 저장해도
  ///   같은 문서를 덮어쓰므로, 저장은 됐는데 응답만 실패한 경우에도 리뷰가 중복 생성되지 않는다.
  /// onCommitted: Firestore 쓰기가 끝난 직후(EXP 지급 전) 호출 — 성공 로그 기록용.
  Future<String> submitWithBlocks({
    required List<Map<String, dynamic>> contentBlocks,
    required List<String> imageUrls,
    required String body,
    required String draftReviewId,
    void Function(String reviewId)? onCommitted,
  }) async {
    final authState = _ref.read(authUserProvider);
    if (authState.isLoading) {
      throw const ReviewSubmitException(ReviewErrorStage.auth, '잠시 후 다시 시도해주세요.');
    }
    final uid = authState.value;
    if (uid == null) {
      throw const ReviewSubmitException(ReviewErrorStage.auth, '로그인이 필요합니다.');
    }

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
        onCommitted?.call(state.editingReviewId!);

        _ref.invalidate(feedProvider);
        _ref.invalidate(reviewDetailProvider(state.editingReviewId!));

        final resultId = state.editingReviewId!;
        state = const ReviewWriteState();
        return resultId;
      }

      // 작성 모드
      final reviewId = draftReviewId;
      final currentUser = _ref.read(currentUserProvider).value;
      final review = ReviewModel(
        id: reviewId,
        authorId: uid,
        authorNickname: currentUser?.nickname ?? '',
        authorLevel: currentUser?.level ?? 1,
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
      onCommitted?.call(reviewId);

      // 리뷰는 이미 저장됐으므로 EXP 지급 실패가 저장 실패로 보이면 안 된다.
      // (예전에는 여기서 예외가 나면 에러 토스트가 뜨고, 사용자가 다시 눌러 중복 리뷰가 생길 수 있었다)
      try {
        final levelUp = await _ref.read(userRepoProvider).addExpAndCheck(uid, LevelSystem.expReview);
        if (levelUp != null) {
          _ref.read(levelUpProvider.notifier).state = levelUp;
        }
      } catch (e, stack) {
        debugPrint('[ReviewWrite] EXP 지급 실패: $e');
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'review EXP grant failed');
      }

      _ref.invalidate(feedProvider);
      state = const ReviewWriteState();
      return reviewId;
    } catch (e, stack) {
      debugPrint('[ReviewWrite] 에러 발생: $e\n$stack');
      state = state.copyWith(isLoading: false);
      throw ReviewSubmitException(ReviewErrorStage.firestoreWrite, e.toString().replaceAll('Exception: ', ''), e);
    }
  }
}

final reviewWriteProvider = StateNotifierProvider<ReviewWriteNotifier, ReviewWriteState>((ref) {
  return ReviewWriteNotifier(ref);
});
