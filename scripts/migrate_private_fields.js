// users/{uid}는 로그인한 누구나 읽을 수 있는데 email·fcmToken이 들어있었다.
// 이 두 필드를 본인만 읽는 users/{uid}/private/account로 옮기고 공개 필드는 지운다.
//
//   node migrate_private_fields.js          # dry-run: 바뀔 내용만 출력
//   node migrate_private_fields.js --apply  # 실제 반영
//
// 여러 번 실행해도 안전하다. 옛 앱은 실행 후에도 공개 문서에 fcmToken을 다시
// 쓸 수 있는데, 함수(getUserFcmData)가 공개 필드 → private 순으로 읽으므로
// 알림은 끊기지 않는다. 공개 필드가 남아 있으면 옛 앱이 가장 최근에 쓴 값이라
// private 값보다 우선해서 옮긴다.
const admin = require('firebase-admin');

if (process.env.FIRESTORE_EMULATOR_HOST) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-mannti' });
} else {
  admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
}

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const APPLY = process.argv.includes('--apply');
const FIELDS = ['email', 'fcmToken'];

async function main() {
  console.log(APPLY ? '[APPLY] 실제로 반영합니다' : '[DRY-RUN] --apply 없이 실행 — 아무것도 바꾸지 않습니다');
  const users = await db.collection('users').get();

  let batch = db.batch();
  let ops = 0;
  let moved = 0;
  const commits = [];
  const flush = () => {
    if (ops > 0 && APPLY) commits.push(batch.commit());
    batch = db.batch();
    ops = 0;
  };

  for (const doc of users.docs) {
    const data = doc.data();
    const present = FIELDS.filter((f) => data[f] !== undefined);
    if (present.length === 0) continue;

    const privateData = {};
    const cleanup = {};
    for (const f of present) {
      if (data[f] !== null && data[f] !== '') privateData[f] = data[f];
      cleanup[f] = FieldValue.delete();
    }

    console.log(`${doc.id}: ${present.join(', ')} → private/account${Object.keys(privateData).length ? '' : ' (빈 값이라 삭제만)'}`);
    if (Object.keys(privateData).length) {
      batch.set(doc.ref.collection('private').doc('account'), privateData, { merge: true });
      ops++;
    }
    batch.update(doc.ref, cleanup);
    ops++;
    moved++;
    if (ops >= 450) flush();
  }
  flush();
  await Promise.all(commits);
  console.log(`대상 ${moved}명 / 전체 ${users.size}명${APPLY ? ' — 반영 완료' : ''}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
