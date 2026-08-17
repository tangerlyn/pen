import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_system.dart';
import '../models/ink_chart_model.dart';
import '../models/user_model.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  /// 닉네임 사용 가능 여부 반환. excludeUid를 주면 해당 유저는 제외
  Future<bool> isNicknameAvailable(String nickname, {String? excludeUid}) async {
    final snap = await _users
        .where('nickname', isEqualTo: nickname)
        .limit(2)
        .get();
    if (snap.docs.isEmpty) return true;
    if (excludeUid != null) {
      return snap.docs.every((d) => d.id == excludeUid);
    }
    return false;
  }

  Future<void> addExp(String uid, int amount) async {
    await _users.doc(uid).update({'exp': FieldValue.increment(amount)});
  }

  /// EXP를 부여하고 레벨업 시 LevelUpInfo를 반환 (레벨업 없으면 null)
  Future<LevelUpInfo?> addExpAndCheck(String uid, int amount) async {
    LevelUpInfo? result;
    await _db.runTransaction((tx) async {
      final userDoc = await tx.get(_users.doc(uid));
      final data = userDoc.data() as Map<String, dynamic>?;
      final currentExp = (data?['exp'] as num?)?.toInt() ?? 0;
      final newExp = currentExp + amount;
      final oldLevel = LevelSystem.levelFromExp(currentExp);
      final newLevel = LevelSystem.levelFromExp(newExp);
      tx.update(_users.doc(uid), {'exp': newExp});
      if (newLevel > oldLevel) {
        result = LevelUpInfo(level: newLevel, title: LevelSystem.title(newLevel));
      }
    });
    return result;
  }

  Future<void> follow(String fromUid, String toUid) async {
    final batch = _db.batch();
    batch.update(_users.doc(fromUid), {'followingCount': FieldValue.increment(1)});
    batch.update(_users.doc(toUid), {'followerCount': FieldValue.increment(1)});
    batch.set(
      _db.collection('follows').doc('${fromUid}_$toUid'),
      {'followerId': fromUid, 'followeeId': toUid, 'createdAt': FieldValue.serverTimestamp()},
    );
    await batch.commit();
  }

  Future<void> unfollow(String fromUid, String toUid) async {
    final batch = _db.batch();
    batch.update(_users.doc(fromUid), {'followingCount': FieldValue.increment(-1)});
    batch.update(_users.doc(toUid), {'followerCount': FieldValue.increment(-1)});
    batch.delete(_db.collection('follows').doc('${fromUid}_$toUid'));
    await batch.commit();
  }

  Stream<bool> watchFollowStatus(String myUid, String targetUid) {
    return _db
        .collection('follows')
        .doc('${myUid}_$targetUid')
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<List<String>> getFollowingUids(String uid) async {
    final snap = await _db
        .collection('follows')
        .where('followerId', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d['followeeId'] as String).toList();
  }

  Stream<List<String>> watchFollowingUids(String uid) {
    return _db
        .collection('follows')
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d['followeeId'] as String).toList());
  }

  Future<List<String>> getFollowerUids(String uid) async {
    final snap = await _db
        .collection('follows')
        .where('followeeId', isEqualTo: uid)
        .get();
    return snap.docs.map((d) => d['followerId'] as String).toList();
  }

  Future<void> block(String blockerUid, String blockedUid) async {
    await _users.doc(blockerUid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    });
  }

  Future<void> unblock(String blockerUid, String blockedUid) async {
    await _users.doc(blockerUid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    });
  }

  Future<List<String>> getBlockedUsers(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    return List<String>.from(data?['blockedUsers'] ?? []);
  }

  Stream<List<String>> watchBlockedUids(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return List<String>.from(data?['blockedUsers'] ?? []);
    });
  }

  /// 차단 유저를 제외하고 authorId 필드를 가진 목록을 필터링
  Future<List<T>> filterByBlocked<T>(
      String? uid, List<T> items, String Function(T) authorId) async {
    if (uid == null || items.isEmpty) return items;
    final blocked = await getBlockedUsers(uid);
    if (blocked.isEmpty) return items;
    return items.where((item) => !blocked.contains(authorId(item))).toList();
  }

  // 신고 문서 ID가 결정적(targetType_targetId_reporterId)이라, 이미 있는지만
  // 확인하면 "이미 신고했는지" 바로 알 수 있다.
  Future<bool> hasReported({
    required String targetType,
    required String targetId,
    required String reporterId,
  }) async {
    final reportId = '${targetType}_${targetId}_$reporterId';
    final doc = await _db.collection(AppConstants.reportsCol).doc(reportId).get();
    return doc.exists;
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reporterId,
    required String reason,
  }) async {
    // 문서 ID를 결정적으로 고정 — 같은 유저가 같은 대상을 여러 번 신고해도
    // 새 문서가 쌓이지 않고 덮어써서, 자동 조치 임계값(서버 onReportCreated)이
    // 한 사람의 반복 신고로 인위적으로 채워지는 걸 막는다.
    final reportId = '${targetType}_${targetId}_$reporterId';
    await _db.collection(AppConstants.reportsCol).doc(reportId).set({
      'targetType': targetType,
      'targetId': targetId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── 잉크 차트 (스와치 다이어리) ────────────────────────────────────
  Stream<List<InkChartModel>> watchInkChart(String uid) {
    return _users
        .doc(uid)
        .collection('inkChart')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => InkChartModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addInkChartEntry(String uid, InkChartModel entry) async {
    final data = entry.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _users.doc(uid).collection('inkChart').doc(entry.id).set(data);
  }

  Future<void> deleteInkChartEntry(String uid, String chartId) async {
    await _users.doc(uid).collection('inkChart').doc(chartId).delete();
  }
}
