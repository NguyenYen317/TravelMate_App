import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../community/screens/community_screen.dart';
import '../../notification/notification_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../trip/screens/trip_planning_screen.dart';
import 'home_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Widget> _pages = const [
    HomePage(),
    SearchScreen(),
    TripPlanningScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  final Set<int> _shownInAppNotificationIds = <int>{};
  Timer? _pollTimer;
  OverlayEntry? _bannerEntry;
  Timer? _bannerAutoCloseTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.consumeInitialNotificationIntent();
    _startInAppNotificationPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bannerAutoCloseTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
    super.dispose();
  }

  void _startInAppNotificationPolling() {
    _checkAndShowInAppNotification();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkAndShowInAppNotification(),
    );
  }

  Future<void> _checkAndShowInAppNotification() async {
    if (!mounted) {
      return;
    }

    final pending = await NotificationService.instance
        .getPendingNotifications();
    if (!mounted || pending.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final candidates =
        pending
            .where(
              (item) =>
                  !_shownInAppNotificationIds.contains(item.id) &&
                  item.scheduledAt.isBefore(
                    now.add(const Duration(seconds: 45)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (candidates.isEmpty) {
      return;
    }

    final target = candidates.first;
    _shownInAppNotificationIds.add(target.id);
    _showFloatingInAppNotification(target);
  }

  void _showFloatingInAppNotification(PendingTripNotification item) {
    if (!mounted) {
      return;
    }

    _bannerAutoCloseTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final topInset = MediaQuery.of(context).padding.top;

    _bannerEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topInset + 10,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.notifications_active_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Assistant Notification',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Đã đến giờ đi ${item.locationName}'),
                        Text(
                          '${item.tripTitle} • ${_fmtDateTime(item.scheduledAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _dismissFloatingInAppNotification,
                    icon: const Icon(Icons.close),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_bannerEntry!);

    _bannerAutoCloseTimer = Timer(
      const Duration(seconds: 5),
      _dismissFloatingInAppNotification,
    );
  }

  void _dismissFloatingInAppNotification() {
    _bannerAutoCloseTimer?.cancel();
    _bannerAutoCloseTimer = null;
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      body: IndexedStack(index: appProvider.currentTabIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: BottomNavigationBar(
          currentIndex: appProvider.currentTabIndex,
          onTap: appProvider.setTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Khám phá',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_travel_outlined),
              activeIcon: Icon(Icons.card_travel),
              label: 'Chuyến đi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'AI gợi ý',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}
