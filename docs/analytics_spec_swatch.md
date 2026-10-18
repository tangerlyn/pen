# 로그 명세 — 스와치 기록 퍼널 (Analytics)

## 개요

스와치 기록 화면(`/record/new`)에서 사용자가 **진입 → 사진 선택 → 잉크 매칭 → 저장**까지 가는 과정을 기록한다. 네이밍·GA4 제약·수집 금지 원칙은 리뷰 퍼널 명세(`docs/analytics_spec.md`의 "공통 규칙")를 그대로 따르고, 접두어만 `swatch_`를 쓴다.

**이 로그로 답하려는 질문**
- 기록 화면에 들어온 사람 중 몇 %가 저장까지 가는가, 사진과 잉크 매칭 중 어디서 더 많이 이탈하는가
- 진입 경로(기록 홈 / 빈 화면 안내 / 아카이브 잉크 상세)에 따라 저장률이 다른가
- 잉크를 아카이브에서 찾는 비율과 직접 입력·새 잉크 요청 비율 (아카이브 DB 커버리지)
- 선택 입력(펜·닙·종이·메모·날짜)을 얼마나 채우는가

**정답 데이터**: Firestore `users/{uid}/inkBooks/{bookId}/inkChart/{chartId}` 문서 생성

**범위**: 새 기록(`mode=new`)과 기록 상세에서 들어가는 수정(`mode=edit`). 마이페이지 공책 화면의 기존 추가·수정 화면은 로그 대상이 아니다.

---

## 용어 정의

| 용어 | 정의 |
|---|---|
| 기록 세션 | 기록 화면 진입부터 저장 성공 또는 이탈까지. `record_session_id`(UUID v4)로 식별 |
| 사진 선택 | 촬영·갤러리 선택 후 **크롭 화면에서 완료까지 누른 시점**. 크롭에서 취소하면 선택으로 보지 않음 |
| 잉크 매칭 | 잉크 이름이 확정된 시점: 아카이브 결과 선택, 새 잉크 요청 제출, 직접 입력 확정, 또는 잉크 상세에서 들어와 미리 채워진 경우 |
| 저장 성공 | Firestore `addEntry` / `updateEntry`가 **완료된 시점** |

---

## 공통 파라미터 (모든 이벤트)

| 파라미터 | 타입 | 값 | 설명 |
|---|---|---|---|
| `record_session_id` | string | UUID v4 | 화면 `initState`에서 발급 |
| `mode` | string | `new` / `edit` | |
| `entry_point` | string | `home` / `empty_state` / `ink_detail` / `record_detail` / `unknown` | 라우트 쿼리 `entry`. 명세에 없는 값은 `unknown` |

---

## 이벤트 명세

### `swatch_record_start`
- **발생 시점**: 기록 화면 진입 (`initState`). 세션당 정확히 1회

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `has_preset_ink` | int | 아카이브 잉크가 미리 채워졌는지 (0/1) |

### `swatch_photo_select`
- **발생 시점**: 크롭 완료 직후. 사진을 바꿀 때마다 기록

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `source` | string | `camera` / `gallery` |
| `crop_shape` | string | `InkSwatchShape.name` (예: `circle`, `bottle`) |
| `is_replace` | int | 이미 사진이 있던 상태에서 바꾼 것인지 (0/1) |

### `swatch_ink_match`
- **발생 시점**: 잉크 이름이 확정될 때. 다시 고르면 다시 기록

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `match_type` | string | `archive`(검색 결과 선택) / `preset`(잉크 상세에서 진입) / `request`(새 잉크 요청) / `free_text`(요청 없이 이름만) |
| `query_len` | int | 확정 시점의 검색어 길이. `preset`이면 0 |
| `filter_count` | int | 적용된 색 계열 + 브랜드 필터 개수 |

### `swatch_save_success`
- **발생 시점**: Firestore 쓰기 완료 직후, 성공 오버레이·화면 이동 이전. 세션 종료

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `record_id` | string | 스와치 문서 ID (정합성 조인 키) |
| `has_ink_id` | int | 아카이브 잉크와 연결됐는지 (0/1) |
| `optional_field_count` | int | 채운 선택 항목 수 (브랜드·펜·닙·종이·메모·날짜, 0~6) |
| `created_book` | int | 이 저장으로 기본 공책을 새로 만들었는지 (0/1) |
| `elapsed_ms` | int | 진입부터 저장 성공까지 |

### `swatch_save_fail`
- **발생 시점**: 저장 중 예외. 재시도 가능하므로 세션은 끝나지 않음

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `error_stage` | string | `photo_upload` / `book_create` / `firestore_write` |
| `error_type` | string | Firebase 예외면 에러 코드, 아니면 타입명 (100자 이하) |

### `swatch_record_exit`
- **발생 시점**: 저장 성공 없이 화면을 떠남 (나가기 확정 시점). 세션 종료

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `last_stage` | string | 가장 깊이 도달한 단계: `start` / `photo_selected` / `ink_matched` / `save_failed` |
| `had_content` | int | 입력 내용이 있었는지 (0/1) |
| `since_start_ms` | int | 진입부터 이탈까지 |

`last_stage`는 사진과 잉크를 **둘 다** 채우면 `ink_matched` 이상으로 본다. 잉크만 채우고 사진이 없으면 `start`로 남긴다 (필수 입력 기준의 진행도).

---

## 기대 이벤트 시퀀스

```
swatch_record_start
   ├─ (preset이면) swatch_ink_match(match_type=preset)
   ├─ swatch_photo_select / swatch_ink_match (0회 이상, 순서 자유)
   ├─ swatch_save_fail → (다시 저장 또는 이탈)
   ├─ swatch_save_success  [세션 종료]
   └─ swatch_record_exit   [세션 종료]
```

**불변 조건**
- 한 세션에 `start`는 정확히 1개, 모든 이벤트보다 먼저
- `mode=new`의 `success`가 있으면 같은 세션에 `photo_select`와 `ink_match`가 모두 있다 (필수 입력)
- `success`와 `exit`는 한 세션에 동시에 존재할 수 없고, 세션 종료 후에는 이벤트가 없다

저장 버튼은 필수 입력(사진·잉크 이름)이 채워지기 전까지 비활성이므로 리뷰 퍼널의 `blocked`에 해당하는 이벤트는 없다.

---

## 진입 경로

| 진입 경로 | 위치 | 라우트 |
|---|---|---|
| 기록 홈 FAB | `features/record/screens/record_home_screen.dart` | `/record/new?entry=home` |
| 기록 홈 빈 화면 버튼 | `features/record/widgets/record_empty_state.dart` | `/record/new?entry=empty_state` |
| 아카이브 잉크 상세 | `features/archive/widgets/archive_detail_content.dart` | `/record/new?inkId=..&entry=ink_detail` |
| 기록 상세 → 수정 | `features/record/screens/swatch_record_detail_screen.dart` | `mode=edit`, `entry=record_detail` |

리뷰 퍼널 명세의 `entry_point`에도 `discover`(디스커버리 화면 FAB)를 추가한다.

---

## 수집 금지
- 잉크 이름·메모·펜·종이 텍스트, 사진 URL → 길이·개수·유무만 기록
- 스와치 문서 ID·아카이브 잉크 ID는 기록 가능 (개인정보 아님)

---

## QA 시나리오

| # | 시나리오 | 기대 이벤트 (공통 파라미터 생략) |
|---|---|---|
| W1 | 기록 홈 FAB → 갤러리 사진 → 크롭 완료 → 검색해서 잉크 선택 → 저장 | start(0), photo_select(gallery, is_replace=0), ink_match(archive), success(has_ink_id=1) |
| W2 | 공책이 하나도 없는 계정, 빈 화면 버튼 → 카메라 → 이름만 직접 입력 → 저장 | start(empty_state), photo_select(camera), ink_match(free_text), success(has_ink_id=0, created_book=1) |
| W3 | 잉크 상세 "스와치 기록하기" → 사진 → 저장 | start(has_preset_ink=1), ink_match(preset), photo_select, success |
| W4 | 사진 선택 → 크롭에서 취소 → 뒤로가기 → 나가기 | start, exit(last_stage=start, had_content=0) — photo_select 없음 |
| W5 | 사진+잉크 입력 후 비행기 모드에서 저장 | save_fail(photo_upload) |
| W6 | 아카이브에 없는 잉크 → 새 잉크 요청 → 저장 | ink_match(request), success(has_ink_id=0). Firestore `inkRequests`에 문서 1개 |

---

## 변경 이력

| 날짜 | 내용 |
|---|---|
| 2026-10-18 | 초안 작성 |
