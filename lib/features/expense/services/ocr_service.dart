import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_amount_parser.dart';

class OCRExtractedData {
  OCRExtractedData({
    required this.rawText,
    this.storeName,
    this.totalAmount,
    this.date,
    this.summary,
    this.suggestedType,
  });

  final String rawText;
  final String? storeName;
  final double? totalAmount;
  final DateTime? date;
  final String? summary;
  final String? suggestedType;
}

class OCRService {
  OCRService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<OCRExtractedData> processImage(String imagePath) async {
    final rawText = await recognizeRawText(imagePath);
    if (rawText.trim().isEmpty) {
      return OCRExtractedData(rawText: '');
    }

    final lines = rawText
        .split('\n')
        .map((line) => _normalizeWhitespace(line))
        .where((line) => line.isNotEmpty)
        .toList();

    return OCRExtractedData(
      rawText: rawText,
      storeName: _extractStoreName(lines),
      totalAmount:
          ReceiptAmountParser.extractAmount(rawText) ??
          _extractTotalAmount(lines),
      date: _extractDate(rawText),
      summary: _extractSummary(lines),
      suggestedType: _classifyExpenseType(rawText),
    );
  }

  Future<String> recognizeRawText(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(image);
    return recognizedText.text;
  }

  void dispose() {
    _recognizer.close();
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

        if (raw.contains('.') || raw.contains(',') || raw.contains(' ')) {
          score += 2;
        }

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

    if (result.isEmpty) {
      for (final line in lines) {
        if (_isLikelyItemLine(line)) {
          result.add(line);
        }
      }
    }

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
    return hasPrice ||
        (hasQty && numberedItem) ||
        (hasQty && compact.split(' ').length >= 2);
  }

  String _classifyExpenseType(String text) {
    final normalized = text.toLowerCase();

    const foodKeywords = [
      'quan',
      'quán',
      'nha hang',
      'nhà hàng',
      'an uong',
      'ăn uống',
      'cafe',
      'cà phê',
      'tra sua',
      'trà sữa',
      'bun',
      'pho',
      'phở',
      'com',
      'cơm',
      'bánh mì',
      'banh mi',
      'đồ ăn',
      'do an',
      'food',
      'restaurant',
    ];
    const stayKeywords = [
      'hotel',
      'khach san',
      'khách sạn',
      'resort',
      'homestay',
      'villa',
      'room',
      'booking',
      'nhà nghỉ',
      'nha nghi',
      'lưu trú',
      'luu tru',
    ];
    const transportKeywords = [
      'grab',
      'taxi',
      'xe',
      'bus',
      'tau',
      'tàu',
      'flight',
      'airline',
      'xang',
      'xăng',
      'tram thu phi',
      'trạm thu phí',
      'vé xe',
      've xe',
      'bến xe',
      'ben xe',
      'ga tàu',
      'ga tau',
      'transport',
    ];
    const ticketKeywords = [
      've',
      'vé',
      'ticket',
      'entrance',
      'tham quan',
      'vào cổng',
      'vao cong',
      'xem phim',
      'sự kiện',
      'su kien',
    ];
    const shoppingKeywords = [
      'mart',
      'shop',
      'store',
      'mua sam',
      'mua sắm',
      'sieu thi',
      'siêu thị',
      'cửa hàng',
      'cua hang',
      'tiện lợi',
      'tien loi',
    ];

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
        } catch (_) {}
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
    return RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(value);
  }

  bool _isLikelyNoiseLine(String line) {
    final compact = line.replaceAll(' ', '');
    if (compact.length >= 8 &&
        RegExp(r'^(SL){4,}$', caseSensitive: false).hasMatch(compact)) {
      return true;
    }
    if (compact.length >= 10 && RegExp(r'^[^A-Za-z0-9]+$').hasMatch(compact)) {
      return true;
    }
    if (compact.length >= 10 &&
        RegExp(r'^[^A-Za-zÀ-ỹ0-9]+$').hasMatch(compact)) {
      return true;
    }
    return false;
  }

  static const List<String> _storeKeywords = [
    'shop',
    'cua hang',
    'cửa hàng',
    'nha hang',
    'nhà hàng',
    'doanh nghiep',
    'doanh nghiệp',
    'cong ty',
    'công ty',
    'hotel',
    'quan',
    'quán',
    'siêu thị',
    'sieu thi',
    'trung tâm',
    'trung tam',
  ];

  static const List<String> _metadataKeywords = [
    'ma so thue',
    'mã số thuế',
    'tax code',
    'serial',
    'ky hieu',
    'ký hiệu',
    'so no',
    'số no',
    'invoice no',
    'so tai khoan',
    'số tài khoản',
    'account',
    'dien thoai',
    'điện thoại',
    'mst',
  ];

  static const List<String> _totalKeywordsStrong = [
    'tong tien thanh toan',
    'tổng tiền thanh toán',
    'total payment',
    'tong cong',
    'tổng cộng',
    'grand total',
    'can thanh toan',
    'cần thanh toán',
    'tong tien',
    'tổng tiền',
  ];

  static const List<String> _totalKeywordsWeak = [
    'thanh tien',
    'thành tiền',
    'total',
    'cong',
    'cộng',
    'amount',
    'payment',
  ];

  static const List<String> _summaryExcludeKeywords = [
    'hoa don',
    'hóa đơn',
    'vat invoice',
    'ma so thue',
    'mã số thuế',
    'tax code',
    'serial',
    'ky hieu',
    'ký hiệu',
    'ngan hang',
    'ngân hàng',
    'tai khoan',
    'tài khoản',
    'customer signature',
    'seller signature',
    'tracuuhoadon',
    'tong tien thanh toan',
    'tổng tiền thanh toán',
  ];

  static const List<String> _itemHeaderKeywords = [
    'ten hang hoa',
    'tên hàng hóa',
    'hang hoa, dich vu',
    'hàng hóa, dịch vụ',
    'san pham',
    'sản phẩm',
    'description',
    'ten hang',
    'tên hàng',
    'dich vu',
    'dịch vụ',
  ];

  static const List<String> _itemStopKeywords = [
    'tong tien truoc thue',
    'tổng tiền trước thuế',
    'tong tien thue',
    'tổng tiền thuế',
    'tong tien thanh toan',
    'tổng tiền thanh toán',
    'total payment',
    'amount in words',
    'so tien viet bang chu',
    'số tiền viết bằng chữ',
    'nguoi mua hang',
    'người mua hàng',
    'nguoi ban hang',
    'người bán hàng',
  ];

  static const List<String> _itemExcludeKeywords = [
    'khach hang',
    'khách hàng',
    'customer',
    'nguoi ban',
    'người bán',
    'address',
    'dia chi',
    'địa chỉ',
    'dien thoai',
    'điện thoại',
    'tax code',
    'ma so thue',
    'mã số thuế',
    'hinh thuc thanh toan',
    'hình thức thanh toán',
    'payment method',
    'ngan hang',
    'ngân hàng',
    'account',
    'cong ty',
    'công ty',
    'doanh nghiep',
    'doanh nghiệp',
  ];
}
