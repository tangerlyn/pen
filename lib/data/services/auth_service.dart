import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'private_account_store.dart';

class AuthResult {
  const AuthResult({
    required this.uid,
    required this.isNewUser,
    required this.hasProfile,
    required this.provider,
  });
  final String uid;
  final bool isNewUser;
  final bool hasProfile;
  final String provider;
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  // ── Kakao / Naver ───────────────────────────────────────────────────
  // 카카오·네이버가 발급한 액세스 토큰을 서버(functions/social_login.js)에
  // 보내면, 서버가 그 토큰으로 사용자 ID를 직접 확인한 뒤 Firebase 커스텀
  // 토큰을 돌려준다. (예전처럼 앱에서 소셜 ID로 비밀번호를 만들면, 앱에 든
  // salt를 꺼낸 사람이 남의 계정으로 로그인할 수 있었다.)
  Future<AuthResult> signInWithKakao() async {
    try {
      final accessToken = await _kakaoAccessToken();
      return await _signInWithSocialToken('kakao', accessToken);
    } catch (e, stack) {
      debugPrint('[Kakao] 에러 발생: $e\n$stack');
      rethrow;
    }
  }

  Future<AuthResult> signInWithNaver() async {
    final accessToken = await _naverAccessToken();
    return _signInWithSocialToken('naver', accessToken);
  }

  Future<String> _kakaoAccessToken() async {
    if (!await kakao.isKakaoTalkInstalled()) {
      return (await kakao.UserApi.instance.loginWithKakaoAccount()).accessToken;
    }
    try {
      return (await kakao.UserApi.instance.loginWithKakaoTalk()).accessToken;
    } catch (e) {
      // 사용자가 직접 취소한 경우는 그대로 전달하고, 그 외(카카오톡 미로그인,
      // 앱 연동 오류 등)는 카카오계정 웹 로그인으로 한 번 더 시도한다.
      if (e is PlatformException && e.code == 'CANCELED') rethrow;
      return (await kakao.UserApi.instance.loginWithKakaoAccount()).accessToken;
    }
  }

  Future<String> _naverAccessToken() async {
    // 이전 세션 초기화
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}

    // 네이버 앱이 없으면 웹 로그인 화면에서 아이디·비밀번호를 직접 입력해야
    // 해서 20초로는 부족했다. SDK가 응답 없이 멈추는 경우만 막도록 넉넉히 둔다.
    final result = await FlutterNaverLogin.logIn().timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw Exception('네이버 로그인 시간 초과 (3분)'),
    );
    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인 실패: ${result.errorMessage}');
    }
    final token = await FlutterNaverLogin.getCurrentAccessToken();
    if (token.accessToken.isEmpty) {
      throw Exception('네이버 액세스 토큰을 가져올 수 없습니다.');
    }
    return token.accessToken;
  }

  /// 서버 검증 후 받은 커스텀 토큰으로 로그인. 기존 회원은 서버가 예전 uid를
  /// 찾아주므로 같은 계정으로 들어온다.
  Future<({UserCredential credential, String email})> _exchangeSocialToken(
    String provider,
    String accessToken,
  ) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('socialLogin')
        .call<Map<String, dynamic>>({
      'provider': provider,
      'accessToken': accessToken,
    });
    final credential =
        await _auth.signInWithCustomToken(res.data['token'] as String);
    return (credential: credential, email: (res.data['email'] as String?) ?? '');
  }

  Future<AuthResult> _signInWithSocialToken(
    String provider,
    String accessToken,
  ) async {
    final (:credential, :email) =
        await _exchangeSocialToken(provider, accessToken);
    final uid = credential.user!.uid;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;

    if (isNew) await _initUserDoc(uid, provider, email);
    final hasProfile = await _checkProfile(uid);

    return AuthResult(
      uid: uid,
      isNewUser: isNew,
      hasProfile: hasProfile,
      provider: provider,
    );
  }

  // ── Apple ─────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final credential = await _auth.signInWithCredential(oauthCredential);
    final user = credential.user!;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;

    if (isNew) {
      await _initUserDoc(user.uid, 'apple', user.email ?? '');
    }
    final hasProfile = await _checkProfile(user.uid);

    return AuthResult(
      uid: user.uid,
      isNewUser: isNew,
      hasProfile: hasProfile,
      provider: 'apple',
    );
  }

  // ── 회원가입 완료 (닉네임·프로필 저장) ─────────────────────────────
  Future<void> createUserProfile({
    required String uid,
    required String nickname,
    required String loginProvider,
    required List<String> interests,
    String? profileImageUrl,
  }) async {
    final ref = _db.collection('users').doc(uid);
    // 닉네임이 비어 있던 기존 회원이 가입 화면을 다시 거치는 경우에도
    // 팔로워 수·경험치·가입일이 0으로 초기화되지 않도록, 없는 필드만 채운다.
    final existing = (await ref.get()).data() ?? const <String, dynamic>{};
    await ref.set({
      'uid': uid,
      'nickname': nickname,
      // loginProvider를 모르는 채로(예: 프로세스 재시작 후 pendingProvider 유실)
      // completeSignup이 호출된 경우, 최초 로그인 때 _initUserDoc이 이미
      // 저장해둔 값을 빈 문자열로 덮어쓰지 않도록 알 때만 기록한다.
      if (loginProvider.isNotEmpty) 'loginProvider': loginProvider,
      'interests': interests,
      'profileImageUrl': profileImageUrl,
      if (!existing.containsKey('bio')) 'bio': '',
      if (!existing.containsKey('followerCount')) 'followerCount': 0,
      if (!existing.containsKey('followingCount')) 'followingCount': 0,
      if (!existing.containsKey('exp')) 'exp': 0,
      if (!existing.containsKey('notificationSettings'))
        'notificationSettings': {
          'likes': true,
          'comments': true,
          'follows': true,
        },
      'termsAgreedAt': FieldValue.serverTimestamp(),
      // 가입 화면에서 "[필수] 만 14세 이상입니다"를 체크해야만 여기까지 온다
      'ageConfirmedAt': FieldValue.serverTimestamp(),
      if (!existing.containsKey('createdAt'))
        'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── 닉네임 중복 확인 ──────────────────────────────────────────────
  Future<bool> isNicknameAvailable(String nickname) async {
    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  // ── 로그아웃 ─────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await PrivateAccountStore(_db)
            .deleteFcmToken(uid)
            .timeout(const Duration(seconds: 3));
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {}
    await _auth.signOut();
  }

  // 탈퇴 후처리(작성한 리뷰/글/댓글/대댓글 삭제 — 남의 답글이 달린 댓글은
  // 내용만 비워 '삭제된 댓글'로 남김 — 와 잉크북/팔로우/알림/스토리지 정리)는
  // Cloud Functions의 onUserDeleted 트리거가 Admin 권한으로 서버에서 처리한다. 클라이언트가 먼저 Firestore 데이터를 지우고 마지막에 계정을
  // 삭제하면, 계정 삭제가 (requires-recent-login 등으로) 실패했을 때
  // "로그인은 되는데 데이터는 사라진" 유령 계정 상태가 생길 수 있어
  // 클라이언트는 재인증 후 계정 삭제만 성공시키는 방식으로 바꿨다.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final doc = await _db.collection('users').doc(uid).get();
    final loginProvider = (doc.data()?['loginProvider'] as String?) ?? '';
    final appleAuthCode = await _reauthenticate(loginProvider);

    // App Store 심사 지침 5.1.1(v): Apple로 가입한 계정을 지울 때는 Apple
    // 토큰도 함께 폐기해야 한다. 실패해도 탈퇴 자체는 막지 않는다.
    if (appleAuthCode != null && appleAuthCode.isNotEmpty) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthCode);
      } catch (e) {
        debugPrint('[Auth] Apple token revoke failed: $e');
      }
    }

    // 소셜 연결 해제는 best-effort — 실패해도 계정 삭제는 진행한다
    if (loginProvider == 'naver') {
      try {
        await FlutterNaverLogin.logOutAndDeleteToken();
      } catch (e) {
        debugPrint('[Auth] Naver token delete failed: $e');
      }
    } else if (loginProvider == 'kakao') {
      try {
        await kakao.UserApi.instance.unlink();
      } catch (e) {
        debugPrint('[Auth] Kakao unlink failed: $e');
      }
    }

    // 카카오·네이버는 재인증 때 다시 로그인하므로 그 이후의 currentUser를 지운다
    await _auth.currentUser!.delete();
  }

  // ── 탈퇴 전 재인증 ───────────────────────────────────────────────
  /// Apple 계정이면 토큰 폐기에 쓸 새 authorizationCode를 돌려준다.
  Future<String?> _reauthenticate(String provider) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    switch (provider) {
      case 'kakao':
      case 'naver':
        // 커스텀 토큰 계정은 reauthenticateWithCredential을 쓸 수 없다 —
        // 같은 계정으로 다시 로그인하면 최근 로그인 시각이 갱신된다.
        final accessToken = provider == 'kakao'
            ? await _kakaoAccessToken()
            : await _naverAccessToken();
        final (:credential, email: _) =
            await _exchangeSocialToken(provider, accessToken);
        // 다른 소셜 계정으로 재인증했다면 그 계정을 지우면 안 된다
        if (credential.user?.uid != user.uid) {
          await _auth.signOut();
          throw Exception('로그인한 계정과 다른 계정으로 인증했어요. 다시 로그인해 주세요.');
        }
        break;

      case 'apple':
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        await user.reauthenticateWithCredential(
          OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          ),
        );
        return appleCredential.authorizationCode;

      default:
        // loginProvider를 알 수 없으면(예: 유령 계정) 재인증을 생략하고
        // 기존 세션으로 진행 — 실패하면 user.delete()에서 자연스럽게 에러가 난다.
        break;
    }
    return null;
  }

  // ── Private helpers ───────────────────────────────────────────────
  Future<void> _initUserDoc(String uid, String provider, String email) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({
            'uid': uid,
            'loginProvider': provider,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
      // 이메일은 공개 users 문서가 아니라 본인만 읽는 private 문서에 둔다
      if (email.isNotEmpty) {
        await PrivateAccountStore(_db)
            .saveEmail(uid, email)
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('[Auth] Initial user doc failed: $e');
    }
  }

  Future<bool> _checkProfile(String uid) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final data = doc.data();
      return doc.exists && (data?['nickname'] ?? '').toString().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
