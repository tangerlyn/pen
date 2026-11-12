// socialLogin 단위 테스트 — 카카오/네이버 API와 Firebase Auth는 가짜로 대체.
// 실행: cd functions && node --test test/
const { test } = require("node:test");
const assert = require("node:assert");
const { socialLogin } = require("../social_login");

const KAKAO_APP_ID = "1234";

function fakeFetch(routes) {
  const calls = [];
  const fn = async (url, opts) => {
    calls.push({ url, auth: opts.headers.Authorization });
    const r = routes[url];
    if (!r) throw new Error(`unexpected url ${url}`);
    return { status: r.status ?? 200, ok: (r.status ?? 200) < 400, json: async () => r.body };
  };
  fn.calls = calls;
  return fn;
}

const kakaoInfo = (body, status) => ({
  "https://kapi.kakao.com/v1/user/access_token_info": { body, status },
});
const naverMe = (body, status) => ({
  "https://openapi.naver.com/v1/nid/me": { body, status },
});

function fakeAuth(usersByEmail = {}) {
  return {
    issued: [],
    async getUserByEmail(email) {
      const u = usersByEmail[email];
      if (!u) {
        const e = new Error("not found");
        e.code = "auth/user-not-found";
        throw e;
      }
      return u;
    },
    async createCustomToken(uid, claims) {
      this.issued.push({ uid, claims });
      return `token-for-${uid}`;
    },
  };
}

const legacy = (uid, providers = ["password"]) => ({
  uid, providerData: providers.map((providerId) => ({ providerId })),
});

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (e) => e.code === code || assert.fail(`expected ${code}, got ${e.code}: ${e.message}`));
}

// ── 카카오 ──────────────────────────────────────────────────────────────
test("카카오: 기존(가상 이메일) 계정은 같은 uid로 로그인", async () => {
  const fetchFn = fakeFetch(kakaoInfo({ id: 42, expires_in: 100, app_id: 1234 }));
  const auth = fakeAuth({ "kakao_42@nibpen.login": legacy("OLD_UID") });
  const res = await socialLogin({ provider: "kakao", accessToken: "tok" }, { fetchFn, auth, kakaoAppId: KAKAO_APP_ID });
  assert.deepStrictEqual(res, { token: "token-for-OLD_UID", email: null });
  assert.strictEqual(fetchFn.calls[0].auth, "Bearer tok");
});

test("카카오: 신규 사용자는 kakao:<id> uid", async () => {
  const auth = fakeAuth();
  const res = await socialLogin({ provider: "kakao", accessToken: "tok" },
    { fetchFn: fakeFetch(kakaoInfo({ id: 7, app_id: 1234 })), auth, kakaoAppId: KAKAO_APP_ID });
  assert.strictEqual(res.token, "token-for-kakao:7");
  assert.deepStrictEqual(auth.issued[0].claims, { provider: "kakao" });
});

test("카카오: 비밀번호 제공자를 해제한 기존 계정(providerData 비어 있음)도 같은 uid", async () => {
  const auth = fakeAuth({ "kakao_42@nibpen.login": legacy("OLD_UID", []) });
  const res = await socialLogin({ provider: "kakao", accessToken: "tok" },
    { fetchFn: fakeFetch(kakaoInfo({ id: 42, app_id: 1234 })), auth, kakaoAppId: KAKAO_APP_ID });
  assert.strictEqual(res.token, "token-for-OLD_UID");
});

test("[공격] 카카오: 다른 앱에서 발급된 토큰 거부", async () => {
  const auth = fakeAuth({ "kakao_42@nibpen.login": legacy("OLD_UID") });
  await rejectsWith(socialLogin({ provider: "kakao", accessToken: "tok" },
    { fetchFn: fakeFetch(kakaoInfo({ id: 42, app_id: 9999 })), auth, kakaoAppId: KAKAO_APP_ID }), "permission-denied");
  assert.strictEqual(auth.issued.length, 0);
});

test("[공격] 카카오: 위조·만료 토큰(401) 거부", async () => {
  const auth = fakeAuth();
  await rejectsWith(socialLogin({ provider: "kakao", accessToken: "bad" },
    { fetchFn: fakeFetch(kakaoInfo({ code: -401 }, 401)), auth, kakaoAppId: KAKAO_APP_ID }), "unauthenticated");
  assert.strictEqual(auth.issued.length, 0);
});

test("카카오: KAKAO_APP_ID 미설정이면 토큰을 발급하지 않음", async () => {
  await rejectsWith(socialLogin({ provider: "kakao", accessToken: "tok" },
    { fetchFn: fakeFetch(kakaoInfo({ id: 1, app_id: 1234 })), auth: fakeAuth(), kakaoAppId: "" }), "failed-precondition");
});

// ── 네이버 ──────────────────────────────────────────────────────────────
test("네이버: 실제 이메일로 가입한 기존 계정은 같은 uid, 이메일 반환", async () => {
  const auth = fakeAuth({ "me@naver.com": legacy("NAVER_OLD") });
  const res = await socialLogin({ provider: "naver", accessToken: "tok" },
    { fetchFn: fakeFetch(naverMe({ resultcode: "00", response: { id: "abc", email: "me@naver.com" } })), auth });
  assert.deepStrictEqual(res, { token: "token-for-NAVER_OLD", email: "me@naver.com" });
});

test("네이버: 이메일 없이 가입한 기존 계정은 가상 이메일로 찾음", async () => {
  const auth = fakeAuth({ "naver_abc@nibpen.login": legacy("NAVER_OLD2") });
  const res = await socialLogin({ provider: "naver", accessToken: "tok" },
    { fetchFn: fakeFetch(naverMe({ resultcode: "00", response: { id: "abc" } })), auth });
  assert.deepStrictEqual(res, { token: "token-for-NAVER_OLD2", email: null });
});

test("[공격] 네이버: 같은 이메일의 애플 계정은 넘겨주지 않고 새 uid", async () => {
  const auth = fakeAuth({ "me@naver.com": legacy("APPLE_USER", ["apple.com"]) });
  const res = await socialLogin({ provider: "naver", accessToken: "tok" },
    { fetchFn: fakeFetch(naverMe({ resultcode: "00", response: { id: "abc", email: "me@naver.com" } })), auth });
  assert.strictEqual(res.token, "token-for-naver:abc");
});

test("[공격] 네이버: 실패 응답 거부", async () => {
  await rejectsWith(socialLogin({ provider: "naver", accessToken: "bad" },
    { fetchFn: fakeFetch(naverMe({ resultcode: "024", message: "Authentication failed" }, 401)), auth: fakeAuth() }), "unauthenticated");
  await rejectsWith(socialLogin({ provider: "naver", accessToken: "bad" },
    { fetchFn: fakeFetch(naverMe({ resultcode: "024" })), auth: fakeAuth() }), "unauthenticated");
});

// ── 입력 검증 ───────────────────────────────────────────────────────────
test("잘못된 입력 거부", async () => {
  const deps = { fetchFn: fakeFetch({}), auth: fakeAuth(), kakaoAppId: KAKAO_APP_ID };
  await rejectsWith(socialLogin({ provider: "kakao" }, deps), "invalid-argument");
  await rejectsWith(socialLogin({ provider: "google", accessToken: "t" }, deps), "invalid-argument");
  await rejectsWith(socialLogin(null, deps), "invalid-argument");
  await rejectsWith(socialLogin({ provider: "kakao", accessToken: "x".repeat(5000) }, deps), "invalid-argument");
});

test("소셜 서버 연결 실패는 unavailable", async () => {
  const fetchFn = async () => { throw new Error("ECONNRESET"); };
  await rejectsWith(socialLogin({ provider: "kakao", accessToken: "t" },
    { fetchFn, auth: fakeAuth(), kakaoAppId: KAKAO_APP_ID }), "unavailable");
});
