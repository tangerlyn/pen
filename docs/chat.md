# 채팅 (Chat)

## 개요

1:1 다이렉트 메시지. 텍스트·이미지 전송, 안읽은 메시지 수 뱃지, 사기 방지 경고 포함.

---

## 화면 목록

### `chat_list_screen.dart`
**경로:** `/chat`

**화면 구성**
- AppBar: "채팅"
- 내가 참여 중인 채팅방 목록 (`chatRoomsProvider(uid)` 실시간)
- 각 항목:
  - 상대방 아바타 (CircleAvatar radius 24)
  - 상대방 닉네임 (굵게)
  - 마지막 메시지 미리보기 (1줄 말줄임)
  - 마지막 메시지 시간 (`timeago` 포맷: "방금 전", "3분 전" 등)
  - 안읽은 메시지 수 빨간 뱃지 (99건 초과 시 "99+" 표시)
- 항목 탭 → `/chat/:chatId`
- 채팅 없으면 말풍선 아이콘 + "채팅 내역이 없습니다." 빈 상태 표시

---

### `chat_room_screen.dart`
**경로:** `/chat/:chatId`

채팅방 진입 시 자동으로 안읽음 해제 (`markAsRead`).

**AppBar**
- 상대방 닉네임
- 우측 ⋮ 버튼 (추후 확장 예정)

**사기 방지 경고 배너**
- 계좌번호·전화번호 패턴 감지(`containsDangerousPattern`) 시 상단 노란 경고 배너 표시
- "채팅창 외부에서 계좌번호나 전화번호를 주고받는 것은 사기 위험이 있습니다." 문구
- X 버튼으로 배너 닫기

**메시지 목록** (`chatMessagesProvider(chatId)` 실시간)
- 내 메시지: 오른쪽 정렬, 네이비 배경 말풍선, 흰 텍스트
- 상대 메시지: 왼쪽 정렬, 아바타(radius 16) + 회색 배경 말풍선
- 이미지 메시지: `CachedNetworkImage` 200×200 라운드 박스
- 말풍선 모서리: 발신 측 하단 우측 4px, 수신 측 하단 좌측 4px (나머지 16px)
- 새 메시지 전송 후 최하단 자동 스크롤 (200ms easeOut)

**하단 입력창**
- 이미지 아이콘 버튼 — 탭 시 갤러리에서 이미지 선택 → Firebase Storage 업로드 → 이미지 메시지 전송
- 텍스트 입력 필드 (멀티라인, "메시지를 입력하세요..." 힌트)
- 전송 버튼 (네이비 아이콘) — 탭 시 텍스트 메시지 전송

---

## 데이터 구조

### ChatRoom

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 채팅방 ID |
| buyerId | String | 구매자 UID |
| sellerId | String | 판매자 UID |
| lastMessage | String | 마지막 메시지 내용 |
| lastMessageAt | DateTime? | 마지막 메시지 시각 |
| unreadCounts | Map\<String, int\> | UID별 안읽은 메시지 수 |

### ChatMessage

| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | 메시지 ID |
| senderId | String | 발신자 UID |
| receiverId | String | 수신자 UID |
| content | String | 메시지 내용(텍스트) 또는 이미지 URL |
| type | MessageType | `text` / `image` |
| createdAt | DateTime | 전송 시각 |

---

## 상태 관리

| Provider | 종류 | 역할 |
|---|---|---|
| `chatRoomsProvider` | StreamProvider.family\<String\> | UID별 채팅방 목록 실시간 |
| `chatRoomProvider` | StreamProvider.family\<String\> | 개별 채팅방 정보 실시간 |
| `chatMessagesProvider` | StreamProvider.family\<String\> | 채팅방 메시지 목록 실시간 |
| `chatRepoProvider` | Provider | ChatRepository 인스턴스 |

---

## 관련 파일

- `lib/features/chat/screens/chat_list_screen.dart`
- `lib/features/chat/screens/chat_room_screen.dart`
- `lib/features/chat/providers/chat_provider.dart`
- `lib/data/models/chat_model.dart`
- `lib/data/repositories/chat_repository.dart`
