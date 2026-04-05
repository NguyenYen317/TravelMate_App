class ReceiptAmountMatch {
  const ReceiptAmountMatch({
    required this.amount,
    required this.line,
    required this.score,
  });

  final double amount;
  final String line;
  final int score;
}

class ReceiptAmountParser {
  static const double _minimumAmount = 1000;
  static final RegExp _amountPattern = RegExp(
    r'([0-9]{1,3}(?:[.,\s][0-9]{3})+|[0-9]{4,})',
  );

  static ReceiptAmountMatch? extractBestMatch(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    ReceiptAmountMatch? best;
    for (final line in lines) {
      final normalized = line.toLowerCase();
      final matches = _amountPattern.allMatches(line);

      for (final match in matches) {
        final rawAmount = match.group(1);
        if (rawAmount == null) {
          continue;
        }

        final amount = _parseAmount(rawAmount);
        if (amount == null || amount < _minimumAmount) {
          continue;
        }

        var score = 0;
        if (_containsAny(normalized, _totalKeywordsStrong)) {
          score += 90;
        } else if (_containsAny(normalized, _totalKeywordsWeak)) {
          score += 45;
        }

        if (_containsAny(normalized, _taxKeywords)) {
          score -= 20;
        }
        if (RegExp(r'(vnd|vnđ|đ)\b', caseSensitive: false).hasMatch(line)) {
          score += 8;
        }
        if (rawAmount.contains('.') ||
            rawAmount.contains(',') ||
            rawAmount.contains(' ')) {
          score += 5;
        }
        if (amount > 2000000000) {
          score -= 15;
        }

        final candidate = ReceiptAmountMatch(
          amount: amount,
          line: line,
          score: score,
        );
        if (_isBetter(candidate, best)) {
          best = candidate;
        }
      }
    }

    if (best != null) {
      return best;
    }

    return _extractLargestAmount(lines);
  }

  static double? extractAmount(String rawText) {
    return extractBestMatch(rawText)?.amount;
  }

  static bool _isBetter(ReceiptAmountMatch candidate, ReceiptAmountMatch? best) {
    if (best == null) {
      return true;
    }
    if (candidate.score != best.score) {
      return candidate.score > best.score;
    }
    return candidate.amount > best.amount;
  }

  static ReceiptAmountMatch? _extractLargestAmount(List<String> lines) {
    ReceiptAmountMatch? best;
    for (final line in lines) {
      for (final match in _amountPattern.allMatches(line)) {
        final rawAmount = match.group(1);
        if (rawAmount == null) {
          continue;
        }
        final amount = _parseAmount(rawAmount);
        if (amount == null || amount < _minimumAmount) {
          continue;
        }

        final candidate = ReceiptAmountMatch(amount: amount, line: line, score: 0);
        if (best == null || candidate.amount > best.amount) {
          best = candidate;
        }
      }
    }
    return best;
  }

  static bool _containsAny(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static double? _parseAmount(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    final plain = normalized.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(plain);
  }

  static const List<String> _totalKeywordsStrong = [
    'tong tien',
    'tong cong',
    'tong thanh toan',
    'total',
    'grand total',
    'amount due',
  ];

  static const List<String> _totalKeywordsWeak = [
    'tong',
    'thanh tien',
    'payment',
    'can thanh toan',
  ];

  static const List<String> _taxKeywords = [
    'vat',
    'thue',
    'tax',
    'gtgt',
  ];
}
