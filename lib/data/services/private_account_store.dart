import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}`는 로그인한 누구나 읽을 수 있어서, 이메일·FCM 토큰처럼
/// 남에게 보이면 안 되는 값은 본인만 읽고 쓰는 `users/{uid}/private/account`에
/// 둔다 (firestore.rules 참고).
///
/// 옛 앱 버전은 같은 값을 `users/{uid}`에 직접 썼기 때문에, 쓸 때마다 그 공개
/// 필드를 함께 지운다. 서버(functions의 getUserFcmData)는 공개 필드가 남아
/// 있으면 "옛 앱이 가장 최근에 쓴 값"으로 보고 우선 사용한다.
class PrivateAccountStore {
  PrivateAccountStore([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('account');

  Future<void> saveFcmToken(String uid, String token) =>
      _write(uid, 'fcmToken', token);

  Future<void> deleteFcmToken(String uid) =>
      _write(uid, 'fcmToken', FieldValue.delete());

  Future<void> saveEmail(String uid, String email) =>
      _write(uid, 'email', email);

  Future<void> _write(String uid, String field, Object value) async {
    final batch = _db.batch()
      ..set(_ref(uid), {field: value}, SetOptions(merge: true))
      ..update(_db.collection('users').doc(uid), {field: FieldValue.delete()});
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
      // users 문서가 아직 없으면 지울 공개 필드도 없다
      await _ref(uid).set({field: value}, SetOptions(merge: true));
    }
  }
}
