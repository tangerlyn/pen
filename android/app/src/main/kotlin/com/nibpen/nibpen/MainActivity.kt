package com.nibpen.nibpen

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_naver_login이 Custom Tabs 로그인 결과를 registerForActivityResult로
// 받기 위해 FlutterFragmentActivity를 요구함 (FlutterActivity는 캐스팅 실패)
class MainActivity : FlutterFragmentActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 네이버 로그인 리다이렉트가 singleTop으로 돌아올 때 getIntent()가
        // 갱신되도록 함 — 없으면 SDK가 이전 Intent를 읽어 redirect 데이터를 놓침
        setIntent(intent)
    }
}
