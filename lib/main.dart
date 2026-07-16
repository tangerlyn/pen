import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/constants/app_secrets.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';

// 백그라운드 메시지 핸들러 — 반드시 top-level 함수
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: AppSecrets.kakaoNativeAppKey);

  timeago.setLocaleMessages('ko', timeago.KoMessages());

  FlutterNativeSplash.remove();
  runApp(const ProviderScope(child: NibpenApp()));

// // 네이버 SDK 초기화 코드
//   await FlutterNaverLogin.initSDK(
//     clientId: 'Y5EtV_fPw02vQtHSFd_C', // AppSecrets.naverClientId 등
//     clientName: 'nibpen', // 네이버 개발자 센터에 등록한 앱 이름
//     clientSecret: 'YSzIzVbqJk', // AppSecrets.naverClientSecret 등
//   );
 }