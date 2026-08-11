import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/app_secrets.dart';

const _kAuthSalt = AppSecrets.authSalt;

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

  // ── Kakao ─────────────────────────────────────────────────��──────────
  Future<AuthResult> signInWithKakao() async {
    try {
      debugPrint('[Kakao] 카카오톡 설치 여부 확인 중...');
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        debugPrint('[Kakao] 카카오톡으로 로그인 시도');
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        debugPrint('[Kakao] 카카오 계정으로 로그인 시도');
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }
      debugPrint('[Kakao] 토큰 발급 성공: ${token.accessToken}');

      final kakaoUser = await kakao.UserApi.instance.me();
      debugPrint('[Kakao] 유저 정보 획득 성공: ${kakaoUser.id}');
      final id = kakaoUser.id.toString();

      final email = 'kakao_$id@nibpen.login';
      final password = _hash(id);

      debugPrint('[Kakao] Firebase 인증 시도...');
      final credential = await _firebaseEmailAuth(email, password);
      final uid = credential.user!.uid;
      final isNew = credential.additionalUserInfo?.isNewUser ?? false;

      if (isNew) {
        debugPrint('[Kakao] 신규 유저 문서 생성 중...');
        await _initUserDoc(uid, 'kakao', email);
      }

      final hasProfile = await _checkProfile(uid);
      debugPrint('[Kakao] 로그인 완료 (신규여부: $isNew, 프로필완성: $hasProfile)');

      return AuthResult(
        uid: uid,
        isNewUser: isNew,
        hasProfile: hasProfile,
        provider: 'kakao',
      );
    } catch (e, stack) {
      debugPrint('[Kakao] 에러 발생: $e\n$stack');
      rethrow;
    }
  }

  // ── Naver ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithNaver() async {
    // 이전 세션 초기화
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}

    final result = await FlutterNaverLogin.logIn().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception('네이버 로그인 시간 초과 (20초)'),
    );

    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('네이버 로그인 실패: ${result.errorMessage}');
    }

    final account = result.account;
    if (account == null) throw Exception('네이버 계정 정보를 가져올 수 없습니다.');

    final id = account.id ?? '';
    final naverEmail = account.email ?? '';
    final email = naverEmail.isNotEmpty ? naverEmail : 'naver_$id@nibpen.login';
    final password = _hash(id);

    final credential = await _firebaseEmailAuth(email, password);
    final uid = credential.user!.uid;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;

    if (isNew) await _initUserDoc(uid, 'naver', email);
    final hasProfile = await _checkProfile(uid);

    return AuthResult(
      uid: uid,
      isNewUser: isNew,
      hasProfile: hasProfile,
      provider: 'naver',
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
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'nickname': nickname,
      // loginProvider를 모르는 채로(예: 프로세스 재시작 후 pendingProvider 유실)
      // completeSignup이 호출된 경우, 최초 로그인 때 _initUserDoc이 이미
      // 저장해둔 값을 빈 문자열로 덮어쓰지 않도록 알 때만 기록한다.
      if (loginProvider.isNotEmpty) 'loginProvider': loginProvider,
      'interests': interests,
      'profileImageUrl': profileImageUrl,
      'bio': '',
      'followerCount': 0,
      'followingCount': 0,
      'exp': 0,
      'notificationSettings': {
        'likes': true,
        'comments': true,
        'follows': true,
      },
      'termsAgreedAt': FieldValue.serverTimestamp(),
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
        await _db
            .collection('users')
            .doc(uid)
            .update({'fcmToken': FieldValue.delete()})
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

  // 탈퇴 후처리(리뷰/글/댓글/대댓글 작성자를 "알 수 없음"으로 표시,
  // 잉크북/팔로우/알림/스토리지 정리)는 Cloud Functions의 onUserDeleted
  // 트리거가 Admin 권한으로 서버에서 처리한다 — 콘텐츠 자체는 지우지
  // 않는다. 클라이언트가 먼저 Firestore 데이터를 지우고 마지막에 계정을
  // 삭제하면, 계정 삭제가 (requires-recent-login 등으로) 실패했을 때
  // "로그인은 되는데 데이터는 사라진" 유령 계정 상태가 생길 수 있어
  // 클라이언트는 재인증 후 계정 삭제만 성공시키는 방식으로 바꿨다.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final doc = await _db.collection('users').doc(uid).get();
    final loginProvider = (doc.data()?['loginProvider'] as String?) ?? '';
    await _reauthenticate(loginProvider);

    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    try {
      await kakao.UserApi.instance.unlink();
    } catch (_) {}

    await user.delete();
  }

  // ── 탈퇴 전 재인증 ───────────────────────────────────────────────
  Future<void> _reauthenticate(String provider) async {
    final user = _auth.currentUser;
    if (user == null) return;

    switch (provider) {
      case 'kakao':
        kakao.OAuthToken token;
        if (await kakao.isKakaoTalkInstalled()) {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } else {
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
        debugPrint('[Reauth] 카카오 토큰 갱신: ${token.accessToken}');
        final kakaoUser = await kakao.UserApi.instance.me();
        final id = kakaoUser.id.toString();
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: 'kakao_$id@nibpen.login',
            password: _hash(id),
          ),
        );
        break;

      case 'naver':
        try {
          await FlutterNaverLogin.logOut();
        } catch (_) {}
        final result = await FlutterNaverLogin.logIn().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception('네이버 재인증 시간 초과'),
        );
        if (result.status != NaverLoginStatus.loggedIn) {
          throw Exception('네이버 재인증 실패: ${result.errorMessage}');
        }
        final account = result.account;
        final id = account?.id ?? '';
        final naverEmail = account?.email ?? '';
        final email = naverEmail.isNotEmpty
            ? naverEmail
            : 'naver_$id@nibpen.login';
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: _hash(id)),
        );
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
        break;

      default:
        // loginProvider를 알 수 없으면(예: 유령 계정) 재인증을 생략하고
        // 기존 세션으로 진행 — 실패하면 user.delete()에서 자연스럽게 에러가 난다.
        break;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────
  String _hash(String id) =>
      sha256.convert(utf8.encode(id + _kAuthSalt)).toString().substring(0, 20);

  Future<UserCredential> _firebaseEmailAuth(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  Future<void> _initUserDoc(String uid, String provider, String email) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({
            'uid': uid,
            'email': email,
            'loginProvider': provider,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
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
