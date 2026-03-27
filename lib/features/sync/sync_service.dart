import 'package:cloud_firestore/cloud_firestore.dart';

class SyncPayload {
  const SyncPayload({required this.items, required this.updatedAtMs});

  final List<Map<String, dynamic>> items;
  final int updatedAtMs;
}

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _db.collection('travelmate_users');
  }

  Future<SyncPayload?> loadTrips({required String userId}) async {
    return _load(
      userId: userId,
      field: 'trips',
      updatedAtField: 'tripsUpdatedAtMs',
    );
  }

  Future<void> saveTrips({
    required String userId,
    required List<Map<String, dynamic>> trips,
  }) async {
    await _save(
      userId: userId,
      field: 'trips',
      updatedAtField: 'tripsUpdatedAtMs',
      items: trips,
    );
  }

  Future<SyncPayload?> loadExpenses({required String userId}) async {
    return _load(
      userId: userId,
      field: 'expenses',
      updatedAtField: 'expensesUpdatedAtMs',
    );
  }

  Future<void> saveExpenses({
    required String userId,
    required List<Map<String, dynamic>> expenses,
  }) async {
    await _save(
      userId: userId,
      field: 'expenses',
      updatedAtField: 'expensesUpdatedAtMs',
      items: expenses,
    );
  }

  Future<SyncPayload?> _load({
    required String userId,
    required String field,
    required String updatedAtField,
  }) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      final data = doc.data();
      if (data == null) {
        return const SyncPayload(items: [], updatedAtMs: 0);
      }

      final rawItems = data[field];
      final rawUpdatedAt = data[updatedAtField];

      final updatedAtMs = rawUpdatedAt is int ? rawUpdatedAt : 0;
      if (rawItems is! List<dynamic>) {
        return SyncPayload(items: const [], updatedAtMs: updatedAtMs);
      }

      final items = rawItems
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();

      return SyncPayload(items: items, updatedAtMs: updatedAtMs);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({
    required String userId,
    required String field,
    required String updatedAtField,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _usersCollection.doc(userId).set({
        field: items,
        updatedAtField: DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {
      // Intentionally ignore sync failures to keep local flow usable offline.
    }
  }
}
