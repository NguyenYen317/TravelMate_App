import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/expense_item.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider() {
    _init();
  }

  static const String _boxName = 'expense_box';
  static const String _expenseKeyPrefix = 'expenses';

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

    // Ignore stale async loads when user switches account quickly.
    if (requestVersion != _reloadVersion || _currentUserId != userId) {
      return;
    }

    _allExpenses
      ..clear()
      ..addAll(
        rawExpenses
            .map((item) => ExpenseItem.fromMap(item as Map<dynamic, dynamic>))
            .toList(),
      );

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
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(
      _expenseKey,
      _allExpenses.map((expense) => expense.toMap()).toList(),
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
    return filteredExpensesByTrip(
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
    _allExpenses.add(
      ExpenseItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        tripId: tripId,
        title: title,
        amount: amount,
        type: type,
        date: date,
        note: note == null || note.trim().isEmpty ? null : note.trim(),
      ),
    );
    await _persist();
    notifyListeners();
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
    _allExpenses[index] = current.copyWith(
      title: title,
      amount: amount,
      type: type,
      date: date,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );

    await _persist();
    notifyListeners();
  }

  Future<void> deleteExpense(String expenseId) async {
    _allExpenses.removeWhere((item) => item.id == expenseId);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteExpensesByTrip(String tripId) async {
    _allExpenses.removeWhere((item) => item.tripId == tripId);
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
}
