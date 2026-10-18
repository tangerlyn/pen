import 'package:cloud_firestore/cloud_firestore.dart';

/// 아카이브에 없는 잉크 등록 요청. 운영자가 확인 후 `inks`에 추가한다.
/// 요청은 생성만 가능하고 처리 상태 변경은 관리자 SDK로만 한다 (firestore.rules).
class InkRequestRepository {
  final _db = FirebaseFirestore.instance;

  Future<String> create({
    required String uid,
    required String brand,
    required String name,
  }) async {
    final doc = _db.collection('inkRequests').doc();
    await doc.set({
      'uid': uid,
      'brand': brand,
      'name': name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
