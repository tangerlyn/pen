import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_model.dart';

class BannerRepository {
  final _db = FirebaseFirestore.instance;

  /// 노출 중인 배너를 순서대로. 배너는 몇 개뿐이라 전체를 읽고 앱에서
  /// 거르고 정렬한다 (active+order 복합 인덱스가 필요 없도록).
  Future<List<BannerModel>> getActiveBanners() async {
    final snap = await _db.collection('banners').limit(20).get();
    final banners = snap.docs
        .map(BannerModel.fromDoc)
        .where((b) => b.active && b.title.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return banners;
  }

  Future<BannerModel?> getBanner(String id) async {
    final doc = await _db.collection('banners').doc(id).get();
    if (!doc.exists) return null;
    return BannerModel.fromDoc(doc);
  }
}
