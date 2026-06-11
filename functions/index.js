const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

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
async function saveNotification({ targetUid, type, targetId, targetType, fromUid, fromNickname, message, fromProfileImageUrl }) {
  try {
    const itemRef = db
      .collection("notifications")
      .doc(targetUid)
      .collection("items")
      .doc();
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
    });
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

    const msg = `회원님의 리뷰에 좋아요를 눌렀어요`;
    const likerData = await db.collection("users").doc(likerUid).get();
    const likerProfile = likerData.data()?.profileImageUrl ?? null;
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

    const msg = `회원님의 게시글에 좋아요를 눌렀어요`;
    const likerDataPost = await db.collection("users").doc(likerUid).get();
    const likerProfilePost = likerDataPost.data()?.profileImageUrl ?? null;
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

  const msg = `회원님을 팔로우하기 시작했어요`;
  const followerDataFull = await db.collection("users").doc(followerId).get();
  const followerProfile = followerDataFull.data()?.profileImageUrl ?? null;
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
    }),
  ]);
});
