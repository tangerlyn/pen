const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

// 서비스 어카운트 키 경로
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('ERROR: serviceAccountKey.json 파일을 scripts 폴더 안에 넣어주세요.');
  console.error('Firebase Console -> 프로젝트 설정 -> 서비스 계정에서 새 비공개 키를 생성하여 저장할 수 있습니다.');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// csv 파일들이 있는 경로
const ASSETS_DIR = path.join(__dirname, '../assets/info_csv');

async function processCsv(filename, collectionName, transformFn) {
  const results = [];
  const filePath = path.join(ASSETS_DIR, filename);
  
  if (!fs.existsSync(filePath)) {
    console.error(`ERROR: ${filename} 파일을 찾을 수 없습니다: ${filePath}`);
    return;
  }

  console.log(`\n=== ${filename} -> ${collectionName} 컬렉션 업로드 시작 ===`);

  return new Promise((resolve, reject) => {
    fs.createReadStream(filePath)
      .pipe(csv())
      .on('data', (data) => {
        if (transformFn) {
          data = transformFn(data);
        }
        results.push(data);
      })
      .on('end', async () => {
        try {
          // Firestore의 Batch write 제한이 500개이므로, 청크로 나눔 (여기서는 데이터가 적으므로 단일 배치 사용)
          const batch = db.batch();
          for (const item of results) {
            const docId = item.id;
            const docRef = db.collection(collectionName).doc(docId);
            batch.set(docRef, item);
          }
          await batch.commit();
          console.log(`✅ ${results.length}개의 데이터를 ${collectionName}에 업로드 완료했습니다.`);
          resolve();
        } catch (error) {
          console.error(`❌ 업로드 실패 (${collectionName}):`, error);
          reject(error);
        }
      });
  });
}

async function main() {
  try {
    // 1. Inks 업로드
    await processCsv('inks.csv', 'inks', (data) => {
      // 용량은 숫자로 변환
      if (data.capacityMl) {
        data.capacityMl = parseInt(data.capacityMl, 10);
      }
      return data;
    });

    // 2. Pens 업로드
    await processCsv('pens.csv', 'pens', (data) => {
      // 닙 사이즈는 | 로 구분된 문자열이므로 배열로 변환
      if (data.nibSizes) {
        data.nibSizes = data.nibSizes.split('|').map(s => s.trim()).filter(s => s.length > 0);
      }
      return data;
    });

    // 3. Papers 업로드
    await processCsv('papers.csv', 'papers', (data) => {
      // 평량은 숫자로 변환
      if (data.grammage) {
        data.grammage = parseInt(data.grammage, 10);
      }
      return data;
    });

    console.log('\n🎉 모든 업로드가 완료되었습니다!');
  } catch (error) {
    console.error('\n업로드 중 오류 발생:', error);
  } finally {
    process.exit(0);
  }
}

main();
