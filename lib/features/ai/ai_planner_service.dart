import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'models/ai_planner_models.dart';

class AIPlannerService {
  AIPlannerService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PlannerResult> generatePlan(String rawInput) async {
    final provider = AppConstants.aiProvider.trim().toLowerCase();
    if (provider == 'ollama') {
      return _generateWithOllama(rawInput.trim());
    }
    return _generateWithGemini(rawInput.trim());
  }

  Future<PlannerResult> _generateWithGemini(String userInput) async {
    final apiKey = AppConstants.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw const AIPlannerException(
        'Thiếu GEMINI_API_KEY. Chạy app với --dart-define=GEMINI_API_KEY=... hoặc chuyển sang AI_PROVIDER=ollama.',
      );
    }

    final prompt = _buildPrompt(userInput);
    final model = AppConstants.geminiModel.trim();
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AIPlannerException(
        'Gemini API lỗi (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = _extractGeminiText(decoded);
    if (rawText == null || rawText.trim().isEmpty) {
      throw const AIPlannerException('Gemini không trả về dữ liệu hợp lệ.');
    }

    return _toPlannerResult(rawText);
  }

  Future<PlannerResult> _generateWithOllama(String userInput) async {
    final baseUrl = AppConstants.ollamaBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AIPlannerException(
        'Thiếu OLLAMA_BASE_URL. Ví dụ: --dart-define=OLLAMA_BASE_URL=http://192.168.1.10:11434',
      );
    }

    final model = AppConstants.ollamaModel.trim();
    final prompt = _buildPrompt(userInput);
    final uri = Uri.parse('$baseUrl/api/generate');

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'format': 'json',
        'stream': false,
        'options': {'temperature': 0.2},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AIPlannerException(
        'Ollama API lỗi (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = decoded['response']?.toString();
    if (rawText == null || rawText.trim().isEmpty) {
      throw const AIPlannerException('Ollama không trả về dữ liệu hợp lệ.');
    }

    return _toPlannerResult(rawText);
  }

  PlannerResult _toPlannerResult(String rawText) {
    final cleanedJson = _stripCodeFence(rawText);
    final payload = jsonDecode(cleanedJson);
    if (payload is! Map<String, dynamic>) {
      throw const AIPlannerException('Định dạng JSON không đúng schema mong đợi.');
    }
    return _ensureNonEmptyItinerary(PlannerResult.fromJson(payload));
  }

  PlannerResult _ensureNonEmptyItinerary(PlannerResult result) {
    final random = Random();
    final totalDays = result.totalDays > 0 ? result.totalDays : 1;

    final sourceDays = result.itinerary.isEmpty
        ? List.generate(
            totalDays,
            (index) => PlannerDay(day: index + 1, items: const []),
          )
        : result.itinerary;

    final fixedDays = sourceDays.map((dayPlan) {
      if (dayPlan.items.isNotEmpty) {
        return dayPlan;
      }
      return PlannerDay(
        day: dayPlan.day,
        title: dayPlan.title ?? 'Khám phá tự do',
        items: [_randomFallbackItem(result.destination, random)],
      );
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    return PlannerResult(
      destination: result.destination,
      totalDays: max(result.totalDays, fixedDays.length),
      places: result.places,
      itinerary: fixedDays,
    );
  }

  PlannerItineraryItem _randomFallbackItem(String destination, Random random) {
    final activities = <PlannerItineraryItem>[
      PlannerItineraryItem(
        place: 'Dạo biển và ngắm hoàng hôn',
        time: '08:30',
        note: 'Hoạt động gợi ý tự động',
      ),
      PlannerItineraryItem(
        place: 'Khám phá khu ẩm thực địa phương',
        time: '11:30',
        note: 'Thử món đặc sản',
      ),
      PlannerItineraryItem(
        place: 'Check-in điểm tham quan nổi bật',
        time: '15:00',
        note: 'Chụp ảnh và thư giãn',
      ),
      PlannerItineraryItem(
        place: destination.trim().isEmpty
            ? 'Đi dạo trung tâm thành phố'
            : 'Đi dạo trung tâm $destination',
        time: '19:00',
        note: 'Tự do khám phá buổi tối',
      ),
    ];
    return activities[random.nextInt(activities.length)];
  }

  String _buildPrompt(String userInput) {
    return '''
Bạn là bộ máy tạo lịch trình du lịch. Nhiệm vụ: chuyển yêu cầu người dùng thành JSON hợp lệ.

RÀNG BUỘC BẮT BUỘC:
- Chỉ trả về JSON object, không markdown, không code fence, không giải thích.
- JSON phải đúng schema:
{
  "destination": "string",
  "total_days": number,
  "places": [
    {"name": "string", "description": "string"}
  ],
  "itinerary": [
    {
      "day": number,
      "title": "string",
      "items": [
        {"place": "string", "time": "HH:mm", "note": "string"}
      ]
    }
  ]
}
- `day` bắt đầu từ 1, tăng dần theo ngày.
- `time` dùng định dạng 24h HH:mm nếu có.
- Không thêm key ngoài schema.
- Nội dung viết tiếng Việt.

INPUT NGƯỜI DÙNG:
$userInput
''';
  }

  String? _extractGeminiText(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      return null;
    }

    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) {
      return null;
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return null;
    }

    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        return part['text'] as String;
      }
    }
    return null;
  }

  String _stripCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }

    final lines = trimmed.split('\n');
    if (lines.length <= 2) {
      return trimmed;
    }

    return lines.sublist(1, lines.length - 1).join('\n').trim();
  }
}

class AIPlannerException implements Exception {
  const AIPlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}
