// 스크랩 기능 제거 후 "좋아요" 탭에서 collectionGroup('likes').where('uid', ...)
// 쿼리로 좋아요한 글을 찾는데, reviews/{id}/likes/{uid} 문서는 예전엔 uid 필드 없이
// 문서 ID로만 uid를 담고 있었다(posts/{id}/likes/{uid}는 이미 uid 필드가 있었음).
// 기존에 눌러둔 좋아요가 새 "좋아요" 탭에서 안 보이지 않도록, 이미 있는 모든
// 리뷰 좋아요 문서에 uid 필드(=문서 ID)를 백필한다. 한 번만 실행하면 됨.
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function backfillReviewLikeUid() {
  console.log('Starting migration: backfilling uid field on review likes...');

  const snapshot = await db.collectionGroup('likes').get();
  const reviewLikeDocs = snapshot.docs.filter(
    (doc) => doc.ref.parent.parent?.parent.id === 'reviews'
  );

  if (reviewLikeDocs.length === 0) {
    console.log('No review like docs found.');
    return;
  }

  let batch = db.batch();
  let opsInBatch = 0;
  let updated = 0;
  const commits = [];

  for (const doc of reviewLikeDocs) {
    const data = doc.data();
    if (data.uid) continue; // 이미 백필됐거나 새로 쓰인 문서는 건너뜀
    batch.update(doc.ref, { uid: doc.id });
    opsInBatch++;
    updated++;
    if (opsInBatch >= 450) {
      commits.push(batch.commit());
      batch = db.batch();
      opsInBatch = 0;
    }
  }
  if (opsInBatch > 0) commits.push(batch.commit());
  await Promise.all(commits);

  console.log(
    `Checked ${reviewLikeDocs.length} review like docs, backfilled uid on ${updated}.`
  );
}

backfillReviewLikeUid()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
