import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:math';

import '../expense_service.dart';
import '../../sync/sync_service.dart';
import '../models/expense_item.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? expenseService})
    : _expenseService = expenseService ?? ExpenseService() {
    _init();
  }

  static const String _boxName = 'expense_box';
  static const String _expenseKeyPrefix = 'expenses';
  static const String _expenseUpdatedAtKeyPrefix = 'expenses_updated_at';

  final ExpenseService _expenseService;
  final List<ExpenseItem> _allExpenses = [];
  bool _isReady = false;
  String? _currentUserId;
  DateTime? _filterDate;
  String _filterType = 'All';
  int _reloadVersion = 0;

  static const List<String> types = [
    'All',
    'Food',
    'Transport',
    'Stay',
    'Ticket',
    'Shopping',
    'Other',
  ];

  bool get isReady => _isReady;
  DateTime? get filterDate => _filterDate;
  String get filterType => _filterType;

  void setUserId(String? userId) {
    if (_currentUserId == userId) {
      return;
    }
    _currentUserId = userId;
    _reloadForUser(userId);
  }

  Future<void> _init() async {
    await _reloadForUser(_currentUserId);
  }

  Future<void> _reloadForUser(String? userId) async {
    final requestVersion = ++_reloadVersion;
    final storageKey = _buildExpenseKey(userId);

    _isReady = false;
    notifyListeners();

    final box = await Hive.openBox<dynamic>(_boxName);
    final rawExpenses =
        box.get(storageKey, defaultValue: <dynamic>[]) as List<dynamic>;
    final localUpdatedAt = _readLocalUpdatedAt(box, storageKey);

    var localExpenses = rawExpenses
        .map((item) => ExpenseItem.fromMap(item as Map<dynamic, dynamic>))
        .toList();

    if (userId != null) {
      final cloudPayload = await SyncService.instance.loadExpenses(
        userId: userId,
      );
      if (requestVersion != _reloadVersion || _currentUserId != userId) {
        return;
      }

      if (cloudPayload != null) {
        final cloudExpenses = cloudPayload.items
            .map((item) => ExpenseItem.fromMap(item))
            .toList();
        final cloudHasData = cloudExpenses.isNotEmpty;
        final localHasData = localExpenses.isNotEmpty;

        if (!localHasData && cloudHasData) {
          localExpenses = cloudExpenses;
          await _saveLocalOnly(_expensesToRaw(localExpenses));
        } else if (localHasData && !cloudHasData) {
          await SyncService.instance.saveExpenses(
            userId: userId,
            expenses: _expensesToRaw(localExpenses),
          );
        } else if (localHasData && cloudHasData) {
          localExpenses = _mergeExpenses(
            localExpenses: localExpenses,
            cloudExpenses: cloudExpenses,
            localUpdatedAtMs: localUpdatedAt,
            cloudUpdatedAtMs: cloudPayload.updatedAtMs,
          );

          final mergedRaw = _expensesToRaw(localExpenses);
          await _saveLocalOnly(mergedRaw);
          await SyncService.instance.saveExpenses(
            userId: userId,
            expenses: mergedRaw,
          );
        }
      }
    }

    // Ignore stale async loads when user switches account quickly.
    if (requestVersion != _reloadVersion || _currentUserId != userId) {
      return;
    }

    _allExpenses
      ..clear()
      ..addAll(localExpenses);

    _filterDate = null;
    _filterType = 'All';
    _isReady = true;
    notifyListeners();
  }

  String get _expenseKey {
    return _buildExpenseKey(_currentUserId);
  }

  String _buildExpenseKey(String? userId) {
    final userKey = userId ?? 'guest';
    return '$_expenseKeyPrefix::$userKey';
  }

  Future<void> _persist() async {
    final rawExpenses = _expensesToRaw(_allExpenses);
    await _saveLocalOnly(rawExpenses);

    final userId = _currentUserId;
    if (userId != null) {
      await SyncService.instance.saveExpenses(
        userId: userId,
        expenses: rawExpenses,
      );
    }
  }

  List<Map<String, dynamic>> _expensesToRaw(List<ExpenseItem> expenses) {
    return expenses.map((expense) => expense.toMap()).toList();
  }

  String _buildExpenseUpdatedAtKey(String storageKey) {
    return '$_expenseUpdatedAtKeyPrefix::$storageKey';
  }

  int _readLocalUpdatedAt(Box<dynamic> box, String storageKey) {
    final raw = box.get(_buildExpenseUpdatedAtKey(storageKey), defaultValue: 0);
    return raw is int ? raw : 0;
  }

  Future<void> _saveLocalOnly(List<Map<String, dynamic>> rawExpenses) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_expenseKey, rawExpenses);
    await box.put(
      _buildExpenseUpdatedAtKey(_expenseKey),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  List<ExpenseItem> expensesByTrip(String tripId) {
    return _allExpenses.where((expense) => expense.tripId == tripId).toList();
  }

  List<ExpenseItem> filteredExpensesByTrip(String tripId) {
    var result = expensesByTrip(tripId);
    if (_filterType != 'All') {
      result = result.where((item) => item.type == _filterType).toList();
    }
    if (_filterDate != null) {
      result = result
          .where((item) => _isSameDate(item.date, _filterDate!))
          .toList();
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  double totalByTrip(String tripId) {
    return expensesByTrip(
      tripId,
    ).fold<double>(0, (sum, item) => sum + item.amount);
  }

  Future<void> addExpense({
    required String tripId,
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
  }) async {
    final created = ExpenseItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tripId: tripId,
      title: title,
      amount: amount,
      type: type,
      date: date,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      updatedAtMs: _nowMs(),
    );

    _allExpenses.add(created);
    await _persist();
    notifyListeners();
    await _expenseService.addExpenseToFirebase(created);
  }

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required double amount,
    required String type,
    required DateTime date,
    String? note,
  }) async {
    final index = _allExpenses.indexWhere((item) => item.id == expenseId);
    if (index < 0) {
      return;
    }

    final current = _allExpenses[index];
    final updated = current.copyWith(
      title: title,
      amount: amount,
      type: type,
      date: date,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      updatedAtMs: _nowMs(),
    );
    _allExpenses[index] = updated;
    await _persist();
    notifyListeners();
    await _expenseService.updateExpenseInFirebase(
      before: current,
      after: updated,
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    final index = _allExpenses.indexWhere((item) => item.id == expenseId);
    if (index < 0) {
      return;
    }
    final removed = _allExpenses.removeAt(index);
    await _persist();
    notifyListeners();
    await _expenseService.deleteExpenseFromFirebase(removed);
  }

  Future<void> deleteExpensesByTrip(String tripId) async {
    final removed = _allExpenses
        .where((item) => item.tripId == tripId)
        .toList(growable: false);
    _allExpenses.removeWhere((item) => item.tripId == tripId);
    await _persist();
    notifyListeners();
    await _expenseService.deleteTripExpensesFromFirebase(
      tripId: tripId,
      expenses: removed,
    );
  }

  Future<void> seedRandomExpensesIfEmpty({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final existing = expensesByTrip(tripId);
    if (existing.isNotEmpty) {
      return;
    }

    final random = Random(tripId.hashCode);
    final daySpan = endDate.difference(startDate).inDays;
    final count = 2 + random.nextInt(2); // 2-3 expense items
    final expenseTypes = ['Food', 'Transport', 'Ticket', 'Other'];
    final sampleTitles = {
      'Food': ['Ăn sáng', 'Bữa trưa', 'Đặc sản địa phương'],
      'Transport': ['Taxi', 'Xe công nghệ', 'Thuê xe máy'],
      'Ticket': ['Vé tham quan', 'Vé vào cổng', 'Vé sự kiện'],
      'Other': ['Nước uống', 'Đồ dùng cá nhân', 'Chi phí phát sinh'],
    };

    for (var i = 0; i < count; i++) {
      final type = expenseTypes[random.nextInt(expenseTypes.length)];
      final titles = sampleTitles[type]!;
      final title = titles[random.nextInt(titles.length)];
      final amount = 50000 + random.nextInt(250000); // 50k-300k
      final dayOffset = daySpan <= 0 ? 0 : random.nextInt(daySpan + 1);
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: dayOffset));

      _allExpenses.add(
        ExpenseItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_seed_$i',
          tripId: tripId,
          title: title,
          amount: amount.toDouble(),
          type: type,
          date: date,
          note: 'Chi phí gợi ý tự động',
          updatedAtMs: _nowMs(),
        ),
      );
    }

    await _persist();
    notifyListeners();
  }

  void setFilterType(String type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterDate(DateTime? date) {
    _filterDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ExpenseItem> _mergeExpenses({
    required List<ExpenseItem> localExpenses,
    required List<ExpenseItem> cloudExpenses,
    required int localUpdatedAtMs,
    required int cloudUpdatedAtMs,
  }) {
    final byId = <String, ExpenseItem>{};

    for (final expense in localExpenses) {
      byId[expense.id] = expense;
    }

    for (final cloudExpense in cloudExpenses) {
      final localExpense = byId[cloudExpense.id];
      if (localExpense == null) {
        byId[cloudExpense.id] = cloudExpense;
        continue;
      }

      byId[cloudExpense.id] = _pickNewerExpense(
        localExpense: localExpense,
        cloudExpense: cloudExpense,
        localUpdatedAtMs: localUpdatedAtMs,
        cloudUpdatedAtMs: cloudUpdatedAtMs,
      );
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      final aUpdated = a.updatedAtMs ?? 0;
      final bUpdated = b.updatedAtMs ?? 0;
      if (aUpdated != bUpdated) {
        return bUpdated.compareTo(aUpdated);
      }
      return b.date.compareTo(a.date);
    });
    return merged;
  }

  ExpenseItem _pickNewerExpense({
    required ExpenseItem localExpense,
    required ExpenseItem cloudExpense,
    required int localUpdatedAtMs,
    required int cloudUpdatedAtMs,
  }) {
    final localItemUpdatedAt = localExpense.updatedAtMs ?? 0;
    final cloudItemUpdatedAt = cloudExpense.updatedAtMs ?? 0;

    if (cloudItemUpdatedAt > localItemUpdatedAt) {
      return cloudExpense;
    }
    if (localItemUpdatedAt > cloudItemUpdatedAt) {
      return localExpense;
    }

    if (cloudUpdatedAtMs >= localUpdatedAtMs) {
      return cloudExpense;
    }
    return localExpense;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}
