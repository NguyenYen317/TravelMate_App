import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ReceiptScanResult {
  ReceiptScanResult({
    required this.rawText,
    this.storeName,
    this.totalAmount,
    this.date,
    this.summary,
    this.suggestedType,
    this.cloudinaryUrl,
  });

  final String rawText;
  final String? storeName;
  final double? totalAmount;
  final DateTime? date;
  final String? summary;
  final String? suggestedType;
  final String? cloudinaryUrl;
}

class ReceiptProcessingService {
  ReceiptProcessingService();

  static const String _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<ReceiptScanResult?> scanReceipt({required ImageSource source}) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) {
      return null;
    }

    final rawText = await _recognizeText(file.path);
    if (rawText.trim().isEmpty) {
      return ReceiptScanResult(
        rawText: '',
        cloudinaryUrl: await _uploadToCloudinary(file),
      );
    }

    final lines = rawText
        .split('\n')
        .map((line) => _normalizeWhitespace(line))
        .where((line) => line.isNotEmpty)
        .toList();

    final storeName = _extractStoreName(lines);
    final date = _extractDate(rawText);
    final total = _extractTotalAmount(lines);
    final summary = _extractSummary(lines);
    final suggestedType = _classifyExpenseType(rawText);
    final cloudinaryUrl = await _uploadToCloudinary(file);

    return ReceiptScanResult(
      rawText: rawText,
      storeName: storeName,
      totalAmount: total,
      date: date,
      summary: summary,
      suggestedType: suggestedType,
      cloudinaryUrl: cloudinaryUrl,
    );
  }

  Future<String> _recognizeText(String path) async {
    final image = InputImage.fromFilePath(path);
    final recognizedText = await _recognizer.processImage(image);
    return recognizedText.text;
  }

  String? _extractStoreName(List<String> lines) {
    for (final line in lines.take(12)) {
      if (_isLikelyNoiseLine(line)) {
        continue;
      }

      final normalized = _normalizeForMatch(line);
      if (_containsAny(normalized, _metadataKeywords)) {
        continue;
      }
      if (!_containsAlphabet(line)) {
        continue;
      }

      // Prefer store-like lines near the top.
      if (_containsAny(normalized, _storeKeywords) || line.length >= 5) {
        return line;
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final lines = text
        .split('\n')
        .map(_normalizeWhitespace)
        .where((e) => e.isNotEmpty);

    DateTime? best;
    var bestScore = -1;

    for (final line in lines) {
      final normalized = _normalizeForMatch(line);
      final dateCandidates = _extractDateCandidates(line);

      for (final candidate in dateCandidates) {
        if (!_isReasonableDate(candidate)) {
          continue;
        }

        var score = 0;
        if (_containsAny(normalized, ['ngay', 'date'])) {
          score += 4;
        }
        if (_containsAny(normalized, ['ky', 'signed', 'ngay ky'])) {
          score -= 1;
        }

        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
    }

    return best;
  }

  double? _extractTotalAmount(List<String> lines) {
    final amountPattern = RegExp(r'([0-9]{1,3}(?:[.,\s][0-9]{3})+|[0-9]+)');

    double? bestAmount;
    var bestScore = -1;

    for (final line in lines) {
      if (_isLikelyNoiseLine(line)) {
        continue;
      }

      final normalized = _normalizeForMatch(line);

      // Ignore metadata lines (tax code, serial, bank account...) for totals.
      if (_containsAny(normalized, _metadataKeywords)) {
        continue;
      }

      final matches = amountPattern.allMatches(line);
      for (final match in matches) {
        final raw = match.group(1)!;
        final value = _parseAmount(raw);
        if (value == null || value <= 0) {
          continue;
        }

        var score = 0;
        if (_containsAny(normalized, _totalKeywordsStrong)) {
          score += 10;
        } else if (_containsAny(normalized, _totalKeywordsWeak)) {
          score += 4;
        }

        if (_containsAny(normalized, ['vat', 'thue gtgt', 'tien thue'])) {
          score -= 3;
        }

        // Prefer number with thousand separators for currency fields.
        if (raw.contains('.') || raw.contains(',') || raw.contains(' ')) {
          score += 2;
        }

        // Long plain digit strings are likely IDs (e.g., tax code).
        final plainDigits = raw.replaceAll(RegExp(r'\D'), '');
        if (!(raw.contains('.') || raw.contains(',') || raw.contains(' ')) &&
            plainDigits.length >= 9 &&
            !_containsAny(normalized, _totalKeywordsStrong)) {
          score -= 6;
        }

        if (value > 2000000000) {
          score -= 4;
        }

        if (score > bestScore ||
            (score == bestScore &&
                (bestAmount == null || value > bestAmount))) {
          bestScore = score;
          bestAmount = value;
        }
      }
    }

    return bestAmount;
  }

  String? _extractSummary(List<String> lines) {
    final itemLines = _extractItemLines(lines);
    if (itemLines.isEmpty) {
      return null;
    }
    return itemLines.join(' | ');
  }

  List<String> _extractItemLines(List<String> lines) {
    final result = <String>[];

    var itemSectionStart = -1;
    for (var i = 0; i < lines.length; i++) {
      final normalized = _normalizeForMatch(lines[i]);
      if (_containsAny(normalized, _itemHeaderKeywords)) {
        itemSectionStart = i;
        break;
      }
    }

    final start = itemSectionStart >= 0 ? itemSectionStart + 1 : 0;

    for (var i = start; i < lines.length; i++) {
      final line = lines[i];
      final normalized = _normalizeForMatch(line);

      if (_containsAny(normalized, _itemStopKeywords)) {
        if (result.isNotEmpty) {
          break;
        }
        continue;
      }

      if (_isLikelyItemLine(line)) {
        result.add(line);
      }
    }

    // Fallback for simple printed bills without a clear item header section.
    if (result.isEmpty) {
      for (final line in lines) {
        if (_isLikelyItemLine(line)) {
          result.add(line);
        }
      }
    }

    // Keep unique item lines and cap length to avoid overly long notes.
    final dedup = <String>[];
    final seen = <String>{};
    for (final line in result) {
      if (seen.add(line)) {
        dedup.add(line);
      }
      if (dedup.length >= 20) {
        break;
      }
    }

    return dedup;
  }

  bool _isLikelyItemLine(String line) {
    if (_isLikelyNoiseLine(line)) {
      return false;
    }

    final normalized = _normalizeForMatch(line);
    if (_containsAny(normalized, _summaryExcludeKeywords)) {
      return false;
    }
    if (_containsAny(normalized, _itemExcludeKeywords)) {
      return false;
    }
    if (!_containsAlphabet(line)) {
      return false;
    }

    final compact = line.trim();
    if (compact.length < 2) {
      return false;
    }

    final hasPrice = RegExp(r'[0-9]{1,3}(?:[.,\s][0-9]{3})+').hasMatch(line);
    final hasQty = RegExp(r'\b\d+(?:[.,]\d+)?\b').hasMatch(line);
    final numberedItem = RegExp(r'^\d+\s+').hasMatch(compact);

    // Most item lines have item text and either quantity/price information.
    return hasPrice ||
        (hasQty && numberedItem) ||
        (hasQty && compact.split(' ').length >= 2);
  }

  String _classifyExpenseType(String text) {
    final normalized = text.toLowerCase();

    const foodKeywords = [
      'quan',
      'nha hang',
      'an uong',
      'cafe',
      'tra sua',
      'bun',
      'pho',
      'com',
      'food',
      'restaurant',
    ];
    const stayKeywords = [
      'hotel',
      'khach san',
      'resort',
      'homestay',
      'villa',
      'room',
      'booking',
    ];
    const transportKeywords = [
      'grab',
      'taxi',
      'xe',
      'bus',
      'tau',
      'flight',
      'airline',
      'xang',
      'tram thu phi',
      'transport',
    ];
    const ticketKeywords = ['ve', 'ticket', 'entrance', 'tham quan'];
    const shoppingKeywords = ['mart', 'shop', 'store', 'mua sam', 'sieu thi'];

    if (_containsAny(normalized, stayKeywords)) {
      return 'Stay';
    }
    if (_containsAny(normalized, transportKeywords)) {
      return 'Transport';
    }
    if (_containsAny(normalized, ticketKeywords)) {
      return 'Ticket';
    }
    if (_containsAny(normalized, shoppingKeywords)) {
      return 'Shopping';
    }
    if (_containsAny(normalized, foodKeywords)) {
      return 'Food';
    }
    return 'Other';
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  double? _parseAmount(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    final plain = normalized.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(plain);
  }

  List<DateTime> _extractDateCandidates(String line) {
    final results = <DateTime>[];
    final patterns = [
      RegExp(r'(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})'),
      RegExp(r'(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})'),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(line)) {
        try {
          if (pattern.pattern.startsWith('(\\d{1,2})')) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) {
              year += 2000;
            }
            results.add(DateTime(year, month, day));
          } else {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            results.add(DateTime(year, month, day));
          }
        } catch (_) {
          // ignore invalid candidate
        }
      }
    }

    return results;
  }

  bool _isReasonableDate(DateTime date) {
    final now = DateTime.now();
    final min = DateTime(2018, 1, 1);
    final max = DateTime(now.year + 2, 12, 31);
    return !date.isBefore(min) && !date.isAfter(max);
  }

  String _normalizeWhitespace(String line) {
    return line.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeForMatch(String text) {
    return text.toLowerCase();
  }

  bool _containsAlphabet(String value) {
    return RegExp(r'[A-Za-zÀ-ỹà-ỹ]').hasMatch(value);
  }

  bool _isLikelyNoiseLine(String line) {
    final compact = line.replaceAll(' ', '');
    if (compact.length >= 8 &&
        RegExp(r'^(SL){4,}$', caseSensitive: false).hasMatch(compact)) {
      return true;
    }
    if (compact.length >= 10 &&
        RegExp(r'^[^A-Za-zÀ-ỹà-ỹ0-9]+$').hasMatch(compact)) {
      return true;
    }
    return false;
  }

  static const List<String> _storeKeywords = [
    'shop',
    'cua hang',
    'nha hang',
    'doanh nghiep',
    'cong ty',
    'hotel',
    'quan',
  ];

  static const List<String> _metadataKeywords = [
    'ma so thue',
    'tax code',
    'serial',
    'ky hieu',
    'so no',
    'invoice no',
    'so tai khoan',
    'account',
    'dien thoai',
    'mst',
  ];

  static const List<String> _totalKeywordsStrong = [
    'tong tien thanh toan',
    'total payment',
    'tong cong',
    'grand total',
    'can thanh toan',
    'tong tien',
  ];

  static const List<String> _totalKeywordsWeak = [
    'thanh tien',
    'total',
    'cong',
    'amount',
    'payment',
  ];

  static const List<String> _summaryExcludeKeywords = [
    'hoa don',
    'vat invoice',
    'ma so thue',
    'tax code',
    'serial',
    'ky hieu',
    'ngan hang',
    'tai khoan',
    'customer signature',
    'seller signature',
    'tracuuhoadon',
    'tong tien thanh toan',
  ];

  static const List<String> _itemHeaderKeywords = [
    'ten hang hoa',
    'hang hoa, dich vu',
    'san pham',
    'description',
    'ten hang',
    'dich vu',
  ];

  static const List<String> _itemStopKeywords = [
    'tong tien truoc thue',
    'tong tien thue',
    'tong tien thanh toan',
    'total payment',
    'amount in words',
    'so tien viet bang chu',
    'nguoi mua hang',
    'nguoi ban hang',
  ];

  static const List<String> _itemExcludeKeywords = [
    'khach hang',
    'customer',
    'nguoi ban',
    'address',
    'dia chi',
    'dien thoai',
    'tax code',
    'ma so thue',
    'hinh thuc thanh toan',
    'payment method',
    'ngan hang',
    'account',
    'cong ty',
    'doanh nghiep',
  ];

  Future<String?> _uploadToCloudinary(XFile file) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = await response.stream.bytesToString();
    final secureUrlMatch = RegExp(
      r'"secure_url"\s*:\s*"([^"]+)"',
    ).firstMatch(body);
    if (secureUrlMatch == null) {
      return null;
    }

    return secureUrlMatch.group(1);
  }

  void dispose() {
    _recognizer.close();
  }
}
