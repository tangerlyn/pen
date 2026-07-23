/**
 * 잉크 스와치 사진에서 대표 색상(hexColor)을 자동으로 뽑아 assets/info_csv/inks.csv에 채워 넣는 스크립트.
 *
 * 배경: 브랜드 공식 사이트의 "컬러차트" 페이지에는 잉크마다 이름 + 워터컬러 번짐 스와치 사진이 있는데,
 * 이 사진에서 흰 종이 배경/캡션 텍스트를 제외한 "잉크" 픽셀만 골라 대표색 하나를 계산한다.
 *
 * 구성 (두 단계로 분리됨 — 이유는 아래 참고):
 *   1) scrape : 특정 브랜드 사이트를 파싱해서 [{title, thumbUrl}, ...] 목록을 JSON으로 저장.
 *      → 사이트마다 HTML 구조가 다르므로, 새 브랜드를 추가할 때는 이 단계의 파서만 새로 작성하면 됨.
 *        (지금 들어있는 파서는 글입다 wearingeul.kr의 imweb 갤러리 위젯 구조 전용)
 *   2) apply : items.json + inks.csv를 이름으로 매칭해서 이미지를 내려받고 색을 추출, CSV에 반영.
 *      → 이 단계는 브랜드와 무관하게 재사용 가능한 부분.
 *
 * 사용 예:
 *   node extract_ink_colors.js scrape wearingeul https://wearingeul.kr/colorchart items_wearingeul.json
 *   node extract_ink_colors.js apply items_wearingeul.json ../assets/info_csv/inks.csv 글입다
 *
 * 펄/쉰(shimmer/sheen) 타입 잉크는 반짝이·테 효과가 베이스 잉크보다 채도가 높아서
 * 기본 알고리즘(채도 우선)이 엉뚱한 색을 고를 수 있다. 이런 잉크는 --overrides로
 * 실제 색 계열(hue 범위)을 직접 지정해서 보정한다. 아래 OVERRIDES_EXAMPLE 참고.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const csvParser = require('csv-parser');
const { createObjectCsvWriter } = require('csv-writer');
const { Jimp } = require('jimp');

// ── 공통 유틸 ──────────────────────────────────────────────────────────

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchText(res.headers.location).then(resolve, reject);
      }
      if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    }).on('error', reject);
  });
}

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchBuffer(res.headers.location).then(resolve, reject);
      }
      if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject);
  });
}

function readCsv(csvPath) {
  return new Promise((resolve, reject) => {
    const rows = [];
    let header = [];
    fs.createReadStream(csvPath)
      .pipe(csvParser())
      .on('headers', (h) => { header = h; })
      .on('data', (row) => rows.push(row))
      .on('end', () => resolve({ header, rows }))
      .on('error', reject);
  });
}

async function writeCsv(csvPath, header, rows) {
  const writer = createObjectCsvWriter({
    path: csvPath,
    header: header.map((h) => ({ id: h, title: h })),
  });
  await writer.writeRecords(rows);
}

// ── 1단계: 사이트별 스크래퍼 ───────────────────────────────────────────

/**
 * 글입다(wearingeul.kr) 컬러차트 페이지 전용 파서.
 * imweb 갤러리 위젯(gallery2)의 item_container 블록에서
 * data-bg(썸네일 URL)와 <p class="title">이름<span class="body">부제</span></p> 를 뽑는다.
 */
function parseWearingeulColorchart(html) {
  const itemRe =
    /data-bg="url\(([^)]+)\)"\s+data-src="([^"]+)"[^>]*data-sub-html="#caption_(\d+)"\s+data-no="(\d+)"[^>]*><\/div>\s*<div class="text_wrap[^"]*"[^>]*>\s*<p class="title">([^<]*)<span class="body">([^<]*)<\/span><\/p>/g;

  const items = [];
  let m;
  while ((m = itemRe.exec(html)) !== null) {
    const [, thumbUrl, fullUrl, , no, rawTitle, rawSubtitle] = m;
    items.push({
      no: Number(no),
      title: decodeHtmlEntities(rawTitle).trim(),
      subtitle: decodeHtmlEntities(rawSubtitle).trim(),
      thumbUrl,
      fullUrl,
    });
  }
  items.sort((a, b) => a.no - b.no);
  return items;
}

const SCRAPERS = {
  wearingeul: parseWearingeulColorchart,
  // 새 브랜드를 추가하려면 여기에 사이트 구조에 맞는 파서를 등록한다.
  // 예: naver_blog: parseNaverBlogGallery, brandsite: parseBrandsite, ...
};

function decodeHtmlEntities(s) {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

// ── 2단계: 색상 추출 (브랜드 무관, 재사용 가능) ──────────────────────────

function rgbToHsv(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  const s = max === 0 ? 0 : d / max;
  return [h, s, max];
}

function median(nums) {
  const sorted = [...nums].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

function toHex(r, g, b) {
  const c = (n) => n.toString(16).padStart(2, '0').toUpperCase();
  return `#${c(r)}${c(g)}${c(b)}`;
}

/**
 * 스와치 사진에서 대표 잉크 색을 추출한다.
 *
 * 기본 동작(hueRanges 없음): 흰 배경 제거 후, 채도 높은 상위 satKeep 비율 픽셀의 중앙값.
 * 대부분의 잉크(normal 타입)에 잘 맞는다.
 *
 * hueRanges가 주어지면: 그 색상 범위(+minSat/maxSat) 안의 픽셀만 골라 중앙값을 낸다.
 * 펄/쉰 잉크처럼 반짝이·테 효과가 베이스보다 채도가 높아 기본 동작이 엉뚱한 색을
 * 고를 때, 실제 잉크의 색 계열을 알고 있다면 이 옵션으로 강제 지정한다.
 *   예) hueRanges: [[320,360],[0,20]] → 레드/와인 계열만 추출
 *
 * @param {Buffer} buffer 이미지 바이너리
 * @param {object} opts
 * @param {number} [opts.whiteThresh=232] 이 값 이상인 R,G,B는 흰 배경/텍스트로 간주해 제외
 * @param {number} [opts.sampleSize=160] 리사이즈 크기 (정사각형, 속도용 다운샘플)
 * @param {number} [opts.satKeep=0.45] hueRanges 없을 때, 채도 상위 몇 %를 남길지
 * @param {[number,number][]} [opts.hueRanges] 남길 색상(hue, 0-360) 범위 목록
 * @param {number} [opts.minSat] hueRanges 모드에서 최소 채도
 * @param {number} [opts.maxSat] hueRanges 모드에서 최대 채도 (무채색 계열 필터링용)
 * @returns {Promise<string|null>} '#RRGGBB' 또는 매칭 픽셀이 없으면 null
 */
async function extractInkColor(buffer, opts = {}) {
  const {
    whiteThresh = 232,
    sampleSize = 160,
    satKeep = 0.45,
    hueRanges = null,
    minSat = null,
    maxSat = null,
  } = opts;

  const img = await Jimp.read(buffer);
  img.resize({ w: sampleSize, h: sampleSize });

  const candidates = [];
  img.scan(0, 0, img.bitmap.width, img.bitmap.height, function (x, y, idx) {
    const r = this.bitmap.data[idx];
    const g = this.bitmap.data[idx + 1];
    const b = this.bitmap.data[idx + 2];
    if (r >= whiteThresh && g >= whiteThresh && b >= whiteThresh) return;

    const [h, s] = rgbToHsv(r, g, b);
    if (hueRanges) {
      const inHue = hueRanges.some(([lo, hi]) => h >= lo && h <= hi);
      if (!inHue) return;
      if (minSat != null && s < minSat) return;
      if (maxSat != null && s > maxSat) return;
    } else {
      if (minSat != null && s < minSat) return;
      if (maxSat != null && s > maxSat) return;
    }
    candidates.push({ r, g, b, s });
  });

  if (candidates.length === 0) return null;

  let core = candidates;
  if (!hueRanges) {
    // 채도 우선 모드: 상위 satKeep 비율만 남긴다
    core = [...candidates].sort((a, b) => b.s - a.s);
    core = core.slice(0, Math.max(1, Math.floor(core.length * satKeep)));
  }

  const r = median(core.map((p) => p.r));
  const g = median(core.map((p) => p.g));
  const b = median(core.map((p) => p.b));
  return toHex(r, g, b);
}

// 참고용 — 펄/쉰 오추출 보정에 실제로 사용했던 색 계열 프리셋
const HUE_FAMILY_PRESETS = {
  red: { hueRanges: [[320, 360], [0, 20]], minSat: 0.25 },
  green: { hueRanges: [[70, 170]], minSat: 0.15 },
  blue: { hueRanges: [[195, 255]], minSat: 0.15 },
  purple: { hueRanges: [[260, 320]], minSat: 0.1 },
  gray: { hueRanges: null, maxSat: 0.2 }, // 무채색(검정/회색) 계열
};

// ── CLI ──────────────────────────────────────────────────────────────

async function cmdScrape(siteKey, url, outPath) {
  const scraper = SCRAPERS[siteKey];
  if (!scraper) {
    console.error(`알 수 없는 사이트 키: ${siteKey}. 등록된 파서: ${Object.keys(SCRAPERS).join(', ')}`);
    console.error('새 브랜드는 이 파일의 SCRAPERS에 사이트 구조에 맞는 파서를 추가로 등록해야 합니다.');
    process.exit(1);
  }
  console.log(`페이지 가져오는 중: ${url}`);
  const html = await fetchText(url);
  const items = scraper(html);
  fs.writeFileSync(outPath, JSON.stringify(items, null, 2), 'utf-8');
  console.log(`${items.length}개 항목 추출 → ${outPath}`);
}

async function cmdApply(itemsPath, csvPath, brandFilter, overridesPath) {
  const items = JSON.parse(fs.readFileSync(itemsPath, 'utf-8'));
  const byTitle = new Map(items.map((it) => [it.title, it]));

  const overrides = overridesPath && fs.existsSync(overridesPath)
    ? JSON.parse(fs.readFileSync(overridesPath, 'utf-8')) // { "잉크이름": "red" | "green" | ... }
    : {};

  const { header, rows } = await readCsv(csvPath);

  const targets = rows.filter((r) => (!brandFilter || r.brand === brandFilter) && byTitle.has(r.name.trim()));
  console.log(`매칭된 잉크: ${targets.length} / ${rows.length}행`);

  let updated = 0;
  for (const row of targets) {
    const item = byTitle.get(row.name.trim());
    try {
      const buffer = await fetchBuffer(item.thumbUrl);
      const presetKey = overrides[row.name.trim()];
      const opts = presetKey ? HUE_FAMILY_PRESETS[presetKey] : {};
      if (presetKey && !opts) {
        console.warn(`  ! 알 수 없는 프리셋 "${presetKey}" (${row.name}) — 기본 방식으로 진행`);
      }
      const hex = await extractInkColor(buffer, opts || {});
      if (hex) {
        row.hexColor = hex;
        updated++;
        console.log(`  ${row.id} ${row.name} → ${hex}${presetKey ? ` (${presetKey} 보정)` : ''}`);
      } else {
        console.warn(`  ! 색 추출 실패(매칭 픽셀 없음): ${row.name}`);
      }
    } catch (e) {
      console.warn(`  ! 실패: ${row.name} — ${e.message}`);
    }
  }

  await writeCsv(csvPath, header, rows);
  console.log(`\nCSV 업데이트 완료: ${updated}개 행 (${csvPath})`);

  const unmatched = rows.filter((r) => (!brandFilter || r.brand === brandFilter) && !byTitle.has(r.name.trim()));
  if (unmatched.length) {
    console.log(`\n이름 매칭 안 된 행 ${unmatched.length}개:`);
    unmatched.forEach((r) => console.log(`  ${r.id} ${r.name}`));
  }
}

async function main() {
  const [, , cmd, ...args] = process.argv;

  if (cmd === 'scrape') {
    const [siteKey, url, outPath] = args;
    if (!siteKey || !url || !outPath) {
      console.error('사용법: node extract_ink_colors.js scrape <siteKey> <url> <출력.json>');
      process.exit(1);
    }
    await cmdScrape(siteKey, url, outPath);
  } else if (cmd === 'apply') {
    const [itemsPath, csvPath, brandFilter, overridesPath] = args;
    if (!itemsPath || !csvPath) {
      console.error('사용법: node extract_ink_colors.js apply <items.json> <inks.csv> [브랜드명] [overrides.json]');
      process.exit(1);
    }
    await cmdApply(itemsPath, csvPath, brandFilter, overridesPath);
  } else {
    console.log(`
잉크 컬러 자동 추출 도구

  node extract_ink_colors.js scrape <siteKey> <url> <출력.json>
      사이트를 파싱해 [{title, thumbUrl}, ...] 목록을 저장.
      등록된 siteKey: ${Object.keys(SCRAPERS).join(', ')}

  node extract_ink_colors.js apply <items.json> <inks.csv> [브랜드명] [overrides.json]
      items.json과 inks.csv를 이름으로 매칭해 hexColor를 채워 넣음.
      overrides.json 예시(펄/쉰 잉크 색 계열 보정):
        { "제천대성": "red", "비밀의 화원": "green", "리어 왕": "gray" }
      프리셋 종류: ${Object.keys(HUE_FAMILY_PRESETS).join(', ')}
`);
  }
}

module.exports = { extractInkColor, parseWearingeulColorchart, HUE_FAMILY_PRESETS };

if (require.main === module) {
  main().catch((e) => { console.error(e); process.exit(1); });
}
