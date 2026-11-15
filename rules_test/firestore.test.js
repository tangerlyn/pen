// Firestore 보안 규칙 테스트.
// 원칙: 현재 앱 코드가 실제로 보내는 쓰기는 통과(assertSucceeds), 악용 경로는 거부(assertFails).
// 실행: npm run emu  (에뮬레이터를 띄우고 테스트 후 종료)
const { test, before, beforeEach, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection,
  writeBatch, runTransaction, increment, serverTimestamp, deleteField,
  collectionGroup, query, where, getDocs,
} = require('firebase/firestore');

let env;
const A = 'alice';
const B = 'bob';
const C = 'carol';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mannti',
    firestore: {
      rules: fs.readFileSync(process.env.FIRESTORE_RULES || path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => env.cleanup());

const db = (uid) => env.authenticatedContext(uid).firestore();

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = ctx.firestore();
    for (const uid of [A, B, C]) {
      await setDoc(doc(s, 'users', uid), {
        uid, nickname: uid, exp: 20, followerCount: 0, followingCount: 0,
      });
    }
    await setDoc(doc(s, 'reviews', 'r1'), {
      authorId: A, title: 't', body: 'b', likeCount: 0, commentCount: 0,
    });
    await setDoc(doc(s, 'posts', 'p1'), {
      authorId: A, title: 't', body: 'b', likeCount: 0, commentCount: 0,
    });
    await setDoc(doc(s, 'reviews', 'r1', 'comments', 'c1'), { authorId: B, body: 'hi' });
    await setDoc(doc(s, 'inks', 'ink1'), { brand: 'x', name: 'y', addedBy: B, isUserAdded: true });
    await setDoc(doc(s, 'inks', 'catalog'), { brand: 'Pilot', name: 'Iroshizuku' });
  });
});

// ── 앱의 실제 동작 재현 헬퍼 (lib/data/repositories/*) ─────────────────
async function toggleLike(d, col, id, uid, liked) {
  const likeRef = doc(d, col, id, 'likes', uid);
  const ref = doc(d, col, id);
  await runTransaction(d, async (tx) => {
    const snap = await tx.get(ref);
    const like = await tx.get(likeRef);
    const cur = snap.data().likeCount ?? 0;
    if (liked) {
      if (!like.exists()) {
        tx.set(likeRef, { uid, createdAt: serverTimestamp() });
        tx.update(ref, { likeCount: cur + 1 });
        tx.update(doc(d, 'users', snap.data().authorId), { exp: increment(1) });
      }
    } else if (like.exists()) {
      tx.delete(likeRef);
      tx.update(ref, { likeCount: cur > 0 ? cur - 1 : 0 });
    }
  });
}

// user_repository.dart follow/unfollow — follows 문서 존재를 트랜잭션에서 확인 후 ±1
function follow(d, from, to) {
  const ref = doc(d, 'follows', `${from}_${to}`);
  return runTransaction(d, async (tx) => {
    if ((await tx.get(ref)).exists()) return;
    tx.update(doc(d, 'users', from), { followingCount: increment(1) });
    tx.update(doc(d, 'users', to), { followerCount: increment(1) });
    tx.set(ref, { followerId: from, followeeId: to, createdAt: serverTimestamp() });
  });
}

function unfollow(d, from, to) {
  const ref = doc(d, 'follows', `${from}_${to}`);
  return runTransaction(d, async (tx) => {
    if (!(await tx.get(ref)).exists()) return;
    tx.update(doc(d, 'users', from), { followingCount: increment(-1) });
    tx.update(doc(d, 'users', to), { followerCount: increment(-1) });
    tx.delete(ref);
  });
}

async function addExpAndCheck(d, uid, amount) {
  await runTransaction(d, async (tx) => {
    const snap = await tx.get(doc(d, 'users', uid));
    tx.update(doc(d, 'users', uid), { exp: (snap.data().exp ?? 0) + amount });
  });
}

// ── 정상 동작: 통과해야 함 ─────────────────────────────────────────────
test('가입: 최초 문서 생성 + 프로필 저장(merge) — 이메일은 private에', async () => {
  const d = db('newbie');
  await assertSucceeds(setDoc(doc(d, 'users', 'newbie'), {
    uid: 'newbie', loginProvider: 'kakao', createdAt: serverTimestamp(),
  }, { merge: true }));
  await assertSucceeds(setDoc(doc(d, 'users', 'newbie', 'private', 'account'), { email: 'kakao_1@nibpen.login' }, { merge: true }));
  await assertSucceeds(setDoc(doc(d, 'users', 'newbie'), {
    uid: 'newbie', nickname: 'n', interests: [], profileImageUrl: null, bio: '',
    followerCount: 0, followingCount: 0, exp: 0,
    notificationSettings: { likes: true, comments: true, follows: true },
    termsAgreedAt: serverTimestamp(), createdAt: serverTimestamp(),
  }, { merge: true }));
});

test('레거시: 공개 email이 남은 문서도 프로필 수정·email 삭제 가능', async () => {
  await env.withSecurityRulesDisabled(async (ctx) =>
    updateDoc(doc(ctx.firestore(), 'users', A), { email: 'kakao_9@nibpen.login' }));
  await assertSucceeds(updateDoc(doc(db(A), 'users', A), { nickname: 'x' }));
  await assertSucceeds(updateDoc(doc(db(A), 'users', A), { email: deleteField() }));
});

test('[공격/옛 앱] 공개 users 문서에 이메일 새로 쓰기·바꾸기', async () => {
  await assertFails(setDoc(doc(db('old'), 'users', 'old'), {
    uid: 'old', email: 'kakao_1@nibpen.login', loginProvider: 'kakao',
  }, { merge: true }));
  await assertFails(updateDoc(doc(db(A), 'users', A), { email: 'a@x.com' }));
  await assertFails(updateDoc(doc(db(A), 'users', A), { email: null }));
});

test('프로필 수정, FCM 토큰 저장/삭제', async () => {
  const d = db(A);
  await assertSucceeds(updateDoc(doc(d, 'users', A), { nickname: 'new', bio: 'hello', fcmToken: 'tok' }));
  await assertSucceeds(updateDoc(doc(d, 'users', A), { fcmToken: null }));
});

test('개인 필드: 본인 토큰·이메일 저장(공개 필드 정리 포함)·조회·로그아웃 삭제', async () => {
  const d = db(A);
  const priv = doc(d, 'users', A, 'private', 'account');
  const save = writeBatch(d);
  save.set(priv, { fcmToken: 'tok', email: 'a@x.com' }, { merge: true });
  save.update(doc(d, 'users', A), { fcmToken: deleteField(), email: deleteField() });
  await assertSucceeds(save.commit());
  await assertSucceeds(getDoc(priv));
  await assertSucceeds(updateDoc(priv, { fcmToken: null }));
});

test('[공격] 남의 개인 필드 읽기·쓰기', async () => {
  await env.withSecurityRulesDisabled(async (ctx) =>
    setDoc(doc(ctx.firestore(), 'users', A, 'private', 'account'), { fcmToken: 'tok', email: 'a@x.com' }));
  const d = db(B);
  await assertFails(getDoc(doc(d, 'users', A, 'private', 'account')));
  await assertFails(setDoc(doc(d, 'users', A, 'private', 'account'), { fcmToken: 'evil' }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users', A, 'private', 'account')));
});

test('EXP 지급: 리뷰(+10), 게시글(+5), 댓글(+2)', async () => {
  await assertSucceeds(addExpAndCheck(db(A), A, 10));
  await assertSucceeds(addExpAndCheck(db(A), A, 5));
  await assertSucceeds(addExpAndCheck(db(A), A, 2));
});

test('팔로우 → 언팔로우', async () => {
  await assertSucceeds(follow(db(B), B, A));
  await assertSucceeds(unfollow(db(B), B, A));
});

test('리뷰/게시글 좋아요 → 취소 (작성자 EXP +1 포함)', async () => {
  await assertSucceeds(toggleLike(db(B), 'reviews', 'r1', B, true));
  await assertSucceeds(toggleLike(db(B), 'reviews', 'r1', B, false));
  await assertSucceeds(toggleLike(db(C), 'posts', 'p1', C, true));
  await assertSucceeds(toggleLike(db(C), 'posts', 'p1', C, false));
});

test('본인 글에 본인 좋아요', async () => {
  await assertSucceeds(toggleLike(db(A), 'reviews', 'r1', A, true));
});

test('리뷰 작성(카운터 0) 및 작성자 수정', async () => {
  const d = db(A);
  await assertSucceeds(setDoc(doc(d, 'reviews', 'r2'), {
    authorId: A, title: 't', body: 'b', likeCount: 0, commentCount: 0,
  }));
  await assertSucceeds(updateDoc(doc(d, 'reviews', 'r1'), {
    title: 'edited', body: 'b2', imageUrls: [], updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(addDoc(collection(d, 'posts'), {
    authorId: A, title: 't', body: 'b', likeCount: 0, commentCount: 0,
  }));
});

test('남의 리뷰에 댓글 작성/삭제 (commentCount ±1)', async () => {
  const d = db(C);
  const add = writeBatch(d);
  add.set(doc(d, 'reviews', 'r1', 'comments', 'c2'), { authorId: C, body: 'x' });
  add.update(doc(d, 'reviews', 'r1'), { commentCount: increment(1) });
  await assertSucceeds(add.commit());
  const del = writeBatch(d);
  del.delete(doc(d, 'reviews', 'r1', 'comments', 'c2'));
  del.update(doc(d, 'reviews', 'r1'), { commentCount: increment(-1) });
  await assertSucceeds(del.commit());
});

test('댓글 소프트 삭제(작성자)', async () => {
  await assertSucceeds(updateDoc(doc(db(B), 'reviews', 'r1', 'comments', 'c1'), { isDeleted: true, body: '' }));
});

test('신고: 결정적 문서 ID', async () => {
  const d = db(B);
  await assertSucceeds(setDoc(doc(d, 'reports', `review_r1_${B}`), {
    targetType: 'review', targetId: 'r1', reporterId: B, reason: 'spam', createdAt: serverTimestamp(),
  }, { merge: true }));
  await assertSucceeds(getDoc(doc(d, 'reports', `review_r1_${B}`)));
});

test('잉크·만년필 등록, 내가 등록한 잉크 수정', async () => {
  const d = db(B);
  await assertSucceeds(addDoc(collection(d, 'inks'), {
    brand: 'b', name: 'n', colorFamily: 'blue', inkType: 'normal', hexColor: '#000000',
    capacityMl: 0, addedBy: B, isUserAdded: true, createdAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(d, 'inks', 'ink1'), { brand: 'b2', name: 'n2', inkType: 'sheen', hexColor: '#111111' }));
  await assertSucceeds(addDoc(collection(d, 'pens'), {
    brand: 'b', modelName: 'm', addedBy: B, isUserAdded: true, createdAt: serverTimestamp(),
  }));
});

// ── 공격: 거부돼야 함 ──────────────────────────────────────────────────
test('[공격] 랜덤 ID 신고 남발로 자동 삭제 유도', async () => {
  const d = db(B);
  await assertFails(addDoc(collection(d, 'reports'), { targetType: 'review', targetId: 'r1', reporterId: B, reason: 'x' }));
  await assertFails(setDoc(doc(d, 'reports', `review_r1_${B}_2`), { targetType: 'review', targetId: 'r1', reporterId: B }));
  await assertFails(setDoc(doc(d, 'reports', `review_r1_${C}`), { targetType: 'review', targetId: 'r1', reporterId: B }));
});

test('[공격] 남의 EXP·팔로워 수를 임의 값으로', async () => {
  const d = db(B);
  await assertFails(updateDoc(doc(d, 'users', A), { exp: 999999 }));
  await assertFails(updateDoc(doc(d, 'users', A), { exp: 0 }));
  await assertFails(updateDoc(doc(d, 'users', A), { followerCount: 999 }));
  await assertFails(updateDoc(doc(d, 'users', A), { followerCount: increment(1) })); // 팔로우 문서 없이
  await assertFails(updateDoc(doc(d, 'users', A), { followingCount: increment(1) }));
  await assertFails(updateDoc(doc(d, 'users', A), { nickname: 'hacked' }));
});

test('[공격] 내 EXP 대량 증가·팔로워 수 부풀리기', async () => {
  const d = db(A);
  await assertFails(updateDoc(doc(d, 'users', A), { exp: 999999 }));
  await assertFails(updateDoc(doc(d, 'users', A), { exp: increment(11) }));
  await assertFails(updateDoc(doc(d, 'users', A), { followerCount: 5000 }));
  await assertFails(updateDoc(doc(d, 'users', A), { followingCount: 5000 }));
});

test('[공격] 좋아요 수 조작', async () => {
  const d = db(B);
  await assertFails(updateDoc(doc(d, 'reviews', 'r1'), { likeCount: 99999 }));
  await assertFails(updateDoc(doc(d, 'reviews', 'r1'), { likeCount: increment(1) })); // 좋아요 문서 없이
  await assertFails(updateDoc(doc(d, 'posts', 'p1'), { commentCount: 500 }));
  const b = writeBatch(d);
  b.set(doc(d, 'reviews', 'r1', 'likes', B), { uid: B });
  b.update(doc(d, 'reviews', 'r1'), { likeCount: increment(5) });
  await assertFails(b.commit());
  await assertFails(updateDoc(doc(db(A), 'reviews', 'r1'), { likeCount: 1000 })); // 작성자 본인도 불가
  await assertFails(setDoc(doc(db(A), 'reviews', 'r3'), { authorId: A, likeCount: 100, commentCount: 0 }));
});

test('[공격] authorId 바꿔치기', async () => {
  await assertFails(updateDoc(doc(db(A), 'reviews', 'r1'), { authorId: B }));
  await assertFails(updateDoc(doc(db(A), 'posts', 'p1'), { authorId: B }));
  await assertFails(updateDoc(doc(db(B), 'reviews', 'r1', 'comments', 'c1'), { authorId: C }));
  await assertFails(updateDoc(doc(db(B), 'reviews', 'r1'), { title: 'hacked' }));
});

test('[공격] 팔로우 문서 랜덤 ID·자기 팔로우·대리 팔로우', async () => {
  const d = db(B);
  await assertFails(addDoc(collection(d, 'follows'), { followerId: B, followeeId: A }));
  await assertFails(setDoc(doc(d, 'follows', `${B}_${B}`), { followerId: B, followeeId: B }));
  await assertFails(setDoc(doc(d, 'follows', `${C}_${A}`), { followerId: C, followeeId: A }));
});

test('[공격] 카탈로그 잉크 변조', async () => {
  const d = db(C);
  await assertFails(updateDoc(doc(d, 'inks', 'catalog'), { name: 'vandal' }));
  await assertFails(updateDoc(doc(d, 'inks', 'ink1'), { name: 'vandal' })); // 남이 등록한 잉크
  await assertFails(updateDoc(doc(db(B), 'inks', 'ink1'), { addedBy: C })); // 등록자도 허용 필드 외 불가
  await assertFails(addDoc(collection(d, 'inks'), { brand: 'b', name: 'n', addedBy: B, isUserAdded: true }));
  await assertFails(deleteDoc(doc(db(B), 'inks', 'ink1')));
});

test('컬렉션 그룹: 내 좋아요 목록·전체 공개 잉크북 목록 조회', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = ctx.firestore();
    await setDoc(doc(s, 'reviews', 'r1', 'likes', B), { uid: B });
    await setDoc(doc(s, 'posts', 'p1', 'likes', C), { uid: C });
    await setDoc(doc(s, 'users', A, 'inkBooks', 'pub'), { isPublic: true, visibility: 'public' });
    await setDoc(doc(s, 'users', A, 'inkBooks', 'priv'), { isPublic: false, visibility: 'private' });
  });
  const d = db(B);
  const mine = await assertSucceeds(
    getDocs(query(collectionGroup(d, 'likes'), where('uid', '==', B))));
  if (mine.size !== 1) throw new Error(`expected 1 like, got ${mine.size}`);
  await assertSucceeds(
    getDocs(query(collectionGroup(d, 'inkBooks'), where('isPublic', '==', true))));
});

test('[공격] 컬렉션 그룹으로 남의 좋아요·비공개 잉크북 훑기', async () => {
  const d = db(B);
  await assertFails(getDocs(query(collectionGroup(d, 'likes'), where('uid', '==', C))));
  await assertFails(getDocs(collectionGroup(d, 'likes')));
  await assertFails(getDocs(collectionGroup(d, 'inkBooks')));
  await assertFails(getDocs(collectionGroup(env.unauthenticatedContext().firestore(), 'inkBooks')));
});

test('알림 설정을 계정(users 문서)에 저장', async () => {
  await assertSucceeds(updateDoc(doc(db(A), 'users', A), {
    notificationSettings: { likes: false, comments: true, follows: true },
  }));
  await assertSucceeds(updateDoc(doc(db(A), 'users', A), { 'notificationSettings.likes': true }));
});

test('배너: 로그인 사용자는 읽기만, 쓰기는 불가', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'banners', 'b1'), { title: '공지', active: true, order: 0 });
  });
  await assertSucceeds(getDoc(doc(db(A), 'banners', 'b1')));
  await assertSucceeds(getDocs(collection(db(A), 'banners')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'banners', 'b1')));
  await assertFails(setDoc(doc(db(A), 'banners', 'b2'), { title: 'spam' }));
  await assertFails(updateDoc(doc(db(A), 'banners', 'b1'), { title: 'hacked' }));
  await assertFails(deleteDoc(doc(db(A), 'banners', 'b1')));
});
