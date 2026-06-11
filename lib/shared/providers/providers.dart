import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/level_system.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/fcm_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/archive_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/inquiry_repository.dart';
import '../../data/models/user_model.dart';

// ── 네트워크 연결 상태 ───────────────────────────────────────
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// ── 서비스 ─────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// ── 레포지토리 ──────────────────────────────────────────────
final userRepoProvider = Provider<UserRepository>((ref) => UserRepository());
final reviewRepoProvider = Provider<ReviewRepository>((ref) => ReviewRepository());
final archiveRepoProvider = Provider<ArchiveRepository>((ref) => ArchiveRepository(ref.read(reviewRepoProvider)));
final chatRepoProvider = Provider<ChatRepository>((ref) => ChatRepository());
final inquiryRepoProvider = Provider<InquiryRepository>((ref) => InquiryRepository());

// ── 현재 유저 ────────────────────────────────────────────��──
final authUserProvider = StreamProvider<String?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(authUserProvider).value;
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepoProvider).watchUser(uid);
});

final currentUidProvider = Provider<String?>((ref) {
  final streamValue = ref.watch(authUserProvider).value;
  if (streamValue != null) return streamValue;
  return FirebaseAuth.instance.currentUser?.uid;
});

/// 레벨업 발생 시 설정 — MainShell에서 감지하여 다이얼로그 표시
final levelUpProvider = StateProvider<LevelUpInfo?>((ref) => null);

/// 알림 탭 시 이동할 경로 — MainShell에서 감지하여 navigate
final pendingRouteProvider = StateProvider<String?>((ref) => null);

/// FCM 서비스 — 앱 시작 시 initialize() 호출됨
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    onNavigate: (route) =>
        ref.read(pendingRouteProvider.notifier).state = route,
    onTokenRefresh: (_, token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token}).catchError((_) {});
      }
    },
  );

  // 로그인 감지 시 FCM 토큰 저장
  ref.listen<AsyncValue<String?>>(authUserProvider, (prev, next) {
    final uid = next.value;
    if (uid != null && prev?.value == null) {
      service.saveToken(uid);
    }
  });

  return service;
});

