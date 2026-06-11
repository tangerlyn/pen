# 채팅 (Chat)

## 개요

유저 간 1:1 DM. 텍스트·이미지 메시지 전송, 읽음 처리, 위험 패턴 감지.

---

## 화면 목록

### `chat_list_screen.dart`
- 경로: `/chat`
- 참여 중인 채팅방 목록 (최근 메시지·시간 표시)
- 미읽 메시지 수 뱃지
- 채팅방 탭 → `/chat/:chatId`

### `chat_room_screen.dart`
- 경로: `/chat/:chatId`
- 실시간 메시지 스트림 (Firestore StreamProvider)
- 텍스트 전송, 이미지 첨부 (갤러리)
- 진입 시 해당 채팅방 읽음 처리 (`markAsRead`)
- **위험 패턴 감지**: 메시지 전송 전 `containsDangerousPattern` 검사. 위험 패턴 감지 시 경고 배너 표시 후 전송 가능
- 상대방 프로필 탭 → `/profile/:uid`

---

## 데이터 구조 (ChatModel / MessageModel)

```
ChatRoom: chatId, participantUids[], lastMessage, lastMessageAt, unreadCount{uid: count}
Message: messageId, senderUid, text, imageUrl, createdAt, isRead
```

---

## 상태 관리

- `chatRoomProvider` — StreamProvider.family(chatId)
- `chatListProvider` — StreamProvider (내 채팅방 목록)

---

## 관련 파일

- `lib/features/chat/providers/chat_provider.dart`
- `lib/data/models/chat_model.dart`
- `lib/data/repositories/` (chat 관련)
