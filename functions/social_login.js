// 카카오·네이버 로그인을 서버에서 검증하고 Firebase 커스텀 토큰을 발급한다.
//
// 예전 방식: 앱이 sha256(소셜ID + 앱에 박힌 salt)를 비밀번호로 Firebase
// 이메일/비밀번호 로그인을 했다. salt는 앱을 디컴파일하면 꺼낼 수 있어서
// 소셜 ID만 알면 남의 계정으로 로그인할 수 있었다.
// 새 방식: 앱은 카카오/네이버가 발급한 액세스 토큰만 보내고, 서버가 그 토큰으로
// 카카오/네이버 API를 호출해 실제 사용자 ID를 얻은 뒤에만 토큰을 발급한다.
const { HttpsError } = require("firebase-functions/v2/https");

const KAKAO_TOKEN_INFO_URL = "https://kapi.kakao.com/v1/user/access_token_info";
const NAVER_PROFILE_URL = "https://openapi.naver.com/v1/nid/me";

async function getJson(fetchFn, url, accessToken) {
  let res;
  try {
    res = await fetchFn(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  } catch (e) {
    throw new HttpsError("unavailable", "소셜 로그인 서버에 연결할 수 없습니다.");
  }
  if (res.status === 401 || res.status === 403) {
    throw new HttpsError("unauthenticated", "유효하지 않은 소셜 로그인 토큰입니다.");
  }
  if (!res.ok) {
    throw new HttpsError("unavailable", `소셜 로그인 서버 오류 (${res.status})`);
  }
  return res.json();
}

// 카카오 access_token_info 응답: { id: 회원번호, expires_in, app_id: 토큰이 발급된 앱 ID }
// app_id를 확인해야 다른 앱(예: 공격자가 만든 앱)에서 발급받은 사용자 토큰을
// 우리 서버에 들이밀어 그 사용자로 로그인하는 걸 막을 수 있다.
async function verifyKakao(accessToken, { fetchFn, kakaoAppId }) {
  if (!kakaoAppId) {
    throw new HttpsError("failed-precondition", "KAKAO_APP_ID가 설정되지 않았습니다.");
  }
  const info = await getJson(fetchFn, KAKAO_TOKEN_INFO_URL, accessToken);
  if (info.id == null) {
    throw new HttpsError("unauthenticated", "카카오 사용자 정보를 확인할 수 없습니다.");
  }
  if (String(info.app_id) !== String(kakaoAppId)) {
    throw new HttpsError("permission-denied", "다른 앱에서 발급된 카카오 토큰입니다.");
  }
  const id = String(info.id);
  return { provider: "kakao", id, email: null, legacyEmails: [`kakao_${id}@nibpen.login`] };
}

// 네이버 nid/me 응답: { resultcode: "00", response: { id, email, ... } }
// 주의: 토큰이 우리 앱에서 발급됐는지(client_id) 확인하는 방법은 문서로 확인하지
// 못했다 — tasks/todo.md 3단계 참고.
async function verifyNaver(accessToken, { fetchFn }) {
  const body = await getJson(fetchFn, NAVER_PROFILE_URL, accessToken);
  const id = body?.response?.id;
  if (body?.resultcode !== "00" || !id) {
    throw new HttpsError("unauthenticated", "네이버 사용자 정보를 확인할 수 없습니다.");
  }
  const email = typeof body.response.email === "string" && body.response.email ?
    body.response.email : null;
  // 예전 앱은 네이버 이메일이 있으면 그걸, 없으면 가상 이메일을 계정 이메일로 썼다
  const legacyEmails = [email, `naver_${id}@nibpen.login`].filter(Boolean);
  return { provider: "naver", id: String(id), email, legacyEmails };
}

// 예전 방식으로 가입한 사용자는 같은 uid를 그대로 쓰게 이메일로 찾는다.
// 찾은 계정에 비밀번호 외 로그인 수단(애플 등)이 있으면 예전 방식 계정이 아니므로
// 매칭하지 않는다 — 이메일이 같다는 이유로 남의 계정을 넘겨주지 않기 위해서.
// (나중에 비밀번호 제공자를 해제하면 providerData가 비게 되는데, 그 경우도 매칭)
async function resolveUid(profile, auth) {
  for (const email of profile.legacyEmails) {
    try {
      const user = await auth.getUserByEmail(email);
      const onlyPassword = user.providerData.every((p) => p.providerId === "password");
      if (onlyPassword) return user.uid;
    } catch (e) {
      if (e?.code !== "auth/user-not-found") throw e;
    }
  }
  return `${profile.provider}:${profile.id}`;
}

async function socialLogin(data, { fetchFn, auth, kakaoAppId }) {
  const { provider, accessToken } = data ?? {};
  if (typeof accessToken !== "string" || accessToken.length === 0 || accessToken.length > 4096) {
    throw new HttpsError("invalid-argument", "accessToken이 필요합니다.");
  }
  let profile;
  if (provider === "kakao") {
    profile = await verifyKakao(accessToken, { fetchFn, kakaoAppId });
  } else if (provider === "naver") {
    profile = await verifyNaver(accessToken, { fetchFn });
  } else {
    throw new HttpsError("invalid-argument", "지원하지 않는 로그인 방식입니다.");
  }
  const uid = await resolveUid(profile, auth);
  const token = await auth.createCustomToken(uid, { provider: profile.provider });
  return { token, email: profile.email };
}

module.exports = { socialLogin };
