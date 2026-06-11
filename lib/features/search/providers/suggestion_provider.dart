import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _end(String q) => q + String.fromCharCode(0xF8FF);

final suggestionProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, query) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  final db = FirebaseFirestore.instance;
  final snaps = await Future.wait([
    db.collection('inks')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThanOrEqualTo: _end(q))
        .limit(5)
        .get(),
    db.collection('inks')
        .where('brand', isGreaterThanOrEqualTo: q)
        .where('brand', isLessThanOrEqualTo: _end(q))
        .limit(3)
        .get(),
    db.collection('pens')
        .where('modelName', isGreaterThanOrEqualTo: q)
        .where('modelName', isLessThanOrEqualTo: _end(q))
        .limit(5)
        .get(),
    db.collection('pens')
        .where('brand', isGreaterThanOrEqualTo: q)
        .where('brand', isLessThanOrEqualTo: _end(q))
        .limit(3)
        .get(),
  ]);

  final seen = <String>{};
  final out = <String>[];

  for (final doc in snaps[0].docs) {
    final v = doc['name'] as String? ?? '';
    if (v.isNotEmpty && seen.add(v)) out.add(v);
  }
  for (final doc in snaps[1].docs) {
    final v = doc['brand'] as String? ?? '';
    if (v.isNotEmpty && seen.add(v)) out.add(v);
  }
  for (final doc in snaps[2].docs) {
    final v = doc['modelName'] as String? ?? '';
    if (v.isNotEmpty && seen.add(v)) out.add(v);
  }
  for (final doc in snaps[3].docs) {
    final v = doc['brand'] as String? ?? '';
    if (v.isNotEmpty && seen.add(v)) out.add(v);
  }

  return out.take(8).toList();
});
