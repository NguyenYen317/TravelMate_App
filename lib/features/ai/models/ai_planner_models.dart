class PlannerPlace {
  PlannerPlace({required this.name, this.description});

  final String name;
  final String? description;

  factory PlannerPlace.fromJson(Map<String, dynamic> json) {
    return PlannerPlace(
      name: (json['name'] ?? '').toString().trim(),
      description: _normalizeText(json['description']),
    );
  }
}

class PlannerItineraryItem {
  PlannerItineraryItem({required this.place, this.time, this.note});

  final String place;
  final String? time;
  final String? note;

  factory PlannerItineraryItem.fromJson(Map<String, dynamic> json) {
    return PlannerItineraryItem(
      place: (json['place'] ?? '').toString().trim(),
      time: _normalizeText(json['time']),
      note: _normalizeText(json['note']),
    );
  }
}

class PlannerDay {
  PlannerDay({required this.day, this.title, required this.items});

  final int day;
  final String? title;
  final List<PlannerItineraryItem> items;

  factory PlannerDay.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) =>
              PlannerItineraryItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.place.isNotEmpty)
        .toList();

    return PlannerDay(
      day: _toInt(json['day']) ?? 1,
      title: _normalizeText(json['title']),
      items: rawItems,
    );
  }
}

class PlannerResult {
  PlannerResult({
    required this.destination,
    required this.totalDays,
    required this.places,
    required this.itinerary,
  });

  final String destination;
  final int totalDays;
  final List<PlannerPlace> places;
  final List<PlannerDay> itinerary;

  factory PlannerResult.fromJson(Map<String, dynamic> json) {
    final rawPlaces = (json['places'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => PlannerPlace.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();

    final rawItinerary =
        (json['itinerary'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => PlannerDay.fromJson(Map<String, dynamic>.from(item)))
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));

    return PlannerResult(
      destination: (json['destination'] ?? '').toString().trim(),
      totalDays: _toInt(json['total_days']) ?? rawItinerary.length,
      places: rawPlaces,
      itinerary: rawItinerary,
    );
  }
}

String? _normalizeText(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value == null) {
    return null;
  }
  return int.tryParse(value.toString());
}
