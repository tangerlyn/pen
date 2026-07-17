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
import 'storage_service.dart';

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

      return AuthResult(uid: uid, isNewUser: isNew, hasProfile: hasProfile, provider: 'kakao');
    } catch (e, stack) {
      debugPrint('[Kakao] 에러 발생: $e\n$stack');
      rethrow;
    }
  }

  // ── Naver ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithNaver() async {
    // 이전 세션 초기화
    try { await FlutterNaverLogin.logOut(); } catch (_) {}

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

    return AuthResult(uid: uid, isNewUser: isNew, hasProfile: hasProfile, provider: 'naver');
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

    return AuthResult(uid: user.uid, isNewUser: isNew, hasProfile: hasProfile, provider: 'apple');
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
      'notificationSettings': {'likes': true, 'comments': true, 'follows': true},
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
        await _db.collection('users').doc(uid)
            .update({'fcmToken': FieldValue.delete()})
            .timeout(const Duration(seconds: 3));
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    try { await FlutterNaverLogin.logOut(); } catch (_) {}
    try { await kakao.UserApi.instance.logout(); } catch (_) {}
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try { await FlutterNaverLogin.logOut(); } catch (_) {}
    try { await kakao.UserApi.instance.unlink(); } catch (_) {}

    // inkBooks 서브컬렉션 및 각 book의 inkChart 삭제
    try {
      final booksSnap = await _db
          .collection('users').doc(uid).collection('inkBooks').get();
      for (final book in booksSnap.docs) {
        final chartSnap = await book.reference.collection('inkChart').get();
        for (final chart in chartSnap.docs) {
          await chart.reference.delete();
        }
        await book.reference.delete();
      }
    } catch (_) {}

    // users/{uid}/inkChart 서브컬렉션 삭제
    try {
      final inkChartSnap = await _db
          .collection('users').doc(uid).collection('inkChart').get();
      for (final doc in inkChartSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // follows 루트 컬렉션에서 해당 유저 관련 문서 삭제
    try {
      final followingSnap = await _db
          .collection('follows').where('followerId', isEqualTo: uid).get();
      for (final doc in followingSnap.docs) {
        await doc.reference.delete();
      }
      final followerSnap = await _db
          .collection('follows').where('followeeId', isEqualTo: uid).get();
      for (final doc in followerSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}

    // Storage 삭제
    final storage = StorageService();
    await storage.deleteFolder('profiles/$uid');
    await storage.deleteFolder('inkChart/$uid');

    // users 문서 및 Firebase Auth 계정 삭제
    await _db.collection('users').doc(uid).delete();
    await user.delete();
  }

  // ── Private helpers ───────────────────────────────────────────────
  String _hash(String id) =>
      sha256.convert(utf8.encode(id + _kAuthSalt)).toString().substring(0, 20);

  Future<UserCredential> _firebaseEmailAuth(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        return await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }
      rethrow;
    }
  }

  Future<void> _initUserDoc(String uid, String provider, String email) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'loginProvider': provider,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
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
