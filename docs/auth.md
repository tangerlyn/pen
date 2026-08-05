# 인증 (Auth)

## 개요

소셜 로그인 기반 인증. 신규 유저는 닉네임 → 프로필 사진 → 관심 카테고리 순서로 온보딩 후 앱에 진입한다.

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

**화면 구성**
- "닉네임을 입력해주세요" 제목 + "커뮤니티에서 사용할 이름이에요. 나중에 변경할 수 있어요." 안내
- 닉네임 입력 필드 (최대 12자)
- **중복확인** 버튼 — 탭 시 Firestore 닉네임 중복 검사
  - 사용 가능: 초록색 "사용 가능한 닉네임이에요." 표시
  - 중복: 빨간색 "이미 사용 중인 닉네임이에요." 표시
- **다음** 버튼 — 중복확인 통과 후에만 활성화. 탭 → `/signup/profile`

---

### `signup_profile_screen.dart`
**경로:** `/signup/profile`

**화면 구성**
- "프로필 사진을 설정해주세요" 제목 + "(선택)" 안내
- 프로필 사진 원형 영역 — 탭 시 갤러리에서 이미지 선택 (imageQuality 85%)
  - 이미지 없으면 기본 person 아이콘
  - 선택 시 미리보기 + 우측 하단 카메라 배지 표시
- **다음** 버튼 → `/signup/interests`
- **건너뛰기** 텍스트 버튼 → `/signup/interests` (사진 없이 진행)

---

### `signup_interests_screen.dart`
**경로:** `/signup/interests`

**화면 구성**
- "관심 있는 카테고리를 선택해주세요" 제목 + "복수 선택 가능해요. 나중에 변경할 수 있어요." 안내
- 카테고리 칩 Wrap (멀티 선택 가능)
  - 선택 시 네이비 배경 흰 텍스트 / 미선택 시 회색 칩 배경
  - 애니메이션 150ms 색상 전환
- **시작하기** 버튼 — 탭 시 관심 카테고리 저장 + 유저 프로필 Firestore 생성 → 홈(`/`)으로 이동
  - 처리 중 로딩 스피너 표시

---

## 인증 플로우

```
앱 시작
  └─ 로그인 상태 확인
       ├─ 로그인됨 + 닉네임 있음 → / (홈)
       ├─ 로그인됨 + 닉네임 없음 → /signup/nickname
       └─ 비로그인 → /login
                         └─ 소셜 로그인 성공
                               ├─ 신규 유저 → /signup/nickname → /signup/profile → /signup/interests → /
                               └─ 기존 유저 → /
```

---

## 라우트 가드

`app_router.dart`의 `redirect` 콜백에서 `authStateProvider`와 `currentUserProvider`를 감지.

| 상태 | 동작 |
|---|---|
| 비로그인 상태로 보호된 경로 접근 | `/login` 리다이렉트 |
| 로그인됨 + 닉네임 없음 | `/signup/nickname` 리다이렉트 |
| 로그인됨 + 프로필 완성 후 인증 화면 접근 | `/` 리다이렉트 |

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `authProvider` | StateNotifierProvider | 로그인/회원가입 처리 상태 |
| `authStateProvider` | StreamProvider\<User?\> | Firebase Auth 실시간 인증 상태 |
| `currentUidProvider` | Provider\<String?\> | 현재 로그인 UID |
| `currentUserProvider` | StreamProvider\<UserModel?\> | 현재 유저 Firestore 문서 실시간 |

---

## 관련 파일

- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/signup_nickname_screen.dart`
- `lib/features/auth/screens/signup_profile_screen.dart`
- `lib/features/auth/screens/signup_interests_screen.dart`
- `lib/features/auth/providers/auth_provider.dart`
- `lib/data/repositories/user_repository.dart`
- `lib/shared/providers/providers.dart`
- `lib/core/router/app_router.dart`
