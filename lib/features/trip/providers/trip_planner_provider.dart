import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../sync/sync_service.dart';
import '../models/trip_models.dart';

class TripPlannerProvider extends ChangeNotifier {
  TripPlannerProvider() {
    _init();
  }

  static const String _boxName = 'trip_planner_box';
  static const String _tripKeyPrefix = 'trips';
  static const String _tripUpdatedAtKeyPrefix = 'trips_updated_at';

  final List<Trip> _trips = [];
  DateTime _selectedDate = DateTime.now();
  String? _activeTripId;
  String? _currentUserId;
  bool _isReady = false;
  int _reloadVersion = 0;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isReady => _isReady;
  DateTime get selectedDate => _selectedDate;
  String? get activeTripId => _activeTripId;

  void setUserId(String? userId) {
    if (_currentUserId == userId) {
      return;
    }
    _currentUserId = userId;
    _reloadForUser(userId);
  }

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
    await _reloadForUser(_currentUserId);
  }

  Future<void> _reloadForUser(String? userId) async {
    final requestVersion = ++_reloadVersion;
    final storageKey = _buildTripKey(userId);

    _isReady = false;
    notifyListeners();

    final box = await Hive.openBox<dynamic>(_boxName);
    final rawTrips =
        box.get(storageKey, defaultValue: <dynamic>[]) as List<dynamic>;

    var localTrips = rawTrips
        .map((item) => Trip.fromMap(item as Map<dynamic, dynamic>))
        .toList();

    if (userId != null) {
      final cloudPayload = await SyncService.instance.loadTrips(userId: userId);
      if (requestVersion != _reloadVersion || _currentUserId != userId) {
        return;
      }

      if (cloudPayload != null) {
        final cloudTrips = cloudPayload.items
            .map((item) => Trip.fromMap(item))
            .toList();
        final cloudHasData = cloudTrips.isNotEmpty;
        final localHasData = localTrips.isNotEmpty;

        if (!localHasData && cloudHasData) {
          localTrips = cloudTrips;
          await _saveLocalOnly(_tripsToRaw(localTrips));
        } else if (localHasData && !cloudHasData) {
          await SyncService.instance.saveTrips(
            userId: userId,
            trips: _tripsToRaw(localTrips),
          );
        } else if (localHasData && cloudHasData) {
          final localUpdatedAt = _readLocalUpdatedAt(box, storageKey);
          if (cloudPayload.updatedAtMs >= localUpdatedAt) {
            localTrips = cloudTrips;
            await _saveLocalOnly(_tripsToRaw(localTrips));
          } else {
            await SyncService.instance.saveTrips(
              userId: userId,
              trips: _tripsToRaw(localTrips),
            );
          }
        }
      }
    }

    // Ignore stale async loads when user switches account quickly.
    if (requestVersion != _reloadVersion || _currentUserId != userId) {
      return;
    }

    _trips
      ..clear()
      ..addAll(localTrips);

    _activeTripId = null;
    _selectedDate = DateTime.now();
    if (_trips.isNotEmpty) {
      _activeTripId = _trips.first.id;
      _selectedDate = _trips.first.startDate;
    }

    _isReady = true;
    notifyListeners();
  }

  String get _tripKey {
    return _buildTripKey(_currentUserId);
  }

  String _buildTripKey(String? userId) {
    final userKey = userId ?? 'guest';
    return '$_tripKeyPrefix::$userKey';
  }

  Future<void> _persist() async {
    final rawTrips = _tripsToRaw(_trips);
    await _saveLocalOnly(rawTrips);

    final userId = _currentUserId;
    if (userId != null) {
      await SyncService.instance.saveTrips(userId: userId, trips: rawTrips);
    }
  }

  List<Map<String, dynamic>> _tripsToRaw(List<Trip> trips) {
    return trips.map((trip) => trip.toMap()).toList();
  }

  String _buildTripUpdatedAtKey(String storageKey) {
    return '$_tripUpdatedAtKeyPrefix::$storageKey';
  }

  int _readLocalUpdatedAt(Box<dynamic> box, String storageKey) {
    final raw = box.get(_buildTripUpdatedAtKey(storageKey), defaultValue: 0);
    return raw is int ? raw : 0;
  }

  Future<void> _saveLocalOnly(List<Map<String, dynamic>> rawTrips) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_tripKey, rawTrips);
    await box.put(
      _buildTripUpdatedAtKey(_tripKey),
      DateTime.now().millisecondsSinceEpoch,
    );
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
