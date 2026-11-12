// Storage 보안 규칙 테스트. 실행: npm run emu
const { test, before, beforeEach, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, deleteObject, getBytes } = require('firebase/storage');

let env;
const A = 'alice';
const B = 'bob';
const img = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
const jpeg = (uploader) => ({
  contentType: 'image/jpeg',
  ...(uploader ? { customMetadata: { uploader } } : {}),
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mannti',
    storage: {
      rules: fs.readFileSync(process.env.STORAGE_RULES || path.join(__dirname, '..', 'storage.rules'), 'utf8'),
    },
  });
});

after(async () => env.cleanup());

const st = (uid) => env.authenticatedContext(uid).storage();

beforeEach(async () => {
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = ctx.storage();
    await uploadBytes(ref(s, 'reviews/a_new.jpg'), img, jpeg(A));
    await uploadBytes(ref(s, 'reviews/legacy.jpg'), img, jpeg());
    await uploadBytes(ref(s, 'posts/a_post.jpg'), img, jpeg(A));
  });
});

// ── 정상 동작 ─────────────────────────────────────────────────────────
test('리뷰/게시글 이미지 업로드 (새 앱: uploader 포함, 옛 앱: 없음)', async () => {
  await assertSucceeds(uploadBytes(ref(st(A), 'reviews/1_x.jpg'), img, jpeg(A)));
  await assertSucceeds(uploadBytes(ref(st(A), 'posts/1_x.jpg'), img, jpeg()));
  await assertSucceeds(getBytes(ref(st(B), 'reviews/a_new.jpg')));
});

test('업로더 본인이 리뷰/게시글 이미지 삭제', async () => {
  await assertSucceeds(deleteObject(ref(st(A), 'reviews/a_new.jpg')));
  await assertSucceeds(deleteObject(ref(st(A), 'posts/a_post.jpg')));
});

test('프로필·잉크차트·만년필 사진 본인 경로 업로드/교체/삭제', async () => {
  for (const p of [`profiles/${A}/1.jpg`, `inkChart/${A}/1.jpg`, `pens/${A}/1.jpg`]) {
    await assertSucceeds(uploadBytes(ref(st(A), p), img, jpeg(A)));
    await assertSucceeds(uploadBytes(ref(st(A), p), img, jpeg(A)));
    await assertSucceeds(deleteObject(ref(st(A), p)));
  }
});

// ── 공격 ─────────────────────────────────────────────────────────────
test('[공격] 남의 리뷰 이미지 덮어쓰기·삭제', async () => {
  await assertFails(uploadBytes(ref(st(B), 'reviews/a_new.jpg'), img, jpeg(B)));
  await assertFails(deleteObject(ref(st(B), 'reviews/a_new.jpg')));
  await assertFails(deleteObject(ref(st(B), 'posts/a_post.jpg')));
  await assertFails(deleteObject(ref(st(B), 'reviews/legacy.jpg')));
});

test('[공격] 업로더 위조', async () => {
  await assertFails(uploadBytes(ref(st(B), 'reviews/fake.jpg'), img, jpeg(A)));
});

test('[공격] 이미지가 아닌 파일·15MB 이상 업로드', async () => {
  await assertFails(uploadBytes(ref(st(A), 'reviews/x.apk'), img, { contentType: 'application/octet-stream' }));
  const big = new Uint8Array(15 * 1024 * 1024);
  await assertFails(uploadBytes(ref(st(A), 'reviews/big.jpg'), big, jpeg(A)));
  await assertFails(uploadBytes(ref(st(A), `profiles/${A}/big.jpg`), big, jpeg(A)));
});

test('[공격] 남의 프로필 경로 업로드, 비로그인 읽기', async () => {
  await assertFails(uploadBytes(ref(st(B), `profiles/${A}/1.jpg`), img, jpeg(B)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'reviews/a_new.jpg')));
});

test('[공격] 규칙에 없는 경로', async () => {
  await assertFails(uploadBytes(ref(st(A), 'listings/1.jpg'), img, jpeg(A)));
  await assertFails(uploadBytes(ref(st(A), 'random.jpg'), img, jpeg(A)));
});
