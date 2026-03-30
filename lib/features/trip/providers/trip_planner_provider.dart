import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../ai/models/ai_planner_models.dart';
import '../../notification/notification_service.dart';
import '../models/trip_models.dart';

class TripPlannerProvider extends ChangeNotifier {
  TripPlannerProvider() {
    _init();
  }

  static const String _boxName = 'trip_planner_box';
  static const String _tripKey = 'trips';

  final List<Trip> _trips = [];
  DateTime _selectedDate = DateTime.now();
  String? _activeTripId;
  bool _isReady = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isReady => _isReady;
  DateTime get selectedDate => _selectedDate;
  String? get activeTripId => _activeTripId;

  Trip? get activeTrip {
    if (_activeTripId == null) {
      return _trips.isNotEmpty ? _trips.first : null;
    }
    for (final trip in _trips) {
      if (trip.id == _activeTripId) {
        return trip;
      }
    }
    return _trips.isNotEmpty ? _trips.first : null;
  }

  Future<void> _init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final rawTrips =
        box.get(_tripKey, defaultValue: <dynamic>[]) as List<dynamic>;

    _trips
      ..clear()
      ..addAll(
        rawTrips
            .map((item) => Trip.fromMap(item as Map<dynamic, dynamic>))
            .toList(),
      );

    if (_trips.isNotEmpty) {
      _activeTripId = _trips.first.id;
      _selectedDate = _trips.first.startDate;
    }

    await _syncNotifications();
    _isReady = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_tripKey, _trips.map((trip) => trip.toMap()).toList());
  }

  Future<void> _syncNotifications() async {
    await NotificationService.instance.rescheduleFromTrips(_trips);
  }

  Future<void> createTrip({
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final trip = Trip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      locations: [],
    );
    _trips.insert(0, trip);
    _activeTripId = trip.id;
    _selectedDate = normalizedStart;
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> createTripFromAiPlan(PlannerResult plannerResult) async {
    final totalDays = plannerResult.totalDays > 0 ? plannerResult.totalDays : 1;
    final start = DateTime.now();
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = normalizedStart.add(Duration(days: totalDays - 1));
    final tripId = DateTime.now().microsecondsSinceEpoch.toString();

    final generatedLocations = <TripLocation>[];
    var sequence = 0;
    for (final plannerDay in plannerResult.itinerary) {
      final day = normalizedStart.add(Duration(days: plannerDay.day - 1));
      for (final item in plannerDay.items) {
        final placeName = item.place.trim();
        if (placeName.isEmpty) {
          continue;
        }
        generatedLocations.add(
          TripLocation(
            id: '${DateTime.now().microsecondsSinceEpoch}_$sequence',
            name: placeName,
            day: _clampDate(day, normalizedStart, normalizedEnd),
            minuteOfDay: _parseMinuteOfDay(item.time),
            note: item.note,
          ),
        );
        sequence += 1;
      }
    }

    final title = plannerResult.destination.trim().isEmpty
        ? 'Chuyến đi từ AI'
        : plannerResult.destination.trim();

    final trip = Trip(
      id: tripId,
      title: title,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      locations: generatedLocations,
    );

    _trips.insert(0, trip);
    _activeTripId = trip.id;
    _selectedDate = normalizedStart;

    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> updateTrip({
    required String tripId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final index = _trips.indexWhere((item) => item.id == tripId);
    if (index < 0) {
      return;
    }

    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final current = _trips[index];

    final updatedLocations = current.locations.map((location) {
      final day = DateTime(
        location.day.year,
        location.day.month,
        location.day.day,
      );
      final clampedDay = _clampDate(day, normalizedStart, normalizedEnd);
      return TripLocation(
        id: location.id,
        name: location.name,
        day: clampedDay,
        note: location.note,
        minuteOfDay: location.minuteOfDay,
      );
    }).toList();

    _trips[index] = current.copyWith(
      title: title,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      locations: updatedLocations,
    );

    if (_activeTripId == tripId) {
      _selectedDate = _clampDate(_selectedDate, normalizedStart, normalizedEnd);
    }

    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> deleteTrip(String tripId) async {
    _trips.removeWhere((item) => item.id == tripId);

    if (_activeTripId == tripId) {
      if (_trips.isEmpty) {
        _activeTripId = null;
        _selectedDate = DateTime.now();
      } else {
        _activeTripId = _trips.first.id;
        _selectedDate = _trips.first.startDate;
      }
    }

    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setActiveTrip(String tripId) async {
    _activeTripId = tripId;
    final trip = activeTrip;
    if (trip != null) {
      _selectedDate = trip.startDate;
    }
    notifyListeners();
  }

  void setSelectedDate(DateTime day) {
    _selectedDate = DateTime(day.year, day.month, day.day);
    notifyListeners();
  }

  Future<void> addLocation({
    required String tripId,
    required String name,
    required DateTime day,
    int? minuteOfDay,
    String? note,
  }) async {
    final index = _trips.indexWhere((item) => item.id == tripId);
    if (index < 0) {
      return;
    }

    final newLocation = TripLocation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      day: DateTime(day.year, day.month, day.day),
      minuteOfDay: minuteOfDay,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );

    final updatedLocations = [..._trips[index].locations, newLocation];
    _trips[index] = _trips[index].copyWith(locations: updatedLocations);
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> removeLocation({
    required String tripId,
    required String locationId,
  }) async {
    final index = _trips.indexWhere((item) => item.id == tripId);
    if (index < 0) {
      return;
    }
    final updated = _trips[index].locations
        .where((location) => location.id != locationId)
        .toList();
    _trips[index] = _trips[index].copyWith(locations: updated);
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> updateLocation({
    required String tripId,
    required String locationId,
    required String name,
    required DateTime day,
    int? minuteOfDay,
    String? note,
  }) async {
    final tripIndex = _trips.indexWhere((item) => item.id == tripId);
    if (tripIndex < 0) {
      return;
    }

    final trip = _trips[tripIndex];
    final locationIndex = trip.locations.indexWhere(
      (item) => item.id == locationId,
    );
    if (locationIndex < 0) {
      return;
    }

    final updatedLocations = [...trip.locations];
    updatedLocations[locationIndex] = TripLocation(
      id: locationId,
      name: name,
      day: DateTime(day.year, day.month, day.day),
      minuteOfDay: minuteOfDay,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );

    _trips[tripIndex] = trip.copyWith(locations: updatedLocations);
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> reorderLocationsForDay({
    required String tripId,
    required DateTime day,
    required int oldIndex,
    required int newIndex,
  }) async {
    final tripIndex = _trips.indexWhere((item) => item.id == tripId);
    if (tripIndex < 0) {
      return;
    }

    final trip = _trips[tripIndex];
    final dayKey = DateTime(day.year, day.month, day.day);

    final dayLocations = trip.locations
        .where((item) => _isSameDate(item.day, dayKey))
        .toList();

    if (oldIndex < 0 || oldIndex >= dayLocations.length) {
      return;
    }

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex > dayLocations.length) {
      return;
    }

    final moved = dayLocations.removeAt(oldIndex);
    dayLocations.insert(targetIndex, moved);

    var dayCursor = 0;
    final rebuilt = <TripLocation>[];
    for (final location in trip.locations) {
      if (_isSameDate(location.day, dayKey)) {
        rebuilt.add(dayLocations[dayCursor]);
        dayCursor += 1;
      } else {
        rebuilt.add(location);
      }
    }

    _trips[tripIndex] = trip.copyWith(locations: rebuilt);
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> saveAiPlannerResult({
    required String tripId,
    required PlannerResult plannerResult,
  }) async {
    final tripIndex = _trips.indexWhere((item) => item.id == tripId);
    if (tripIndex < 0) {
      return;
    }

    final trip = _trips[tripIndex];
    final generatedLocations = <TripLocation>[];
    var sequence = 0;

    for (final plannerDay in plannerResult.itinerary) {
      final normalizedDay = _clampDate(
        trip.startDate.add(Duration(days: plannerDay.day - 1)),
        trip.startDate,
        trip.endDate,
      );

      for (final item in plannerDay.items) {
        final placeName = item.place.trim();
        if (placeName.isEmpty) {
          continue;
        }

        generatedLocations.add(
          TripLocation(
            id: '${DateTime.now().microsecondsSinceEpoch}_$sequence',
            name: placeName,
            day: normalizedDay,
            minuteOfDay: _parseMinuteOfDay(item.time),
            note: item.note,
          ),
        );
        sequence += 1;
      }
    }

    if (generatedLocations.isEmpty) {
      return;
    }

    final updatedLocations = [...trip.locations, ...generatedLocations];
    _trips[tripIndex] = trip.copyWith(locations: updatedLocations);
    await _persist();
    await _syncNotifications();
    notifyListeners();
  }

  List<TripLocation> locationsByDay(String tripId, DateTime day) {
    final trip = _trips.where((item) => item.id == tripId).firstOrNull;
    if (trip == null) {
      return [];
    }

    final normalizedDay = DateTime(day.year, day.month, day.day);
    return trip.locations
        .where((location) => _isSameDate(location.day, normalizedDay))
        .toList();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int? _parseMinuteOfDay(String? time) {
    if (time == null) {
      return null;
    }

    final normalized = time.trim();
    final regex = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');
    final match = regex.firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return (hour * 60) + minute;
  }

  DateTime _clampDate(DateTime value, DateTime start, DateTime end) {
    if (value.isBefore(start)) {
      return start;
    }
    if (value.isAfter(end)) {
      return end;
    }
    return value;
  }
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
