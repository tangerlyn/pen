import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../shared/providers/providers.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.error,
    this.pendingUid,
    this.pendingProvider,
    this.nickname = '',
    this.profileImagePath,
    this.interests = const [],
  });

  final bool isLoading;
  final String? error;
  final String? pendingUid;
  final String? pendingProvider;
  final String nickname;
  final String? profileImagePath;
  final List<String> interests;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? pendingUid,
    String? pendingProvider,
    String? nickname,
    String? profileImagePath,
    List<String>? interests,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingUid: pendingUid ?? this.pendingUid,
      pendingProvider: pendingProvider ?? this.pendingProvider,
      nickname: nickname ?? this.nickname,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      interests: interests ?? this.interests,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService, this._storageService) : super(const AuthState());

  final AuthService _authService;
  final StorageService _storageService;

  Future<void> signInWithKakao(BuildContext context) =>
      _signIn(context, _authService.signInWithKakao);

  Future<void> signInWithNaver(BuildContext context) =>
      _signIn(context, _authService.signInWithNaver);

  Future<void> signInWithApple(BuildContext context) =>
      _signIn(context, _authService.signInWithApple);

  Future<void> _signIn(
    BuildContext context,
    Future<AuthResult> Function() loginFn,
  ) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await loginFn();

      state = state.copyWith(
        isLoading: false,
        pendingUid: result.uid,
        pendingProvider: result.provider,
      );

      if (!context.mounted) return;

      if (result.hasProfile) {
        context.go('/');
      } else {
        context.go('/signup/nickname');
      }
    } catch (e, stack) {
      debugPrint('[Auth] 로그인 에러: $e\n$stack');
      final msg = e.toString().contains('canceled') ? null : '로그인에 실패했어요. 다시 시도해주세요.';
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  void setNickname(String nickname) => state = state.copyWith(nickname: nickname);
  void setProfileImagePath(String path) => state = state.copyWith(profileImagePath: path);
  void setInterests(List<String> interests) => state = state.copyWith(interests: interests);

  Future<bool> checkNickname(String nickname) =>
      _authService.isNicknameAvailable(nickname);

  Future<void> completeSignup(BuildContext context) async {
    // pendingUid는 로그인 직후 메모리 상태라, 카카오 로그인처럼 외부 앱으로
    // 전환됐다가 돌아오며 프로세스가 재시작되면 비어있을 수 있다. 이 경우
    // Firebase Auth에 남아있는 세션의 uid로 폴백해야 회원가입을 이어갈 수 있다.
    final uid = state.pendingUid ?? _authService.currentUid;
    final provider = state.pendingProvider ?? '';
    if (uid == null) {
      state = state.copyWith(error: '로그인 정보를 확인할 수 없어요. 다시 로그인해주세요.');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      String? imageUrl;
      if (state.profileImagePath != null) {
        imageUrl = await _storageService.uploadProfileImage(
          File(state.profileImagePath!),
          uid,
        );
      }

      await _authService.createUserProfile(
        uid: uid,
        nickname: state.nickname,
        loginProvider: provider,
        interests: state.interests,
        profileImageUrl: imageUrl,
      );

      state = const AuthState();
      if (context.mounted) context.go('/');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '회원가입에 실패했어요. 다시 시도해주세요.');
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(storageServiceProvider),
  );
});
