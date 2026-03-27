import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../trip/models/trip_models.dart';
import '../../trip/providers/trip_planner_provider.dart';

class TripSummary extends StatelessWidget {
  const TripSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer2<TripPlannerProvider, AppProvider>(
        builder: (context, tripProvider, appProvider, _) {
          final colorScheme = Theme.of(context).colorScheme;
          final items = _buildSummaryItems(tripProvider.trips);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chuyến đi của bạn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      'Bạn chưa có chuyến đi đang diễn ra hoặc sắp tới.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TripSummaryCard(
                        item: item,
                        onTap: () async {
                          await tripProvider.setActiveTrip(item.trip.id);
                          tripProvider.setSelectedDate(
                            _focusDateForTrip(item.trip),
                          );
                          appProvider.setTab(2);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_TripSummaryItem> _buildSummaryItems(List<Trip> trips) {
    final today = _onlyDate(DateTime.now());

    Trip? currentTrip;
    Trip? upcomingTrip;

    for (final trip in trips) {
      final start = _onlyDate(trip.startDate);
      final end = _onlyDate(trip.endDate);

      if ((today.isAtSameMomentAs(start) || today.isAfter(start)) &&
          (today.isAtSameMomentAs(end) || today.isBefore(end))) {
        currentTrip = trip;
      } else if (start.isAfter(today)) {
        if (upcomingTrip == null ||
            start.isBefore(_onlyDate(upcomingTrip.startDate))) {
          upcomingTrip = trip;
        }
      }
    }

    final result = <_TripSummaryItem>[];
    if (currentTrip != null) {
      result.add(
        _TripSummaryItem(
          trip: currentTrip,
          title: 'Đang khám phá',
          subtitle: currentTrip.title,
          icon: Icons.explore,
        ),
      );
    }
    if (upcomingTrip != null) {
      result.add(
        _TripSummaryItem(
          trip: upcomingTrip,
          title: 'Chuẩn bị khám phá',
          subtitle: upcomingTrip.title,
          icon: Icons.flight_takeoff,
        ),
      );
    }

    return result;
  }

  DateTime _focusDateForTrip(Trip trip) {
    final today = _onlyDate(DateTime.now());
    final start = _onlyDate(trip.startDate);
    final end = _onlyDate(trip.endDate);
    if (today.isBefore(start)) {
      return start;
    }
    if (today.isAfter(end)) {
      return end;
    }
    return today;
  }

  DateTime _onlyDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _TripSummaryItem {
  _TripSummaryItem({
    required this.trip,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final Trip trip;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.item, required this.onTap});

  final _TripSummaryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtDate(item.trip.startDate)} - ${_fmtDate(item.trip.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
