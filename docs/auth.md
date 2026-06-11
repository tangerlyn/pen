# 인증 (Auth)

## 개요

소셜 로그인 기반 회원가입·로그인 플로우. 신규 유저는 닉네임 → 프로필 → 관심 분야 3단계를 거쳐 가입 완료.

---

## 화면 목록

### `login_screen.dart`
- 경로: `/login`
- 카카오 / 네이버 / Apple 소셜 로그인 버튼
- 로그인 성공 시 Firestore 유저 문서 유무 확인 → 신규면 회원가입 플로우로 리다이렉트

### `signup_nickname_screen.dart`
- 경로: `/signup/nickname`
- 닉네임 입력 + 중복 확인 (실시간 Firestore 조회)
- 유효성: 2~12자, 특수문자 불가

### `signup_profile_screen.dart`
- 경로: `/signup/profile`
- 프로필 사진 선택 (갤러리 / 기본 아바타)
- 한 줄 소개 입력

### `signup_interests_screen.dart`
- 경로: `/signup/interests`
- 관심 제품 카테고리 선택 (잉크 / 만년필 / 종이 등)
- 완료 후 홈으로 이동

---

## 라우트 가드

`RouterNotifier` (go_router)가 `authUserProvider` + `currentUserProvider` 스트림을 감지.

| 상태 | 동작 |
|---|---|
| 비로그인 | `/login` 리다이렉트 |
| 로그인 + 프로필 미완성 | `/signup/nickname` 리다이렉트 |
| 로그인 + 프로필 완성 | 인증 화면 접근 차단 → `/` 리다이렉트 |

---

## 관련 파일

- `lib/data/services/auth_service.dart` — Firebase Auth + 소셜 로그인 로직
- `lib/data/repositories/user_repository.dart` — 유저 문서 생성·조회
- `lib/shared/providers/providers.dart` — `authUserProvider`, `currentUserProvider`
