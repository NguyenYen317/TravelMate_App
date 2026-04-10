class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    this.updatedAtMs,
  });

  final String id;
  final String tripId;
  final String title;
  final double amount;
  final String type;
  final DateTime date;
  final String? note;
  final int? updatedAtMs;

  ExpenseItem copyWith({
    String? title,
    double? amount,
    String? type,
    DateTime? date,
    String? note,
    int? updatedAtMs,
  }) {
    return ExpenseItem(
      id: id,
      tripId: tripId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'note': note,
      'updatedAtMs': updatedAtMs,
    };
  }

  factory ExpenseItem.fromMap(Map<dynamic, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      tripId: map['tripId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      updatedAtMs: _asInt(map['updatedAtMs']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '').toString());
}
