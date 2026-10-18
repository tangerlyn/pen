// firestore.rules 검증 — 에뮬레이터 REST로 허용/거부 기대값 확인 (기록 홈·스와치 기록 규칙)
// 실행: firebase emulators:exec --only firestore --project demo-nibpen "node scripts/firestore_rules_test.mjs"
// demo- 프로젝트라 운영 데이터에 닿지 않는다.
const P = 'demo-nibpen';
const BASE = `http://127.0.0.1:8080/v1/projects/${P}/databases/(default)/documents`;
const tok = (uid) => {
  const b = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b({ alg: 'none', typ: 'JWT' })}.${b({ sub: uid, user_id: uid, iat: 0, exp: 9999999999, aud: P, iss: `https://securetoken.google.com/${P}`, firebase: { sign_in_provider: 'custom' } })}.`;
};
const val = (v) => typeof v === 'string' ? { stringValue: v } : typeof v === 'number' ? { integerValue: String(v) } : v instanceof Date ? { timestampValue: v.toISOString() } : v;
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, val(v)]));
async function commit(auth, path, data, { serverTs = [], exists } = {}) {
  const write = { update: { name: `projects/${P}/databases/(default)/documents/${path}`, fields: fields(data) },
    updateTransforms: serverTs.map((f) => ({ fieldPath: f, setToServerValue: 'REQUEST_TIME' })) };
  if (exists !== undefined) write.currentDocument = { exists };
  const r = await fetch(`${BASE}:commit`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${auth}` }, body: JSON.stringify({ writes: [write] }) });
  return r.ok;
}
async function get(auth, path) { return (await fetch(`${BASE}/${path}`, { headers: { Authorization: `Bearer ${auth}` } })).ok; }
async function del(auth, path) { return (await fetch(`${BASE}/${path}`, { method: 'DELETE', headers: { Authorization: `Bearer ${auth}` } })).ok; }
let fail = 0;
const expect = async (name, p, want) => { const got = await p; const ok = got === want; if (!ok) fail++; console.log(`${ok ? 'PASS' : 'FAIL'} ${name} (expected ${want ? 'allow' : 'deny'})`); };
const A = tok('alice'), B = tok('bob');

await commit('owner', 'users/alice/inkBooks/b1', { name: '내 잉크 기록', visibility: 'private', ownerUid: 'alice' });
const legacy = { photoUrl: 'u', brand: 'Pilot', inkName: 'Kon-peki', memo: '', order: 0 };
await expect('구버전 스와치 생성(새 필드 없음)', commit(A, 'users/alice/inkBooks/b1/inkChart/c1', legacy, { serverTs: ['createdAt'] }), true);
await expect('새 필드 포함 생성', commit(A, 'users/alice/inkBooks/b1/inkChart/c2', { ...legacy, brand: '', inkId: 'ink1', penName: 'Custom 74', nibSize: 'F', paperName: 'Tomoe River', recordedAt: new Date() }, { serverTs: ['createdAt'] }), true);
await expect('새 필드 타입 오류(recordedAt 문자열)', commit(A, 'users/alice/inkBooks/b1/inkChart/c3', { ...legacy, recordedAt: '2026-10-18' }), false);
await expect('새 필드 길이 초과(nibSize 41자)', commit(A, 'users/alice/inkBooks/b1/inkChart/c3', { ...legacy, nibSize: 'x'.repeat(41) }), false);
await expect('남의 공책에 스와치 생성', commit(B, 'users/alice/inkBooks/b1/inkChart/c4', legacy), false);
await expect('비공개 공책 스와치를 남이 읽기', get(B, 'users/alice/inkBooks/b1/inkChart/c2'), false);
await expect('본인 스와치 삭제', del(A, 'users/alice/inkBooks/b1/inkChart/c1'), true);

const owned = { inkId: 'ink1', brand: 'Pilot', name: 'Kon-peki', hexColor: '#1E88E5' };
await expect('내 컬렉션 추가', commit(A, 'users/alice/ownedInks/ink1', owned, { serverTs: ['createdAt'] }), true);
await expect('내 컬렉션: 문서 ID와 inkId 불일치', commit(A, 'users/alice/ownedInks/ink2', owned, { serverTs: ['createdAt'] }), false);
await expect('내 컬렉션: 허용 안 된 필드', commit(A, 'users/alice/ownedInks/ink1', { ...owned, extra: 'x' }, { serverTs: ['createdAt'] }), false);
await expect('내 컬렉션: createdAt 클라이언트 시각', commit(A, 'users/alice/ownedInks/ink1', { ...owned, createdAt: new Date(0) }), false);
await expect('남의 컬렉션에 추가', commit(B, 'users/alice/ownedInks/ink1', owned, { serverTs: ['createdAt'] }), false);
await expect('남의 컬렉션 읽기', get(B, 'users/alice/ownedInks/ink1'), false);
await expect('내 컬렉션 읽기', get(A, 'users/alice/ownedInks/ink1'), true);
await expect('내 컬렉션 삭제', del(A, 'users/alice/ownedInks/ink1'), true);

const req = { uid: 'alice', brand: '', name: '없는 잉크', status: 'pending' };
await expect('새 잉크 요청 생성', commit(A, 'inkRequests/r1', req, { serverTs: ['createdAt'] }), true);
await expect('요청: 다른 uid 명의', commit(B, 'inkRequests/r2', req, { serverTs: ['createdAt'] }), false);
await expect('요청: status 조작', commit(A, 'inkRequests/r3', { ...req, status: 'approved' }, { serverTs: ['createdAt'] }), false);
await expect('요청: 빈 이름', commit(A, 'inkRequests/r4', { ...req, name: '' }, { serverTs: ['createdAt'] }), false);
await expect('요청 본인 읽기', get(A, 'inkRequests/r1'), true);
await expect('요청 남이 읽기', get(B, 'inkRequests/r1'), false);
await expect('요청 수정', commit(A, 'inkRequests/r1', req, { serverTs: ['createdAt'], exists: true }), false);
await expect('요청 삭제', del(A, 'inkRequests/r1'), false);
await expect('비로그인 요청 생성', commit('x', 'inkRequests/r5', req, { serverTs: ['createdAt'] }), false);

console.log(fail === 0 ? 'ALL PASS' : `${fail} FAILED`);
process.exit(fail === 0 ? 0 : 1);
