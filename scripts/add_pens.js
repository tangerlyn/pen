// 만년필 아카이브에 대표 모델을 추가한다. 이름은 한국어 표기, 영어 원문은 *En 필드에.
//
//   node add_pens.js          → 추가될 목록만 출력 (아무것도 안 씀)
//   node add_pens.js --apply  → 실제로 추가
//
// 이미 같은 브랜드·모델(영어 표기 기준)이 있으면 건너뛴다. 여러 번 실행해도 안전.
// 가격대는 국내 정가·일반 판매가 기준 대략값이다(시기·판매처마다 다름).
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const APPLY = process.argv.includes('--apply');

const CC = '카트리지·컨버터';
const CART = '카트리지';
const PISTON = '피스톤필러';
const VAC = '진공';
const EYE = '아이드로퍼';
const GOLD = '금닙';
const STEEL = '스틸닙';

// [brand, brandEn, modelName, modelNameEn, lineup, lineupEn, nibSizes, nibMaterial, fillType, priceRange]
const PENS = [
  // 펠리칸
  ['펠리칸', 'Pelikan', 'M200', 'M200', '클래식', 'Classic', 'EF|F|M|B', STEEL, PISTON, '15~25만원'],
  ['펠리칸', 'Pelikan', 'M205', 'M205', '클래식', 'Classic', 'EF|F|M|B', STEEL, PISTON, '15~25만원'],
  ['펠리칸', 'Pelikan', 'M400', 'M400', '수버렌', 'Souveran', 'EF|F|M|B', GOLD, PISTON, '40~60만원'],
  ['펠리칸', 'Pelikan', 'M600', 'M600', '수버렌', 'Souveran', 'EF|F|M|B', GOLD, PISTON, '50~70만원'],
  ['펠리칸', 'Pelikan', 'M805', 'M805', '수버렌', 'Souveran', 'EF|F|M|B|BB', GOLD, PISTON, '60~90만원'],
  ['펠리칸', 'Pelikan', 'M1000', 'M1000', '수버렌', 'Souveran', 'EF|F|M|B|BB', GOLD, PISTON, '80~120만원'],
  // 파일럿
  ['파일럿', 'Pilot', '커스텀 74', 'Custom 74', '', '', 'EF|F|M|B', GOLD, CC, '15~20만원'],
  ['파일럿', 'Pilot', '커스텀 742', 'Custom 742', '', '', 'EF|F|M|B', GOLD, CC, '20~30만원'],
  ['파일럿', 'Pilot', '커스텀 743', 'Custom 743', '', '', 'EF|F|M|B', GOLD, CC, '25~35만원'],
  ['파일럿', 'Pilot', '커스텀 823', 'Custom 823', '', '', 'F|M|B', GOLD, VAC, '30~40만원'],
  ['파일럿', 'Pilot', '캡리스', 'Capless', '', '', 'EF|F|M|B', GOLD, CC, '20~30만원'],
  ['파일럿', 'Pilot', '프레라', 'Prera', '', '', 'F|M', STEEL, CC, '5~8만원'],
  ['파일럿', 'Pilot', 'E95S', 'E95S', '', '', 'EF|F|M', GOLD, CC, '10~15만원'],
  // 세일러
  ['세일러', 'Sailor', '프로기어', 'Pro Gear', '', '', 'EF|F|MF|M|B', GOLD, CC, '30~45만원'],
  ['세일러', 'Sailor', '1911 스탠다드', '1911 Standard', '', '', 'EF|F|MF|M|B', GOLD, CC, '15~25만원'],
  ['세일러', 'Sailor', '프로핏 주니어', 'Profit Junior', '', '', 'F|M', STEEL, CC, '2~4만원'],
  ['세일러', 'Sailor', '후데 만넨', 'Fude de Mannen', '', '', '40도|55도', STEEL, CC, '1~3만원'],
  // 플래티넘
  ['플래티넘', 'Platinum', '프로키온', 'Procyon', '', '', 'EF|F|M', STEEL, CC, '5~8만원'],
  ['플래티넘', 'Platinum', '플레지르', 'Plaisir', '', '', 'F|M', STEEL, CC, '2~3만원'],
  ['플래티넘', 'Platinum', '큐리다스', 'Curidas', '', '', 'EF|F|M', STEEL, CC, '5~8만원'],
  // 라미
  ['라미', 'LAMY', '알스타', 'AL-star', '', '', 'EF|F|M|B', STEEL, CC, '4~6만원'],
  ['라미', 'LAMY', '비스타', 'Vista', '', '', 'EF|F|M|B', STEEL, CC, '3~5만원'],
  ['라미', 'LAMY', '스튜디오', 'Studio', '', '', 'EF|F|M|B', STEEL, CC, '10~15만원'],
  ['라미', 'LAMY', '아이온', 'Aion', '', '', 'EF|F|M|B', STEEL, CC, '10~15만원'],
  ['라미', 'LAMY', '다이얼로그 3', 'Dialog 3', '', '', 'EF|F|M|B', GOLD, CC, '50~70만원'],
  ['라미', 'LAMY', '조이', 'Joy', '', '', '1.1|1.5|1.9', STEEL, CC, '3~5만원'],
  // 트위스비
  ['트위스비', 'TWSBI', '바쿰 700R', 'Vac 700R', '', '', 'EF|F|M|B|1.1', STEEL, VAC, '8~12만원'],
  ['트위스비', 'TWSBI', '스와이프', 'Swipe', '', '', 'EF|F|M|B', STEEL, CC, '4~6만원'],
  ['트위스비', 'TWSBI', '다이아몬드 미니', 'Diamond Mini', '', '', 'EF|F|M|B', STEEL, PISTON, '7~10만원'],
  // 카웨코
  ['카웨코', 'Kaweco', 'AL 스포츠', 'AL Sport', '', '', 'EF|F|M|B', STEEL, CART, '8~12만원'],
  ['카웨코', 'Kaweco', '릴리풋', 'Liliput', '', '', 'EF|F|M|B', STEEL, CART, '6~10만원'],
  ['카웨코', 'Kaweco', '스튜던트', 'Student', '', '', 'EF|F|M|B', STEEL, CC, '7~10만원'],
  // 몽블랑
  ['몽블랑', 'Montblanc', '145', '145', '마이스터스튁', 'Meisterstück', 'EF|F|M|B', GOLD, CC, '90~120만원'],
  // 파커
  ['파커', 'Parker', '소네트', 'Sonnet', '', '', 'F|M', STEEL, CC, '15~30만원'],
  ['파커', 'Parker', 'IM', 'IM', '', '', 'F|M', STEEL, CC, '5~8만원'],
  ['파커', 'Parker', '조터', 'Jotter', '', '', 'M', STEEL, CART, '2~4만원'],
  ['파커', 'Parker', '듀오폴드', 'Duofold', '', '', 'F|M|B', GOLD, CC, '80~120만원'],
  // 워터맨
  ['워터맨', 'Waterman', '헤미스피어', 'Hémisphère', '', '', 'F|M', STEEL, CC, '10~20만원'],
  ['워터맨', 'Waterman', '엑스퍼트', 'Expert', '', '', 'F|M', STEEL, CC, '15~25만원'],
  ['워터맨', 'Waterman', '카렌', 'Carène', '', '', 'F|M', GOLD, CC, '30~45만원'],
  // 파버카스텔
  ['파버카스텔', 'Faber-Castell', '이모션', 'e-motion', '', '', 'EF|F|M|B', STEEL, CC, '15~20만원'],
  ['파버카스텔', 'Faber-Castell', '그립 2011', 'Grip 2011', '', '', 'EF|F|M', STEEL, CC, '3~5만원'],
  // 오로라
  ['오로라', 'Aurora', '88', '88', '', '', 'EF|F|M|B', GOLD, PISTON, '60~80만원'],
  // 기타
  ['오퍼스 88', 'Opus 88', '콜로로', 'Koloro', '', '', 'EF|F|M', STEEL, EYE, '10~15만원'],
  ['에스터브룩', 'Esterbrook', '에스티', 'Estie', '', '', 'EF|F|M|B', STEEL, CC, '25~35만원'],
  ['디플로마트', 'Diplomat', '에어로', 'Aero', '', '', 'EF|F|M|B', STEEL, CC, '15~25만원'],
  ['레오나르도', 'Leonardo', '모멘토 제로', 'Momento Zero', '', '', 'EF|F|M|B', STEEL, CC, '20~30만원'],
  ['마존', 'Majohn', 'A1', 'A1', '', '', 'EF|F', STEEL, CC, '3~5만원'],
  ['진하오', 'Jinhao', 'X450', 'X450', '', '', 'F|M', STEEL, CC, '1만원 이하'],
  ['진하오', 'Jinhao', '82', '82', '', '', 'EF|F|M', STEEL, CC, '1만원 이하'],
];

const norm = (s) => (s || '').trim().replace(/\s+/g, ' ').toLowerCase();

async function main() {
  const snap = await db.collection('pens').get();
  const existing = new Set();
  let maxNum = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    existing.add(`${norm(d.brandEn || d.brand)}|${norm(d.modelNameEn || d.modelName)}`);
    const m = /^pen_(\d+)$/.exec(doc.id);
    if (m) maxNum = Math.max(maxNum, Number(m[1]));
  }

  let added = 0;
  let skipped = 0;
  const batch = db.batch();
  for (const [brand, brandEn, modelName, modelNameEn, lineup, lineupEn, nibs, nibMaterial, fillType, priceRange] of PENS) {
    const key = `${norm(brandEn)}|${norm(modelNameEn)}`;
    if (existing.has(key)) {
      skipped++;
      continue;
    }
    existing.add(key);
    const id = `pen_${String(++maxNum).padStart(3, '0')}`;
    const doc = {
      id,
      brand,
      brandEn,
      modelName,
      modelNameEn,
      lineup,
      nibSizes: nibs.split('|'),
      nibMaterial,
      fillType,
      priceRange,
    };
    if (lineupEn) doc.lineupEn = lineupEn;
    console.log(`${id}: ${brand} ${modelName}${lineup ? ` (${lineup})` : ''} — ${nibMaterial}, ${fillType}, ${priceRange}`);
    if (APPLY) batch.set(db.collection('pens').doc(id), doc);
    added++;
  }
  if (APPLY && added) await batch.commit();
  console.log(`\n${added}개 ${APPLY ? '추가 완료' : '추가 예정 (반영하려면 --apply)'}, 이미 있어서 건너뜀 ${skipped}개`);
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
