# 로그 명세 — 리뷰 작성 퍼널 (Analytics)

## 개요

리뷰 작성 화면(`/write/review`)에서 사용자가 **진입 → 작성 시작 → 사진 첨부 → 등록**까지 가는 과정을 Firebase Analytics 이벤트로 기록하기 위한 명세. 출시 전 단계이므로 1차 목적은 사용자 분석이 아니라 **로그가 실제 행동을 정확히 기록하는지 검증할 수 있는 구조를 만드는 것**이다.

**이 로그로 답하려는 질문**
- 리뷰 작성 화면에 들어온 사람 중 몇 %가 실제로 등록까지 가는가, 어느 단계에서 가장 많이 이탈하는가
- 진입 경로(홈 / 리뷰 피드 / 제품 상세)에 따라 등록률이 다른가
- "사진 1장 이상 필수" 규칙 때문에 막히는 비율은 얼마인가
- 등록 실패는 어느 단계(이미지 업로드 / Firestore 쓰기 / 후처리)에서 주로 발생하는가

**정답 데이터(ground truth)**
- 서버의 진실: Firestore `reviews` 컬렉션 (등록 성공 여부·사진 수)
- 행동의 진실: QA 시나리오 수행 기록 (아래 "QA 시나리오" 참고)

**범위**: 리뷰 작성·수정 화면 한정. 리뷰 상세·피드 노출/클릭은 다음 단계에서 다룬다.

---

## 용어 정의

| 용어 | 정의 | 비고 |
|---|---|---|
| 작성 세션 | 작성 화면 진입부터 이탈 또는 등록 성공까지의 한 번의 시도. `write_session_id`(UUID v4)로 식별 | GA4 `ga_session_id`는 앱 세션 단위라 한 세션에 리뷰를 두 번 쓰면 구분 불가 → 별도 ID 필요 |
| 작성 시작 | 세션 내 **첫 사용자 입력**이 발생한 시점. 제목 1글자, 본문 1글자, 제품 태그 수동 추가, 사진 삽입 중 가장 먼저 일어난 것 | 화면 진입 ≠ 작성 시작. 제품 상세 진입 시 **자동 태깅은 입력으로 보지 않음** |
| 등록 시도 | 저장 버튼 탭 | 검증 실패·업로드 실패도 포함 |
| 등록 성공 | Firestore `createReview` / `updateReview`가 **완료된 시점** | 버튼 탭 시점이 아님. EXP 지급·화면 이동 이전 |
| 퍼널 | 같은 `write_session_id` 안에서 각 단계에 **도달했는지 여부** | 순서 기반이 아님. 사진을 제목보다 먼저 넣을 수 있기 때문. `mode=edit`는 퍼널에서 제외 |

---

## 공통 규칙

**네이밍**
- 이벤트명: `review_` 접두어 + `snake_case`, 동사는 과거형이 아닌 명사/동사 원형 (`review_submit_success`)
- 파라미터명: `snake_case`, 단위가 있으면 접미어로 표시 (`_ms`, `_len`, `_count`)
- GA4 제약: 이벤트명 40자 이하, 이벤트당 파라미터 25개 이하, 문자열 값 100자 이하, `firebase_` / `google_` / `ga_` 접두어 금지
- bool은 GA4가 지원하지 않으므로 `0/1` 정수로 기록

**공통 파라미터 (모든 이벤트)**

| 파라미터 | 타입 | 값 | 설명 |
|---|---|---|---|
| `write_session_id` | string | UUID v4 | 작성 세션 식별자. 화면 `initState`에서 발급 |
| `mode` | string | `new` / `edit` | `reviewToEdit != null`이면 `edit` |
| `entry_point` | string | `home` / `review_feed` / `product_detail` / `review_detail` | 진입 경로 (아래 "진입 경로 식별" 참고) |

**사용자 속성**

| 속성 | 값 | 설명 |
|---|---|---|
| `build_env` | `debug` / `testflight` / `prod` | 테스트 데이터 분리용. 모든 검증 쿼리는 이 값으로 필터 |

앱 버전·OS·기기 정보는 GA4가 자동 수집하므로 별도로 넣지 않는다 (BigQuery `app_info.version`, `platform`, `device.*`).

**수집 금지**
- 제목·본문 텍스트 내용, 이미지 URL, 닉네임 → 길이·개수만 기록
- 리뷰 ID와 제품 ID는 개인정보가 아니므로 기록 (정합성 검증의 조인 키)

---

## 이벤트 명세

### `review_write_view`
- **발생 시점**: 작성 화면 진입 (`ReviewWriteScreen.initState`)
- **횟수**: 세션당 1회

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `prefilled_product_type` | string | 제품 상세 진입 시 자동 태깅된 타입 `ink` / `pen`, 없으면 `none` |

### `review_write_start`
- **발생 시점**: 세션 내 첫 사용자 입력 (용어 정의 참고)
- **횟수**: 세션당 최대 1회 (트래커가 플래그로 중복 방지)

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `first_input` | string | `title` / `body` / `tag` / `photo` |
| `since_view_ms` | int | 화면 진입 후 첫 입력까지 걸린 시간 |

### `review_photo_add`
- **발생 시점**: 사진 블록 삽입 직후 (`BlogBodyEditor._insertImages`)
- **횟수**: 삽입 동작 1회당 1회. 갤러리에서 여러 장을 한 번에 고르면 **이벤트 1개 + `added_count`** 로 기록 (장당 1개 아님)

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `source` | string | `camera` / `gallery` |
| `added_count` | int | 이번에 추가된 장수 |
| `photo_count_after` | int | 추가 후 본문 전체 사진 수 (수정 모드의 기존 사진 포함) |

### `review_photo_remove`
- **발생 시점**: 사진 블록 ✕ 삭제 직후 (`BlogBodyEditor._removeBlock`)
- **횟수**: 삭제 1회당 1회

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `photo_count_after` | int | 삭제 후 본문 전체 사진 수 |

### `review_submit_attempt`
- **발생 시점**: 저장 버튼 탭, 검증 전 (`_submit` 진입 직후)
- **횟수**: 탭할 때마다

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `attempt_no` | int | 세션 내 몇 번째 시도인지 (1부터) |
| `photo_count` | int | 본문 사진 수 |
| `title_len` | int | 제목 글자 수 |
| `body_len` | int | 본문 텍스트 글자 수 |
| `ink_tag_count` | int | 잉크 태그 수 |
| `pen_tag_count` | int | 만년필 태그 수 |

### `review_submit_blocked`
- **발생 시점**: 클라이언트 검증에 막혀 업로드를 시작하지 않음
- **횟수**: 막힐 때마다

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `attempt_no` | int | 대응되는 시도 번호 |
| `reason` | string | `no_photo` (현재 유일한 검증 규칙) |

### `review_submit_fail`
- **발생 시점**: 업로드·저장 중 예외
- **횟수**: 실패할 때마다

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `attempt_no` | int | 대응되는 시도 번호 |
| `error_stage` | string | `image_upload` / `auth` / `firestore_write` |
| `error_type` | string | 예외 클래스명 또는 Firebase 에러 코드 (100자 이내로 자름) |
| `elapsed_ms` | int | 시도부터 실패까지 걸린 시간 |

### `review_submit_success`
- **발생 시점**: `createReview` / `updateReview` await 완료 **직후**, EXP 지급(`addExpAndCheck`) **이전** (`submitWithBlocks`의 `onCommitted` 콜백)
- **횟수**: 세션당 최대 1회

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `review_id` | string | Firestore 문서 ID. **Firestore와의 조인 키** |
| `attempt_no` | int | 성공한 시도 번호 |
| `photo_count` | int | 저장된 `imageUrls` 길이 |
| `elapsed_ms` | int | 시도부터 성공까지 걸린 시간 (이미지 업로드 포함) |

### `review_write_exit`
- **발생 시점**: 등록 성공 없이 화면을 떠남 (`PopScope`에서 나가기가 확정된 순간)
- **횟수**: 세션당 최대 1회. 나가기 확인 다이얼로그에서 취소하면 기록하지 않음

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `last_stage` | string | 이탈 직전 도달한 가장 깊은 단계: `view` / `started` / `photo_added` / `attempted` |
| `had_content` | int | 입력 내용이 있었는지 (0/1) — `_hasContent()` 결과 |
| `since_view_ms` | int | 진입부터 이탈까지 걸린 시간 |

> 앱 강제 종료·크래시로 인한 이탈은 `exit`가 남지 않는다. 이는 의도된 한계이며, "`view`는 있는데 `success`도 `exit`도 없는 세션" 비율로 별도 추적한다 (DQ-10).

---

## 기대 이벤트 시퀀스

```
review_write_view
   ├─(첫 입력)→ review_write_start
   │              ├─ review_photo_add / review_photo_remove (0회 이상, 순서 자유)
   │              └─ review_submit_attempt
   │                   ├─ review_submit_blocked → (다시 작성)
   │                   ├─ review_submit_fail    → (다시 시도 또는 이탈)
   │                   └─ review_submit_success  [세션 종료]
   └─ review_write_exit  [세션 종료, 어느 단계에서든]
```

**불변 조건** (이게 깨지면 로그 버그)
- 한 세션에 `view`는 정확히 1개
- `start`가 있으면 그보다 먼저 `view`가 있다
- `success`가 있으면 같은 세션에 `view`·`start`·`attempt`가 모두 있다 (`mode=new` 기준)
- `success`와 `exit`는 한 세션에 동시에 존재할 수 없다
- 각 `attempt`는 `blocked` / `fail` / `success` 중 정확히 하나로 끝난다 (강제 종료 제외)

---

## 진입 경로 식별

현재 홈과 리뷰 피드는 모두 `/write/review`로 똑같이 이동해서 구분이 안 된다. 라우트에 `entry` 쿼리 파라미터를 추가한다.

| 진입 경로 | 코드 위치 | 변경 후 |
|---|---|---|
| 홈 FAB 바텀시트 | `lib/features/home/screens/home_screen.dart:78` | `/write/review?entry=home` |
| 리뷰 피드 FAB | `lib/features/review/screens/review_feed_screen.dart:299` | `/write/review?entry=review_feed` |
| 제품 상세 | `lib/features/archive/widgets/archive_detail_content.dart:41` | `...&entry=product_detail` |
| 리뷰 상세 → 수정 | `lib/features/home/screens/review_detail_screen.dart:475` (`Navigator.push`) | 라우터를 거치지 않으므로 `reviewToEdit != null`이면 `review_detail` |

`entry` 값이 없거나 알 수 없는 값이면 `unknown`으로 기록한다. `unknown`이 쌓이면 새 진입점이 생겼는데 명세에 반영이 안 된 것이다 (DQ-11).

---

## Firestore와의 정합성 기준

| 비교 항목 | Analytics | Firestore | 조인 키 |
|---|---|---|---|
| 등록 건수 | `review_submit_success` (`mode=new`) | `reviews` 문서 생성 | `review_id` = 문서 ID |
| 사진 수 | `success.photo_count` | `imageUrls` 길이 | `review_id` |
| 등록 시각 | `event_timestamp` (UTC, 기기 시계) | `createdAt` (기기 시계, `DateTime.now()`) | — |

**차이가 정상적으로 생길 수 있는 원인** (이 외의 차이는 버그로 본다)
- `success` 로그 이벤트가 업로드되기 전에 앱이 종료되어 Analytics 쪽에서 지연되거나 빠짐
- Analytics는 이벤트를 모아서 보내므로 수집 지연이 있음 → 날짜 경계 근처 건수는 하루 밀릴 수 있음
- `build_env` 필터와 Firestore의 테스트 계정 문서가 일치하지 않음

---

## 검증 규칙

모든 규칙은 `build_env` 필터 적용 후 실행한다. 규칙 ID는 SQL 파일명·대시보드와 일치시킨다.

| ID | 품질 차원 | 규칙 (위반 조건) |
|---|---|---|
| DQ-01 | 유일성 | 한 세션에 `view`가 2개 이상 |
| DQ-02 | 완전성 | `success`가 있는데 같은 세션에 `view`가 없음 |
| DQ-03 | 완전성 | `success`가 있는데 같은 세션에 `start`가 없음 (`mode=new`) |
| DQ-04 | 유일성 | 한 `review_id`에 `success`가 2개 이상 |
| DQ-05 | 일관성 | 한 세션에 `success`와 `exit`가 함께 있음 |
| DQ-06 | 일관성 | 이벤트 순서 역전 (`start`가 `view`보다 앞섬 등) |
| DQ-07 | 정확성 | `success.photo_count` ≠ Firestore `imageUrls` 길이 |
| DQ-08 | 정확성 | `success.photo_count` ≠ 같은 `attempt_no`의 `attempt.photo_count` |
| DQ-09 | 정확성 | (`mode=new`) Σ`photo_add.added_count` − `photo_remove` 횟수 ≠ 마지막 `attempt.photo_count` |
| DQ-10 | 완전성 | `attempt` 뒤에 `blocked`/`fail`/`success` 중 아무것도 없음 — 0이 목표가 아니라 **비율을 추적** |
| DQ-11 | 유효성 | `entry_point = unknown` 또는 명세에 없는 파라미터 값 |
| DQ-12 | 정합성 | Firestore에 생성된 리뷰인데 `success` 로그가 없음 (로그 유실) |
| DQ-13 | 정합성 | `success` 로그가 있는데 Firestore에 문서가 없음 (유령 성공) |
| DQ-14 | 적시성 | 이벤트 발생부터 서버 수집까지의 지연 분포 (`event_server_timestamp_offset` 등) |

---

## QA 시나리오 (정답지)

각 시나리오를 실행할 때 시작 시각·기기·OS를 기록해두고, 수집된 로그와 아래 기대값을 대조한다. iOS·Android에서 각각 수행한다.

| # | 시나리오 | 기대 이벤트 (공통 파라미터 생략) |
|---|---|---|
| S1 | 리뷰 피드 FAB → 제목 입력 → 갤러리 2장 → 등록 | view(review_feed), start(title), photo_add(gallery, 2, 2), attempt(1), success(photo_count=2) |
| S2 | 홈 → 제목만 입력 → 등록 → 사진 1장 추가 → 다시 등록 | view(home), start(title), attempt(1), blocked(1, no_photo), photo_add, attempt(2), success(attempt_no=2) |
| S3 | 잉크 상세 → 아무것도 안 하고 뒤로가기 → 나가기 확인 | view(product_detail, prefilled=ink), exit(view, had_content=1) — 자동 태깅 때문에 `had_content`는 1, `start`는 없음 |
| S4 | 사진부터 추가 → 카메라 1장 + 갤러리 2장 → 1장 삭제 → 등록 | start(photo), photo_add×2, photo_remove(2), attempt(photo_count=2), success(photo_count=2) |
| S5 | 제목 입력 후 뒤로가기 → 다이얼로그 취소 → 다시 뒤로가기 → 나가기 | exit 1개만 (취소 시점에는 없음), last_stage=started |
| S6 | 비행기 모드에서 등록 | attempt → fail(image_upload) |
| S7 | 등록 버튼 누르고 업로드 중 앱 강제 종료 | attempt만 남거나 아무것도 안 남을 수 있음. Firestore 문서 생성 여부를 함께 확인 |
| S8 | 저장 버튼 빠르게 연타 | attempt는 여러 개일 수 있으나 success와 Firestore 문서는 각 1개 |
| S9 | 리뷰 상세 → 수정 → 사진 1장 추가 → 저장 | view(review_detail, mode=edit), start(photo), photo_add(photo_count_after=기존+1), success |

---

## 코드 확인 중 발견한 리스크

명세를 쓰면서 현재 코드에서 로그 정합성에 영향을 줄 수 있는 지점을 확인했다. 구현 시 반드시 반영하거나 결정한다.

1. ~~**등록 성공 후 EXP 지급이 실패하면 사용자에게 에러가 보임**~~ (2026-10-12 수정) — `submitWithBlocks`에서 `createReview` 완료 후 `addExpAndCheck`가 같은 `try` 안에 있어, EXP 지급이 실패하면 리뷰는 저장됐는데 에러 토스트가 뜨고 화면 이동도 안 됐다. 다시 누르면 새 UUID로 **중복 리뷰가 생길 수 있었다**. → EXP 실패는 Crashlytics non-fatal로만 기록하고 등록은 성공 처리. 사용자 행동이 아닌 운영 오류이므로 Analytics에는 남기지 않는다
1-1. ~~**이미지 업로드 중 완료 버튼 연타 가능**~~ (2026-10-12 수정) — 버튼 비활성화 기준인 `isLoading`이 업로드가 끝난 뒤에야 켜져서, 업로드 중 연타하면 업로드와 저장이 두 번 실행되고 리뷰가 2개 생길 수 있었다. → 화면에 `_isSubmitting` 가드를 두어 저장 버튼 탭부터 완료까지 막음
1-2. **문서 ID를 화면 진입 시 고정** (2026-10-12) — 리뷰 ID를 저장할 때마다 새로 만들지 않고 작성 화면 진입 시 한 번 정한다. 서버에는 저장됐는데 응답만 실패해 사용자가 다시 눌러도 같은 문서를 덮어쓰므로 중복이 생기지 않는다 (멱등성)
2. **`createdAt`이 기기 시계 기준** — `ReviewModel.createdAt = DateTime.now()`. Firestore와 Analytics 모두 기기 시계라 서로는 맞지만, 기기 시간이 틀리면 둘 다 틀린다. 일자별 비교 시 서버 시각을 쓸 수 없다는 한계로 기록해둔다
3. **이미지 업로드 실패는 `submitWithBlocks` 바깥에서 처리됨** — `_submit`에서 `buildContentBlocks` 실패 시 토스트만 띄우고 `return`. 실패 로그를 화면 쪽에서 남겨야 `error_stage=image_upload`를 구분할 수 있다
4. **`withRetry`가 `createReview`를 최대 3번 재시도** — 문서 ID를 미리 정해서 `doc(id)`에 쓰므로 재시도해도 중복 문서는 생기지 않는 것으로 보인다. 다만 재시도 횟수가 로그에 없어 `elapsed_ms`가 길게 나와도 원인을 알 수 없다 → 필요하면 `retry_count` 파라미터 추가 검토
5. **`BlogBodyEditor`에 변경 콜백이 없음** — 본문 첫 입력(`first_input=body`)과 사진 추가/삭제를 감지하려면 에디터에 콜백을 추가해야 한다

---

## 확인 필요

- debug 모드(`-FIRDebugEnabled`)로 보낸 이벤트가 BigQuery export에 포함되는지
- BigQuery 일별 export 테이블이 생성되는 시각과 수집 지연 이벤트가 어떻게 반영되는지
- 개인정보처리방침(`docs/privacy_policy.md`)과 App Store / Play Console 개인정보 항목에 Analytics 수집 내용 반영

---

## 변경 이력

| 날짜 | 내용 |
|---|---|
| 2026-10-12 | 초안 작성 |
| 2026-10-12 | 구현 반영: `error_stage`에서 `post_process` 제거, 중복 리뷰 리스크 1·1-1·1-2 수정 |
