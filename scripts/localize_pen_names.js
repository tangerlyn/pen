// 만년필 아카이브의 브랜드·모델명을 한국어 표기로 바꾼다.
// 원래 영어 표기는 brandEn / modelNameEn / lineupEn에 남겨 영어 검색도 계속 되게 한다.
//
//   node localize_pen_names.js          → 바뀔 내용만 출력 (아무것도 안 씀)
//   node localize_pen_names.js --apply  → 실제로 반영
//
// 여러 번 실행해도 안전하다: 이미 brandEn이 있는 문서는 영어 원문을 덮어쓰지 않는다.
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

// 영어 표기(소문자 비교) → 한국어 표기
const BRANDS = {
  'pilot': '파일럿',
  'namiki': '나미키',
  'lamy': '라미',
  'pelikan': '펠리칸',
  'sailor': '세일러',
  'kaweco': '카웨코',
  'twsbi': '트위스비',
  'platinum': '플래티넘',
  'montblanc': '몽블랑',
  'mont blanc': '몽블랑',
  'aurora': '오로라',
  'visconti': '비스콘티',
  'faber-castell': '파버카스텔',
  'graf von faber-castell': '그라프 폰 파버카스텔',
  'parker': '파커',
  'waterman': '워터맨',
  'cross': '크로스',
  'sheaffer': '쉐퍼',
  'nakaya': '나카야',
  'leonardo': '레오나르도',
  'leonardo officina italiana': '레오나르도',
  'montegrappa': '몬테그라파',
  'opus 88': '오퍼스 88',
  'esterbrook': '에스터브룩',
  'diplomat': '디플로마트',
  'otto hutt': '오토 후트',
  'conklin': '콘클린',
  'jinhao': '진하오',
  'moonman': '문맨',
  'majohn': '마존',
  'hongdian': '홍디안',
  'kaco': '카코',
  'monteverde': '몬테베르데',
  'retro 51': '레트로 51',
  'benu': '베누',
  'scribo': '스크리보',
  'omas': '오마스',
  'delta': '델타',
  'stipula': '스티풀라',
  'caran d\'ache': '까렌다쉬',
  's.t. dupont': '에스티 듀퐁',
  'cartier': '까르띠에',
};

// 모델명 — 숫자만 있는 모델(149, 146, 2000)은 그대로 둔다.
const MODELS = {
  'custom heritage 92': '커스텀 헤리티지 92',
  'safari': '사파리',
  'pro gear slim': '프로기어 슬림',
  'sport': '스포츠',
  'kakuno': '카쿠노',
  'metropolitan': '메트로폴리탄',
  'eco': '에코',
  'diamond 580': '다이아몬드 580',
  '1911 large': '1911 라지',
  'century 3776': '센츄리 3776',
  'preppy': '프레피',
  'falcon': '팔콘',
  'optima': '옵티마',
  'homo sapiens': '호모 사피엔스',
  'loom': '룸',
  'ambition': '앰비션',
};

const LINEUPS = {
  'souveran': '수버렌',
  'meisterstück': '마이스터스튁',
  'meisterstuck': '마이스터스튁',
  'opera': '오페라',
};

const ko = (map, v) => map[(v || '').trim().toLowerCase()];

async function main() {
  const snap = await db.collection('pens').get();
  let changed = 0;
  const unknownBrands = new Set();
  let batch = db.batch();
  let ops = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    // 이미 바꾼 문서면 영어 원문은 *En 필드에 있다.
    const brandEn = d.brandEn || d.brand || '';
    const modelEn = d.modelNameEn || d.modelName || '';
    const lineupEn = d.lineupEn || d.lineup || '';

    const brandKo = ko(BRANDS, brandEn);
    const modelKo = ko(MODELS, modelEn);
    const lineupKo = ko(LINEUPS, lineupEn);
    if (!brandKo && /[a-z]/i.test(brandEn)) unknownBrands.add(brandEn);

    const update = {};
    if (brandKo && d.brand !== brandKo) update.brand = brandKo;
    if (modelKo && d.modelName !== modelKo) update.modelName = modelKo;
    if (lineupKo && d.lineup !== lineupKo) update.lineup = lineupKo;
    if (Object.keys(update).length === 0) continue;
    if (!d.brandEn) update.brandEn = brandEn;
    if (!d.modelNameEn) update.modelNameEn = modelEn;
    if (lineupEn && !d.lineupEn) update.lineupEn = lineupEn;

    changed++;
    console.log(
      `${doc.id}: ${brandEn} ${modelEn}${lineupEn ? ` (${lineupEn})` : ''}` +
        `  →  ${update.brand || d.brand} ${update.modelName || d.modelName}` +
        `${update.lineup ? ` (${update.lineup})` : ''}`,
    );
    if (APPLY) {
      batch.update(doc.ref, update);
      if (++ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
  }
  if (APPLY && ops > 0) await batch.commit();

  console.log(`\n전체 ${snap.size}개 중 ${changed}개 ${APPLY ? '반영 완료' : '변경 예정 (반영하려면 --apply)'}`);
  if (unknownBrands.size) {
    console.log(`한국어 표기가 없는 브랜드 (그대로 둠): ${[...unknownBrands].join(', ')}`);
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
