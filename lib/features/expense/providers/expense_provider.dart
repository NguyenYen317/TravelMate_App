import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:math';

import '../expense_service.dart';
import '../models/expense_item.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? expenseService})
    : _expenseService = expenseService ?? ExpenseService() {
    _init();
  }

  static const String _boxName = 'expense_box';
  static const String _expenseKey = 'expenses';

  final ExpenseService _expenseService;
  final List<ExpenseItem> _allExpenses = [];
  bool _isReady = false;
  DateTime? _filterDate;
  String _filterType = 'All';

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

  Future<void> _init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final rawExpenses =
        box.get(_expenseKey, defaultValue: <dynamic>[]) as List<dynamic>;
    _allExpenses
      ..clear()
      ..addAll(
        rawExpenses
            .map((item) => ExpenseItem.fromMap(item as Map<dynamic, dynamic>))
            .toList(),
      );
    _isReady = true;
    notifyListeners();
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
    return expensesByTrip(tripId).fold<double>(0, (sum, item) => sum + item.amount);
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
}
