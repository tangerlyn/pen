import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ink_model.dart';
import '../../data/models/owned_ink_model.dart';
import '../../data/repositories/ink_request_repository.dart';
import '../../data/repositories/owned_ink_repository.dart';
import 'providers.dart';

final ownedInkRepoProvider = Provider<OwnedInkRepository>((ref) => OwnedInkRepository());

final inkRequestRepoProvider =
    Provider<InkRequestRepository>((ref) => InkRequestRepository());

final ownedInksProvider = StreamProvider.family<List<OwnedInk>, String>((ref, uid) {
  return ref.watch(ownedInkRepoProvider).watchOwnedInks(uid);
});

/// 현재 로그인 사용자가 이 잉크를 컬렉션에 담았는지 — 문서 스트림이라 토글 즉시 반영
final ownedInkStatusProvider = StreamProvider.family<bool, String>((ref, inkId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(ownedInkRepoProvider).watchIsOwned(uid, inkId);
});

final ownedInkActionsProvider = Provider<OwnedInkActions>((ref) => OwnedInkActions(ref));

class OwnedInkActions {
  const OwnedInkActions(this._ref);
  final Ref _ref;

  /// 반환값: true=추가됨, false=제거됨, null=비로그인(동작 안 함)
  Future<bool?> toggle(InkModel ink, {required bool isOwned}) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return null;
    final repo = _ref.read(ownedInkRepoProvider);
    if (isOwned) {
      await repo.remove(uid, ink.id);
      return false;
    }
    await repo.add(
      uid,
      OwnedInk(
        inkId: ink.id,
        brand: ink.brand,
        name: ink.name,
        hexColor: ink.hexColor,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }
}
