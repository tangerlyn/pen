import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inquiry_model.dart';

class InquiryRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('inquiries');

  Stream<List<InquiryModel>> watchMyInquiries(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(InquiryModel.fromDoc).toList());
  }

  Stream<InquiryModel?> watchInquiry(String id) {
    return _col.doc(id).snapshots().map(
          (doc) => doc.exists ? InquiryModel.fromDoc(doc) : null,
        );
  }

  Future<void> createInquiry({
    required String uid,
    required String title,
    required String content,
  }) async {
    await _col.add({
      'uid': uid,
      'title': title,
      'content': content,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'answer': null,
      'answeredAt': null,
    });
  }
}
