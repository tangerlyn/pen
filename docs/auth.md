# 인증 (Auth)

## 개요

소셜 로그인 기반 인증. 신규 유저는 닉네임/프로필 사진/약관동의를 한 화면에서 입력한 뒤, 앱 소개 온보딩(5페이지)을 보고 앱에 진입한다.

---

## 화면 목록

### `login_screen.dart`
**경로:** `/login`

앱 시작 시 비로그인 상태이면 자동 이동. (로그인 되어 있으면 `/`로 진입)

**화면 구성**
- 앱 로고 (네이비 박스 + 편집 아이콘) + "펜귄" + "만년필·잉크·노트 커뮤니티" 문구
- 로그인 로딩 중이면 CircularProgressIndicator
- **카카오로 시작하기** 버튼 (노란 배경) — 탭 시 카카오 OAuth → Firebase 로그인
- **네이버로 시작하기** 버튼 (초록 배경) — 탭 시 네이버 OAuth → Firebase 로그인
- **Apple로 시작하기** 버튼 (검정 배경) — 탭 시 Apple Sign-In → Firebase 로그인
- 로그인 오류 시 화면 중앙 팝업(`showCenterToast`)으로 에러 표시
- 이용약관·개인정보처리방침 동의 안내 문구

**로그인 성공 후 분기**
- 신규 유저(닉네임 미설정) → `/signup/nickname`
- 기존 유저 → `/` (홈)

---

### `signup_nickname_screen.dart`
**경로:** `/signup/nickname`

닉네임·프로필 사진·약관동의를 한 화면에서 처리한다 (예전엔 3개 화면으로 나뉘어 있었으나 통합됨).

**화면 구성**
- "닉네임과 프로필 사진을 설정해주세요" 제목 + 안내 문구
- 프로필 사진 원형 영역 (선택) — 탭 시 갤러리에서 이미지 선택 → `InkCropScreen`(원형 오버레이, 핀치줌/드래그)으로 위치·확대 조정 후 크롭된 정사각 이미지를 프로필 사진으로 사용
- 닉네임 입력 필드 (최대 12자) + **중복확인** 버튼
  - 사용 가능: 초록색 "사용 가능한 닉네임이에요." 표시
  - 중복: 빨간색 "이미 사용 중인 닉네임이에요." 표시
- 약관동의
  - **전체 동의** 토글
  - **[필수] 이용약관 동의** — "보기" 탭 시 `TermsScreen`을 `Navigator.push`로 표시 (go_router가 아님: 프로필 미완성 상태에선 `/signup/*` 밖 경로가 전부 리다이렉트되기 때문)
  - **[필수] 개인정보처리방침 동의** — 위와 동일한 방식으로 `PrivacyScreen` 표시
- **시작하기** 버튼 — 닉네임 중복확인 통과 + 필수 약관 2개 모두 동의해야 활성화. 탭 시 유저 프로필 Firestore 생성 후 `/onboarding`으로 이동
  - 처리 중 로딩 스피너 표시

---

### `onboarding_screen.dart`
**경로:** `/onboarding`

회원가입 완료 직후 1회 노출되는 앱 소개 화면. 기존 유저는 다시 보지 않는다.

**화면 구성**
- 5페이지 `PageView` + 하단 점 인디케이터(`smooth_page_indicator`)
- 1~4페이지: 우측 상단 **건너뛰기** 버튼 → 즉시 홈(`/`)으로 이동, 하단 버튼은 "다음"
- 5페이지: 건너뛰기 버튼 사라지고, 하단 버튼이 **시작하기**로 바뀜 → 탭 시 홈(`/`)으로 이동

---

## 인증 플로우

```
앱 시작
  └─ 로그인 상태 확인
       ├─ 로그인됨 + 닉네임 있음 → / (홈)
       ├─ 로그인됨 + 닉네임 없음 → /signup/nickname
       └─ 비로그인 → /login
                         └─ 소셜 로그인 성공
                               ├─ 신규 유저 → /signup/nickname (닉네임+프사+약관동의) → /onboarding → /
                               └─ 기존 유저 → /
```

---

## 라우트 가드

`app_router.dart`의 `redirect` 콜백에서 `authUserProvider`와 `currentUserProvider`를 감지.

| 상태 | 동작 |
|---|---|
| 비로그인 상태로 보호된 경로 접근 | `/login` 리다이렉트 |
| 로그인됨 + 닉네임 없음 | `/signup/nickname` 리다이렉트 |
| 로그인됨 + 프로필 완성 후 인증 화면 접근 | `/` 리다이렉트 |

`/onboarding`은 `isAuthRoute`(`/login`, `/signup/*`) 판정에 포함되지 않는다 — 프로필이 완성된 상태에서 접근하는 일반 경로이므로 리다이렉트 없이 그대로 렌더링된다.

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `authProvider` | StateNotifierProvider | 로그인/회원가입 처리 상태 |
| `authUserProvider` | StreamProvider\<String?\> | Firebase Auth 실시간 인증 상태(uid) |
| `currentUidProvider` | Provider\<String?\> | 현재 로그인 UID |
| `currentUserProvider` | StreamProvider\<UserModel?\> | 현재 유저 Firestore 문서 실시간 |

---

## 회원탈퇴

`SettingsScreen`(`/mypage/settings`)의 **회원탈퇴** 항목에서 시작. 자세한 내용은 [mypage.md](mypage.md#설정) 참고.

- 클라이언트(`AuthService.deleteAccount`)는 재인증 후 Firebase Auth 계정 삭제만 수행
- 나머지 처리(리뷰/글/댓글/대댓글은 삭제하지 않고 작성자 닉네임만 "알 수 없음"으로 표시, 잉크북/팔로우/알림/스토리지 삭제, 팔로우·좋아요·스크랩 카운트 정합성 유지)는 Cloud Functions `onUserDeleted` 트리거가 Admin 권한으로 서버에서 처리
- 탈퇴한 유저의 프로필을 누르면 `navigateToProfile()`이 "탈퇴한 사용자입니다" 팝업을 표시 (Firestore `users/{uid}` 문서 자체가 삭제되므로, 닉네임 중복확인 쿼리도 더는 이 계정을 찾지 못해 같은 닉네임을 새 유저가 바로 다시 쓸 수 있음)

---

## 관련 파일

- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/signup_nickname_screen.dart`
- `lib/features/auth/screens/onboarding_screen.dart`
- `lib/features/auth/providers/auth_provider.dart`
- `lib/data/services/auth_service.dart`
- `lib/data/repositories/user_repository.dart`
- `lib/shared/providers/providers.dart`
- `lib/core/router/app_router.dart`
- `functions/index.js` (`onUserDeleted`)
