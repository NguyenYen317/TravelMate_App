import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/providers/app_provider.dart';
import '../../routes/app_routes.dart';
import '../trip/models/trip_models.dart';
import '../trip/providers/trip_planner_provider.dart';

class PendingTripNotification {
  PendingTripNotification({
    required this.id,
    required this.tripId,
    required this.tripTitle,
    required this.locationName,
    required this.scheduledAt,
  });

  final int id;
  final String tripId;
  final String tripTitle;
  final String locationName;
  final DateTime scheduledAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'tripTitle': tripTitle,
      'locationName': locationName,
      'scheduledAt': scheduledAt.toIso8601String(),
    };
  }

  factory PendingTripNotification.fromMap(Map<String, dynamic> map) {
    return PendingTripNotification(
      id: map['id'] as int,
      tripId: map['tripId'] as String,
      tripTitle: map['tripTitle'] as String,
      locationName: map['locationName'] as String,
      scheduledAt: DateTime.parse(map['scheduledAt'] as String),
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'smart_assistant_trip';
  static const String _channelName = 'Smart Assistant';
  static const String _channelDescription =
      'Nhac nho lich trinh va check-in theo chuyen di';

  static const String _permissionAskedKey =
      'smart_assistant_notification_permission_asked';
  static const String _pendingCacheKey = 'smart_assistant_pending_cache';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _initialPayload;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  Future<void> ensurePermissionRequestedOnFirstModuleAccess() async {
    await ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool(_permissionAskedKey) ?? false;
    if (!asked) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();
      await prefs.setBool(_permissionAskedKey, true);
    }
  }

  Future<void> consumeInitialNotificationIntent() async {
    await ensureInitialized();
    final payload = _initialPayload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    _initialPayload = null;
    _handlePayload(payload);
  }

  Future<void> rescheduleFromTrips(List<Trip> trips) async {
    await ensureInitialized();

    await _plugin.cancelAll();

    final pending = <PendingTripNotification>[];
    final now = DateTime.now();

    for (final trip in trips) {
      for (final location in trip.locations) {
        if (location.minuteOfDay == null) {
          continue;
        }

        final date = DateTime(
          location.day.year,
          location.day.month,
          location.day.day,
          location.minuteOfDay! ~/ 60,
          location.minuteOfDay! % 60,
        );

        if (!date.isAfter(now)) {
          continue;
        }

        final id = _notificationId(trip.id, location.id);
        final payload = jsonEncode({
          'tripId': trip.id,
          'locationId': location.id,
        });

        await _plugin.zonedSchedule(
          id,
          'The Smart Assistant',
          'Đã đến giờ đi ${location.name}. Đừng quên chụp ảnh kỷ niệm và check-in!',
          tz.TZDateTime.from(date, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        pending.add(
          PendingTripNotification(
            id: id,
            tripId: trip.id,
            tripTitle: trip.title,
            locationName: location.name,
            scheduledAt: date,
          ),
        );
      }
    }

    pending.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await _savePendingCache(pending);
  }

  Future<List<PendingTripNotification>> getPendingNotifications() async {
    await ensureInitialized();

    final requests = await _plugin.pendingNotificationRequests();
    final ids = requests.map((item) => item.id).toSet();

    final cache = await _loadPendingCache();
    final filtered = cache.where((item) => ids.contains(item.id)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (filtered.length != cache.length) {
      await _savePendingCache(filtered);
    }

    return filtered;
  }

  Future<void> cancelAllPendingNotifications() async {
    await ensureInitialized();
    await _plugin.cancelAll();
    await _savePendingCache(const <PendingTripNotification>[]);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final tripId = data['tripId']?.toString();
      if (tripId == null || tripId.isEmpty) {
        return;
      }

      final context = AppRoutes.navigatorKey.currentContext;
      if (context == null) {
        _initialPayload = payload;
        return;
      }

      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final tripProvider = Provider.of<TripPlannerProvider>(
        context,
        listen: false,
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
      appProvider.setTab(2);
      tripProvider.setActiveTrip(tripId);
    } catch (_) {
      // Ignore invalid payload.
    }
  }

  Future<void> _savePendingCache(List<PendingTripNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((item) => item.toMap()).toList());
    await prefs.setString(_pendingCacheKey, encoded);
  }

  Future<List<PendingTripNotification>> _loadPendingCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingCacheKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) => PendingTripNotification.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  int _notificationId(String tripId, String locationId) {
    final key = '$tripId|$locationId';
    return key.hashCode & 0x7fffffff;
  }
}
