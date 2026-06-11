import 'package:cloud_firestore/cloud_firestore.dart';

class InquiryModel {
  const InquiryModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
    this.answer,
    this.answeredAt,
  });

  final String id;
  final String uid;
  final String title;
  final String content;
  final String status; // 'pending' | 'answered'
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;

  bool get isAnswered => status == 'answered';

  factory InquiryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InquiryModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      answer: data['answer'] as String?,
      answeredAt: data['answeredAt'] is Timestamp
          ? (data['answeredAt'] as Timestamp).toDate()
          : null,
    );
  }
}
