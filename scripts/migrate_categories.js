const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateCategories() {
  console.log('Starting migration: adding categories field to reviews...');
  
  const reviewsRef = db.collection('reviews');
  const snapshot = await reviewsRef.get();

  if (snapshot.empty) {
    console.log('No reviews found.');
    return;
  }

  const batch = db.batch();
  let count = 0;

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const categories = [];

    if (data.inkIds && data.inkIds.length > 0) categories.push('잉크');
    if (data.penIds && data.penIds.length > 0) categories.push('만년필');
    if (data.paperIds && data.paperIds.length > 0) categories.push('종이');

    // Only update if categories is not empty or if it's different from current
    if (categories.length > 0) {
      batch.update(doc.ref, { categories: categories });
      count++;
    }
  });

  if (count > 0) {
    await batch.commit();
    console.log(`Successfully updated ${count} reviews with categories.`);
  } else {
    console.log('No reviews needed updating.');
  }
}

migrateCategories()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
