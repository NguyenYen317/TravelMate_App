import 'package:flutter/material.dart';

import 'ai_planner_service.dart';
import 'models/ai_planner_models.dart';

class AIProvider extends ChangeNotifier {
  AIProvider({AIPlannerService? plannerService})
    : _plannerService = plannerService ?? AIPlannerService();

  final AIPlannerService _plannerService;

  PlannerResult? _lastResult;
  bool _isLoading = false;
  String? _error;

  PlannerResult? get lastResult => _lastResult;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> generatePlanner(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      _error = 'Vui lòng nhập yêu cầu, ví dụ: Đà Nẵng 3 ngày.';
      _lastResult = null;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _plannerService.generatePlan(query);
      _lastResult = result;
      _error = null;
      return true;
    } catch (error) {
      _lastResult = null;
      _error = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResult() {
    _lastResult = null;
    _error = null;
    notifyListeners();
  }
}
