// 보안 3단계 마무리: 예전 카카오·네이버 로그인 계정의 비밀번호를 아무도 모르는
// 무작위 값으로 바꾼다. 예전 비밀번호는 sha256(소셜ID + 앱에 박힌 salt)라 salt를
// 꺼낸 사람이 계산할 수 있었다. 새 앱은 서버 검증(socialLogin 함수) → 커스텀
// 토큰으로 로그인하므로 비밀번호가 필요 없다.
//
// ⚠️ 반드시 강제 업데이트(Remote Config min_version) 이후에 실행할 것.
//    옛 앱은 이 비밀번호로 로그인하므로, 실행하면 옛 앱 사용자는 로그인할 수 없다.
//    (비밀번호 제공자를 "해제"하지 않고 값만 바꾸는 이유: 계정 이메일을 유지해야
//     socialLogin이 이메일로 기존 uid를 찾을 수 있다.)
// 실행 후 Firebase 콘솔 > Authentication > 로그인 방법에서 "이메일/비밀번호"를 끈다.
//
//   node rotate_legacy_social_passwords.js          # dry-run
//   node rotate_legacy_social_passwords.js --apply  # 실제 반영
const crypto = require('crypto');
const admin = require('firebase-admin');

if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-mannti' });
} else {
  admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
}

const APPLY = process.argv.includes('--apply');

// 비밀번호 로그인만 가진 계정 = 예전 카카오/네이버 방식으로 만든 계정
// (애플은 apple.com 제공자를 가지고, 새 방식 계정은 제공자가 없다)
function isLegacySocialAccount(user) {
  return user.providerData.length > 0
    && user.providerData.every((p) => p.providerId === 'password');
}

async function main() {
  console.log(APPLY ? '[APPLY] 실제로 반영합니다' : '[DRY-RUN] --apply 없이 실행 — 아무것도 바꾸지 않습니다');
  let pageToken;
  let total = 0;
  const targets = [];
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    total += page.users.length;
    targets.push(...page.users.filter(isLegacySocialAccount));
    pageToken = page.pageToken;
  } while (pageToken);

  const synthetic = targets.filter((u) => u.email?.endsWith('@nibpen.login')).length;
  console.log(`대상 ${targets.length}명 / 전체 ${total}명 (가상 이메일 ${synthetic}, 네이버 실제 이메일 ${targets.length - synthetic})`);
  for (const u of targets) console.log(`  ${u.uid}  ${u.email ?? '(이메일 없음)'}`);
  if (!APPLY) return;

  let failed = 0;
  for (const u of targets) {
    try {
      await admin.auth().updateUser(u.uid, { password: crypto.randomBytes(32).toString('base64url') });
    } catch (e) {
      failed++;
      console.error(`실패 ${u.uid}:`, e.message);
    }
  }
  console.log(`완료: ${targets.length - failed}명 변경, 실패 ${failed}명`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
