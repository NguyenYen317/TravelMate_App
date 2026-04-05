import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import 'models/expense_item.dart';

class ExpenseService {
  ExpenseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _writeTimeout = Duration(seconds: 15);

  Future<void> addExpenseToFirebase(ExpenseItem item) async {
    await _runForCurrentUser((userId) async {
      final tripDoc = _tripDoc(userId, item.tripId);
      final itemDoc = tripDoc.collection('items').doc(item.id);

      await _firestore
          .runTransaction<void>((transaction) async {
            transaction.set(itemDoc, _toFirestoreMap(item, isCreate: true));
            transaction.set(
              tripDoc,
              {
                'tripId': item.tripId,
                'userId': userId,
                'totalAmount': FieldValue.increment(item.amount),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          })
          .timeout(_writeTimeout);
    });
  }

  Future<void> updateExpenseInFirebase({
    required ExpenseItem before,
    required ExpenseItem after,
  }) async {
    await _runForCurrentUser((userId) async {
      final tripDoc = _tripDoc(userId, after.tripId);
      final itemDoc = tripDoc.collection('items').doc(after.id);
      final diff = after.amount - before.amount;

      await _firestore
          .runTransaction<void>((transaction) async {
            transaction.set(
              itemDoc,
              _toFirestoreMap(after, isCreate: false),
              SetOptions(merge: true),
            );
            if (diff != 0) {
              transaction.set(
                tripDoc,
                {
                  'totalAmount': FieldValue.increment(diff),
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            }
          })
          .timeout(_writeTimeout);
    });
  }

  Future<void> deleteExpenseFromFirebase(ExpenseItem item) async {
    await _runForCurrentUser((userId) async {
      final tripDoc = _tripDoc(userId, item.tripId);
      final itemDoc = tripDoc.collection('items').doc(item.id);

      await _firestore
          .runTransaction<void>((transaction) async {
            transaction.delete(itemDoc);
            transaction.set(
              tripDoc,
              {
                'totalAmount': FieldValue.increment(-item.amount),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          })
          .timeout(_writeTimeout);
    });
  }

  Future<void> deleteTripExpensesFromFirebase({
    required String tripId,
    required List<ExpenseItem> expenses,
  }) async {
    if (expenses.isEmpty) {
      return;
    }

    await _runForCurrentUser((userId) async {
      final tripDoc = _tripDoc(userId, tripId);
      final batch = _firestore.batch();

      for (final expense in expenses) {
        final itemDoc = tripDoc.collection('items').doc(expense.id);
        batch.delete(itemDoc);
      }

      batch.set(
        tripDoc,
        {
          'tripId': tripId,
          'userId': userId,
          'totalAmount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit().timeout(_writeTimeout);
    });
  }

  Future<void> _runForCurrentUser(
    Future<void> Function(String userId) action,
  ) async {
    if (!AuthService.instance.isFirebaseAvailable) {
      return;
    }

    try {
      final user = await AuthService.instance.getCurrentUser();
      if (user == null) {
        return;
      }
      await action(user.id);
    } catch (error) {
      debugPrint('Expense Firebase sync failed: $error');
    }
  }

  DocumentReference<Map<String, dynamic>> _tripDoc(String userId, String tripId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('trip_expenses')
        .doc(tripId);
  }

  Map<String, dynamic> _toFirestoreMap(
    ExpenseItem item, {
    required bool isCreate,
  }) {
    return {
      'id': item.id,
      'tripId': item.tripId,
      'title': item.title,
      'amount': item.amount,
      'type': item.type,
      'date': Timestamp.fromDate(item.date),
      'note': item.note,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
