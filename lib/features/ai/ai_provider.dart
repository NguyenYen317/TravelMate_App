import 'package:flutter/material.dart';

import 'ai_planner_service.dart';
import 'models/ai_chat_models.dart';
import 'models/ai_planner_models.dart';

class AIProvider extends ChangeNotifier {
  AIProvider({AIPlannerService? plannerService})
    : _plannerService = plannerService ?? AIPlannerService();

  final AIPlannerService _plannerService;

  PlannerResult? _lastResult;
  bool _isLoading = false;
  String? _error;
  final List<AIChatMessage> _chatMessages = <AIChatMessage>[];
  bool _isChatLoading = false;
  String? _chatError;

  PlannerResult? get lastResult => _lastResult;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AIChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  bool get isChatLoading => _isChatLoading;
  String? get chatError => _chatError;

  Future<bool> generatePlanner(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      _error = 'Vui long nhap yeu cau, vi du: Da Nang 3 ngay.';
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

  Future<void> sendChatMessage(String input) async {
    final query = input.trim();
    if (query.isEmpty || _isChatLoading) {
      return;
    }

    _chatMessages.add(
      AIChatMessage(
        role: AIChatRole.user,
        text: query,
        createdAt: DateTime.now(),
      ),
    );
    _chatError = null;
    _isChatLoading = true;
    notifyListeners();

    try {
      final reply = await _plannerService.generateChatReply(
        userInput: query,
        history: _chatMessages,
      );
      _chatMessages.add(
        AIChatMessage(
          role: AIChatRole.bot,
          text: reply,
          createdAt: DateTime.now(),
        ),
      );
      _chatError = null;
    } catch (error) {
      _chatError = error.toString();
      _chatMessages.add(
        AIChatMessage(
          role: AIChatRole.bot,
          text: 'Xin loi, minh dang gap loi ket noi. Ban thu lai sau nhe.',
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      _isChatLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _chatMessages.clear();
    _chatError = null;
    _isChatLoading = false;
    notifyListeners();
  }
}
