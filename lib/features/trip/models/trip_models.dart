class TripLocation {
  TripLocation({
    required this.id,
    required this.name,
    required this.day,
    this.note,
    this.minuteOfDay,
  });

  final String id;
  final String name;
  final DateTime day;
  final String? note;
  final int? minuteOfDay;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'day': day.toIso8601String(),
      'note': note,
      'minuteOfDay': minuteOfDay,
    };
  }

  factory TripLocation.fromMap(Map<dynamic, dynamic> map) {
    return TripLocation(
      id: map['id'] as String,
      name: map['name'] as String,
      day: DateTime.parse(map['day'] as String),
      note: map['note'] as String?,
      minuteOfDay: map['minuteOfDay'] as int?,
    );
  }
}

class Trip {
  Trip({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.locations,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<TripLocation> locations;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;

  Trip copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<TripLocation>? locations,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      locations: locations ?? this.locations,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'locations': locations.map((item) => item.toMap()).toList(),
      'startMinuteOfDay': startMinuteOfDay,
      'endMinuteOfDay': endMinuteOfDay,
    };
  }

  factory Trip.fromMap(Map<dynamic, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      title: map['title'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      locations: (map['locations'] as List<dynamic>)
          .map((item) => TripLocation.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
      startMinuteOfDay: map['startMinuteOfDay'] as int?,
      endMinuteOfDay: map['endMinuteOfDay'] as int?,
    );
  }
}
