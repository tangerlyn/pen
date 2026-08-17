const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const functionsV1 = require("firebase-functions/v1");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");

initializeApp();
const db = getFirestore();
const fcm = getMessaging();

// 유저의 FCM 토큰과 알림 설정 조회
async function getUserFcmData(uid) {
  const doc = await db.collection("users").doc(uid).get();
  const data = doc.data() ?? {};
  return {
    fcmToken: data.fcmToken ?? null,
    notificationSettings: data.notificationSettings ?? {},
  };
}

// FCM 메시지 전송
async function sendNotification({ token, body, data }) {
  if (!token) return;
  try {
    await fcm.send({
      token,
      notification: { title: "닙펜", body },
      data,
      apns: { payload: { aps: { sound: "default" } } },
      android: {
        notification: { sound: "default", channelId: "nibpen_notifications" },
      },
    });
  } catch (e) {
    console.error("[FCM] send error:", e);
  }
}

// Firestore 알림 문서 저장
// docId를 넘기면 해당 ID로 set(merge) — 좋아요/팔로우처럼 "취소 후 재실행"이
// 가능한 액션은 같은 문서를 덮어써서 중복 알림이 쌓이지 않게 한다.
// 댓글/답글처럼 매번 새로운 이벤트인 경우 docId를 생략해 auto-ID로 새로 쌓는다.
async function saveNotification({ targetUid, type, targetId, targetType, fromUid, fromNickname, message, fromProfileImageUrl, docId }) {
  try {
    const itemsRef = db.collection("notifications").doc(targetUid).collection("items");
    const itemRef = docId ? itemsRef.doc(docId) : itemsRef.doc();
    await itemRef.set({
      type,
      targetId: targetId ?? "",
      targetType: targetType ?? "",
      fromUid,
      fromNickname,
      fromProfileImageUrl: fromProfileImageUrl ?? null,
      message,
      isRead: false,
      createdAt: new Date(),
    }, { merge: true });
  } catch (e) {
    console.error("[Notification] save error:", e);
  }
}

// ── 리뷰 좋아요 ─────────────────────────────────────────────────────────────
exports.onReviewLike = onDocumentCreated(
  "reviews/{reviewId}/likes/{uid}",
  async (event) => {
    const { reviewId, uid: likerUid } = event.params;

    const reviewDoc = await db.collection("reviews").doc(reviewId).get();
    const authorId = reviewDoc.data()?.authorId;
    if (!authorId || authorId === likerUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(authorId);
    if (!fcmToken || notificationSettings.likes === false) return;

    const likerDoc = await db.collection("users").doc(likerUid).get();
    const likerNickname = likerDoc.data()?.nickname ?? "누군가";
    const likerProfile = likerDoc.data()?.profileImageUrl ?? null;

    const msg = `회원님의 리뷰에 좋아요를 눌렀어요`;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${likerNickname}님이 ${msg}`,
        data: { type: "like_review", reviewId },
      }),
      saveNotification({
        targetUid: authorId,
        type: "like",
        targetId: reviewId,
        targetType: "review",
        fromUid: likerUid,
        fromNickname: likerNickname,
        fromProfileImageUrl: likerProfile,
        message: msg,
        docId: `like_review_${reviewId}_${likerUid}`,
      }),
    ]);
  }
);

// ── 리뷰 댓글 ───────────────────────────────────────────────────────────────
exports.onReviewComment = onDocumentCreated(
  "reviews/{reviewId}/comments/{commentId}",
  async (event) => {
    const { reviewId } = event.params;
    const commentData = event.data?.data() ?? {};
    const commenterUid = commentData.authorId;

    const reviewDoc = await db.collection("reviews").doc(reviewId).get();
    const authorId = reviewDoc.data()?.authorId;
    if (!authorId || authorId === commenterUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(authorId);
    if (!fcmToken || notificationSettings.comments === false) return;

    const commenterNickname = commentData.authorNickname || "누군가";

    const msg = `회원님의 리뷰에 댓글을 남겼어요`;
    const commenterDoc = await db.collection("users").doc(commenterUid).get();
    const commenterProfile = commenterDoc.data()?.profileImageUrl ?? null;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${commenterNickname}님이 ${msg}`,
        data: { type: "comment_review", reviewId },
      }),
      saveNotification({
        targetUid: authorId,
        type: "comment",
        targetId: reviewId,
        targetType: "review",
        fromUid: commenterUid,
        fromNickname: commenterNickname,
        fromProfileImageUrl: commenterProfile,
        message: msg,
      }),
    ]);
  }
);

// ── 게시글 좋아요 ───────────────────────────────────────────────────────────
exports.onPostLike = onDocumentCreated(
  "posts/{postId}/likes/{uid}",
  async (event) => {
    const { postId, uid: likerUid } = event.params;

    const postDoc = await db.collection("posts").doc(postId).get();
    const authorId = postDoc.data()?.authorId;
    if (!authorId || authorId === likerUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(authorId);
    if (!fcmToken || notificationSettings.likes === false) return;

    const likerDoc = await db.collection("users").doc(likerUid).get();
    const likerNickname = likerDoc.data()?.nickname ?? "누군가";
    const likerProfilePost = likerDoc.data()?.profileImageUrl ?? null;

    const msg = `회원님의 게시글에 좋아요를 눌렀어요`;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${likerNickname}님이 ${msg}`,
        data: { type: "like_post", postId },
      }),
      saveNotification({
        targetUid: authorId,
        type: "like",
        targetId: postId,
        targetType: "post",
        fromUid: likerUid,
        fromNickname: likerNickname,
        fromProfileImageUrl: likerProfilePost,
        message: msg,
        docId: `like_post_${postId}_${likerUid}`,
      }),
    ]);
  }
);

// ── 게시글 댓글 ─────────────────────────────────────────────────────────────
exports.onPostComment = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const { postId } = event.params;
    const commentData = event.data?.data() ?? {};
    const commenterUid = commentData.authorId;

    const postDoc = await db.collection("posts").doc(postId).get();
    const authorId = postDoc.data()?.authorId;
    if (!authorId || authorId === commenterUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(authorId);
    if (!fcmToken || notificationSettings.comments === false) return;

    const commenterNickname = commentData.authorNickname || "누군가";

    const msgPost = `회원님의 게시글에 댓글을 남겼어요`;
    const commenterDocPost = await db.collection("users").doc(commenterUid).get();
    const commenterProfilePost = commenterDocPost.data()?.profileImageUrl ?? null;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${commenterNickname}님이 ${msgPost}`,
        data: { type: "comment_post", postId },
      }),
      saveNotification({
        targetUid: authorId,
        type: "comment",
        targetId: postId,
        targetType: "post",
        fromUid: commenterUid,
        fromNickname: commenterNickname,
        fromProfileImageUrl: commenterProfilePost,
        message: msgPost,
      }),
    ]);
  }
);

// ── 팔로우 ──────────────────────────────────────────────────────────────────
exports.onFollow = onDocumentCreated("follows/{followDoc}", async (event) => {
  const followData = event.data?.data() ?? {};
  const { followerId, followeeId } = followData;
  if (!followerId || !followeeId) return;

  const { fcmToken, notificationSettings } = await getUserFcmData(followeeId);
  if (!fcmToken || notificationSettings.follows === false) return;

  const followerDoc = await db.collection("users").doc(followerId).get();
  const followerNickname = followerDoc.data()?.nickname ?? "누군가";
  const followerProfile = followerDoc.data()?.profileImageUrl ?? null;

  const msg = `회원님을 팔로우하기 시작했어요`;
  await Promise.all([
    sendNotification({
      token: fcmToken,
      body: `${followerNickname}님이 ${msg}`,
      data: { type: "follow", fromUid: followerId },
    }),
    saveNotification({
      targetUid: followeeId,
      type: "follow",
      targetId: followerId,
      targetType: "",
      fromUid: followerId,
      fromNickname: followerNickname,
      fromProfileImageUrl: followerProfile,
      message: msg,
      docId: `follow_${followerId}_${followeeId}`,
    }),
  ]);
});

// ── 리뷰 댓글의 답글 ─────────────────────────────────────────────────────────
exports.onReviewReply = onDocumentCreated(
  "reviews/{reviewId}/comments/{commentId}/replies/{replyId}",
  async (event) => {
    const { reviewId, commentId } = event.params;
    const replyData = event.data?.data() ?? {};
    const replierUid = replyData.authorId;

    const commentDoc = await db
      .collection("reviews").doc(reviewId)
      .collection("comments").doc(commentId)
      .get();
    const commentAuthorId = commentDoc.data()?.authorId;
    if (!commentAuthorId || commentAuthorId === replierUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(commentAuthorId);
    if (!fcmToken || notificationSettings.comments === false) return;

    const replierNickname = replyData.authorNickname || "누군가";
    const replierDoc = await db.collection("users").doc(replierUid).get();
    const replierProfile = replierDoc.data()?.profileImageUrl ?? null;

    const msg = `회원님의 댓글에 답글을 남겼어요`;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${replierNickname}님이 ${msg}`,
        data: { type: "comment_review", reviewId },
      }),
      saveNotification({
        targetUid: commentAuthorId,
        type: "comment",
        targetId: reviewId,
        targetType: "review",
        fromUid: replierUid,
        fromNickname: replierNickname,
        fromProfileImageUrl: replierProfile,
        message: msg,
      }),
    ]);
  }
);

// ── 게시글 댓글의 답글 ───────────────────────────────────────────────────────
exports.onPostReply = onDocumentCreated(
  "posts/{postId}/comments/{commentId}/replies/{replyId}",
  async (event) => {
    const { postId, commentId } = event.params;
    const replyData = event.data?.data() ?? {};
    const replierUid = replyData.authorId;

    const commentDoc = await db
      .collection("posts").doc(postId)
      .collection("comments").doc(commentId)
      .get();
    const commentAuthorId = commentDoc.data()?.authorId;
    if (!commentAuthorId || commentAuthorId === replierUid) return;

    const { fcmToken, notificationSettings } = await getUserFcmData(commentAuthorId);
    if (!fcmToken || notificationSettings.comments === false) return;

    const replierNickname = replyData.authorNickname || "누군가";
    const replierDoc = await db.collection("users").doc(replierUid).get();
    const replierProfile = replierDoc.data()?.profileImageUrl ?? null;

    const msg = `회원님의 댓글에 답글을 남겼어요`;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: `${replierNickname}님이 ${msg}`,
        data: { type: "comment_post", postId },
      }),
      saveNotification({
        targetUid: commentAuthorId,
        type: "comment",
        targetId: postId,
        targetType: "post",
        fromUid: replierUid,
        fromNickname: replierNickname,
        fromProfileImageUrl: replierProfile,
        message: msg,
      }),
    ]);
  }
);

// ── 문의 답변 완료 ───────────────────────────────────────────────────────────
exports.onInquiryAnswered = onDocumentUpdated(
  "inquiries/{inquiryId}",
  async (event) => {
    const before = event.data?.before?.data() ?? {};
    const after = event.data?.after?.data() ?? {};
    // 답변이 이번에 새로 채워진 경우에만 알림 (답변을 수정하는 경우는 재알림 안 함)
    if (before.answer || !after.answer) return;

    const { inquiryId } = event.params;
    const targetUid = after.uid;
    if (!targetUid) return;

    const { fcmToken } = await getUserFcmData(targetUid);
    if (!fcmToken) return;

    const msg = `문의하신 내용에 답변이 등록됐어요`;
    await Promise.all([
      sendNotification({
        token: fcmToken,
        body: msg,
        data: { type: "inquiry_answered", inquiryId },
      }),
      saveNotification({
        targetUid,
        type: "inquiry_answered",
        targetId: inquiryId,
        targetType: "inquiry",
        fromUid: "system",
        fromNickname: "펜귄",
        message: msg,
        docId: `inquiry_${inquiryId}`,
      }),
    ]);
  }
);

// ── 신고 처리 ───────────────────────────────────────────────────────────────
// 신고가 쌓이기만 하고 아무도 조치하지 않던 문제 대응. 리뷰/게시글처럼
// 삭제 방법이 명확한 콘텐츠는 신고 5건(서로 다른 신고자 — reports 문서 ID가
// `targetType_targetId_reporterId`로 고정돼있어 한 사람의 중복 신고는 카운트 안 됨)
// 누적 시 자동 삭제하고, 관리자(개발자 본인) 계정으로 평소 알림과 동일한
// FCM 푸시 + 인앱 알림을 보내 무슨 일이 있었는지 알 수 있게 한다.
// 댓글/답글/제품(잉크·만년필) 신고는 신고 문서만으로 부모 문서 경로를 알 수
// 없거나(댓글·답글) 삭제 리스크가 커서(카탈로그 제품) 자동 삭제 대상에서
// 제외 — 임계값 도달 시 알림만 보내 수동 검토를 유도한다.
const REPORT_AUTO_DELETE_THRESHOLD = 5;
// TODO: 본인의 Firebase Auth UID로 교체할 것 (Firebase 콘솔 → Authentication
// 에서 확인, 또는 Firestore users 컬렉션에서 본인 문서 ID 확인). 채우기
// 전까지는 자동 삭제는 정상 동작하지만 관리자 알림은 전송되지 않는다.
const ADMIN_UID = "";

const REPORT_DELETABLE_COLLECTIONS = {
  review: "reviews",
  post: "posts",
};

exports.onReportCreated = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const report = event.data?.data();
    if (!report) return;
    const { targetType, targetId } = report;
    if (!targetType || !targetId) return;

    const countSnap = await db
      .collection("reports")
      .where("targetType", "==", targetType)
      .where("targetId", "==", targetId)
      .count()
      .get();
    const reportCount = countSnap.data().count;

    let action = "watching";
    const targetCollection = REPORT_DELETABLE_COLLECTIONS[targetType];
    if (reportCount >= REPORT_AUTO_DELETE_THRESHOLD && targetCollection) {
      const targetRef = db.collection(targetCollection).doc(targetId);
      const targetSnap = await targetRef.get();
      if (targetSnap.exists) {
        // 댓글/좋아요/스크랩 서브컬렉션까지 정리 — 클라이언트의 단순
        // delete()와 달리 관리자 권한 자동 삭제이므로 고아 데이터 없이
        // 통째로 지운다 (onUserDeleted에서 쓰는 것과 동일한 방식).
        await db.recursiveDelete(targetRef);
        action = "deleted";
      } else {
        action = "already_deleted";
      }
    }

    // 임계값을 이번 신고로 막 넘긴 시점에만 1회 알림 (그 전후 신고마다
    // 매번 알리면 스팸이 되므로, 정확히 같아지는 순간만 잡는다)
    if (reportCount === REPORT_AUTO_DELETE_THRESHOLD && ADMIN_UID) {
      const msg =
        action === "deleted"
          ? `신고 ${reportCount}건이 누적돼 ${targetType} 콘텐츠를 자동 삭제했어요 (ID: ${targetId})`
          : `${targetType}(ID: ${targetId})에 신고가 ${reportCount}건 누적됐어요. 확인해주세요.`;

      const { fcmToken } = await getUserFcmData(ADMIN_UID);
      await Promise.all([
        sendNotification({
          token: fcmToken,
          body: msg,
          data: { type: "admin_report_alert", targetType, targetId, action },
        }),
        saveNotification({
          targetUid: ADMIN_UID,
          type: "admin_report_alert",
          targetId,
          targetType,
          fromUid: "system",
          fromNickname: "펜귄",
          message: msg,
          docId: `report_alert_${targetType}_${targetId}`,
        }),
      ]);
    }
  }
);

// 계정 탈퇴 후 처리 — 클라이언트는 auth.user().delete()만 성공시키면 되고,
// 나머지는 Admin 권한으로 서버에서 처리한다. 리뷰/커뮤니티 글/댓글/대댓글은
// 지우지 않고 작성자 닉네임만 "알 수 없음"으로 바꿔서 콘텐츠는 그대로
// 남긴다. users 문서는 통째로 지우는데, 이러면 (1) 프로필을 눌렀을 때
// 기존 navigateToProfile()의 "탈퇴한 계정" 처리와 review/comment 위젯의
// 작성자 null 처리(아바타 기본값, 라이브 닉네임 조회 실패 시 denormalized
// 값 사용)가 별도 클라이언트 수정 없이 그대로 맞물리고, (2) 닉네임 중복
// 확인 쿼리가 이 유저를 더 이상 찾지 못해 같은 닉네임을 새 사용자가
// 충돌 없이 다시 쓸 수 있게 된다.
const ANONYMOUS_NICKNAME = "알 수 없음";

async function anonymizeAuthor(query) {
  const snap = await query.get();
  if (snap.empty) return;
  let batch = db.batch();
  let count = 0;
  const commits = [];
  for (const doc of snap.docs) {
    batch.update(doc.ref, { authorNickname: ANONYMOUS_NICKNAME });
    count++;
    if (count === 450) {
      commits.push(batch.commit());
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) commits.push(batch.commit());
  await Promise.all(commits);
}

async function deleteQueryBatch(query) {
  const snap = await query.get();
  if (snap.empty) return;
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
}

exports.onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;

  await Promise.all([
    anonymizeAuthor(db.collection("reviews").where("authorId", "==", uid)),
    anonymizeAuthor(db.collection("posts").where("authorId", "==", uid)),
    anonymizeAuthor(
      db.collectionGroup("comments").where("authorId", "==", uid)
    ),
    anonymizeAuthor(
      db.collectionGroup("replies").where("authorId", "==", uid)
    ),
  ]).catch((e) => console.error("[onUserDeleted] 작성자 표시 실패:", e));

  // 팔로우 관계는 콘텐츠가 아니라서 그대로 삭제하고, 상대방의
  // followerCount/followingCount도 같이 줄여준다. 안 그러면 예를 들어
  // "팔로워 4명"인데 실제 목록엔 1명이 탈퇴해서 3명만 보이는 식으로
  // 숫자와 목록이 어긋나게 된다.
  try {
    const [asFollower, asFollowee] = await Promise.all([
      db.collection("follows").where("followerId", "==", uid).get(),
      db.collection("follows").where("followeeId", "==", uid).get(),
    ]);

    // 같은 문서(otherUid)에 batch 안에서 update()를 두 번 하면 안 되므로,
    // 델타를 한 번에 모아서 유저당 update 한 번만 실행한다.
    const counterDeltas = {};
    const bump = (targetUid, field) => {
      counterDeltas[targetUid] = counterDeltas[targetUid] || {};
      counterDeltas[targetUid][field] =
        (counterDeltas[targetUid][field] || 0) - 1;
    };

    let batch = db.batch();
    let ops = 0;
    const commits = [];
    const flush = () => {
      if (ops > 0) commits.push(batch.commit());
      batch = db.batch();
      ops = 0;
    };

    for (const doc of asFollower.docs) {
      // uid가 팔로우하던 상대 → 그 사람의 followerCount 감소
      const { followeeId } = doc.data();
      batch.delete(doc.ref);
      ops++;
      if (followeeId) bump(followeeId, "followerCount");
      if (ops >= 450) flush();
    }
    for (const doc of asFollowee.docs) {
      // uid를 팔로우하던 상대 → 그 사람의 followingCount 감소
      const { followerId } = doc.data();
      batch.delete(doc.ref);
      ops++;
      if (followerId) bump(followerId, "followingCount");
      if (ops >= 450) flush();
    }
    for (const [targetUid, deltas] of Object.entries(counterDeltas)) {
      const update = {};
      if (deltas.followerCount) {
        update.followerCount = FieldValue.increment(deltas.followerCount);
      }
      if (deltas.followingCount) {
        update.followingCount = FieldValue.increment(deltas.followingCount);
      }
      batch.update(db.collection("users").doc(targetUid), update);
      ops++;
      if (ops >= 450) flush();
    }
    flush();
    await Promise.all(commits);
  } catch (e) {
    console.error("[onUserDeleted] follows 정리 실패:", e);
  }

  // 탈퇴 사용자가 다른 사람 리뷰/글에 남긴 좋아요·스크랩도 정리하고
  // (문서 ID = uid), 해당 글의 likeCount/scrapCount를 같이 줄인다.
  // likes/scraps는 review/post마다 서브컬렉션이라 "이 uid의 좋아요 전체"를
  // 바로 조회할 방법이 없어, collection group 전체를 훑어 문서 ID로 걸러낸다.
  try {
    const [likeDocs, scrapDocs] = await Promise.all([
      db.collectionGroup("likes").get(),
      db.collectionGroup("scraps").get(),
    ]);

    let batch = db.batch();
    let ops = 0;
    const commits = [];
    const flush = () => {
      if (ops > 0) commits.push(batch.commit());
      batch = db.batch();
      ops = 0;
    };

    for (const doc of likeDocs.docs) {
      if (doc.id !== uid) continue;
      const parent = doc.ref.parent.parent; // reviews/{id} or posts/{id}
      batch.delete(doc.ref);
      ops++;
      if (parent) {
        batch.update(parent, { likeCount: FieldValue.increment(-1) });
        ops++;
      }
      if (ops >= 450) flush();
    }
    for (const doc of scrapDocs.docs) {
      if (doc.id !== uid) continue;
      const parent = doc.ref.parent.parent;
      batch.delete(doc.ref);
      ops++;
      if (parent) {
        batch.update(parent, { scrapCount: FieldValue.increment(-1) });
        ops++;
      }
      if (ops >= 450) flush();
    }
    flush();
    await Promise.all(commits);
  } catch (e) {
    console.error("[onUserDeleted] 좋아요/스크랩 정리 실패:", e);
  }

  // users 문서(잉크북/잉크차트 포함) 및 알림함 재귀 삭제
  try {
    await db.recursiveDelete(db.collection("users").doc(uid));
  } catch (e) {
    console.error("[onUserDeleted] users 문서 재귀 삭제 실패:", e);
  }
  try {
    await db.recursiveDelete(db.collection("notifications").doc(uid));
  } catch (e) {
    console.error("[onUserDeleted] notifications 재귀 삭제 실패:", e);
  }

  // Storage 파일 정리
  try {
    const bucket = getStorage().bucket();
    await bucket.deleteFiles({ prefix: `profiles/${uid}/` });
    await bucket.deleteFiles({ prefix: `inkChart/${uid}/` });
  } catch (e) {
    console.error("[onUserDeleted] Storage 정리 실패:", e);
  }
});
