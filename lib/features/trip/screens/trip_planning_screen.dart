import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/models/place.dart';
import '../../../routes/app_routes.dart';
import '../../expense/providers/expense_provider.dart';
import '../../search/provider/search_provider.dart';
import '../models/trip_models.dart';
import '../providers/trip_planner_provider.dart';

class TripPlanningScreen extends StatefulWidget {
  const TripPlanningScreen({super.key});

  @override
  State<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends State<TripPlanningScreen> {
  final TextEditingController _tripTitleCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _locationNoteCtrl = TextEditingController();
  final Set<String> _selectedFavoritePlaceIds = <String>{};

  DateTimeRange? _tripRange;
  TimeOfDay? _tripStartTime;
  TimeOfDay? _tripEndTime;
  TimeOfDay? _locationTime;

  @override
  void dispose() {
    _tripTitleCtrl.dispose();
    _locationCtrl.dispose();
    _locationNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TripPlannerProvider, ExpenseProvider, SearchProvider>(
      builder: (context, tripProvider, expenseProvider, searchProvider, _) {
        if (!tripProvider.isReady || !expenseProvider.isReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeTrip = tripProvider.activeTrip;
        final selectedDate = tripProvider.selectedDate;

        return Scaffold(
          appBar: AppBar(title: const Text('Lập kế hoạch chuyến đi')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildCreateTripCard(
                context,
                tripProvider,
                searchProvider.favoritePlaces,
              ),
              const SizedBox(height: 12),
              if (tripProvider.trips.isNotEmpty)
                _buildTripSelector(context, tripProvider, expenseProvider),
              const SizedBox(height: 12),
              if (activeTrip != null) ...[
                _buildExpenseShortcut(context, activeTrip, expenseProvider),
                const SizedBox(height: 12),
                _buildCalendarCard(
                  context,
                  tripProvider,
                  activeTrip,
                  selectedDate,
                ),
                const SizedBox(height: 12),
                _buildAddLocationCard(
                  context,
                  tripProvider,
                  activeTrip,
                  selectedDate,
                ),
                const SizedBox(height: 12),
                _buildTimelineCard(
                  context,
                  tripProvider,
                  activeTrip,
                  selectedDate,
                ),
              ] else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có chuyến đi nào. Hãy tạo chuyến đi đầu tiên.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateTripCard(
    BuildContext context,
    TripPlannerProvider provider,
    List<Place> favoritePlaces,
  ) {
    final selectedFavoritePlaces = _selectedFavoritePlaces(favoritePlaces);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo chuyến đi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tripTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên chuyến đi',
                hintText: 'Ví dụ: Đà Nẵng 3N2Đ',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 2),
                  initialDateRange: _tripRange,
                );
                if (range == null) {
                  return;
                }
                setState(() {
                  _tripRange = range;
                });
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                _tripRange == null
                    ? 'Chọn khoảng ngày'
                    : '${_fmtDate(_tripRange!.start)} - ${_fmtDate(_tripRange!.end)}',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _tripStartTime ??
                            const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        _tripStartTime = picked;
                      });
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _tripStartTime == null
                          ? 'Giờ bắt đầu'
                          : 'Bắt đầu: ${_tripStartTime!.format(context)}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _tripEndTime ??
                            const TimeOfDay(hour: 18, minute: 0),
                      );
                      if (picked == null) {
                        return;
                      }
                      setState(() {
                        _tripEndTime = picked;
                      });
                    },
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      _tripEndTime == null
                          ? 'Giờ kết thúc'
                          : 'Kết thúc: ${_tripEndTime!.format(context)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (favoritePlaces.isEmpty)
              Text(
                'Thêm địa điểm vào Yêu thích ở tab Khám phá để tạo chuyến đi nhanh.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final selectedIds = await _showFavoritePlacesPicker(
                    context,
                    favoritePlaces,
                    initialSelection: selectedFavoritePlaces
                        .map((place) => place.id)
                        .toSet(),
                  );
                  if (selectedIds == null) {
                    return;
                  }
                  setState(() {
                    _selectedFavoritePlaceIds
                      ..clear()
                      ..addAll(selectedIds);
                  });
                },
                icon: const Icon(Icons.favorite_outline),
                label: Text(
                  selectedFavoritePlaces.isEmpty
                      ? 'Chọn địa điểm từ Yêu thích'
                      : 'Đã chọn ${selectedFavoritePlaces.length} địa điểm',
                ),
              ),
              if (selectedFavoritePlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedFavoritePlaces
                      .map(
                        (place) => InputChip(
                          label: Text(place.name),
                          onDeleted: () {
                            setState(() {
                              _selectedFavoritePlaceIds.remove(place.id);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                final title = _tripTitleCtrl.text.trim();
                if (title.isEmpty || _tripRange == null) {
                  _showSnack(
                    context,
                    'Nhập tên chuyến đi và chọn khoảng ngày.',
                  );
                  return;
                }
                final initialLocations = _buildLocationsFromFavoritePlaces(
                  selectedFavoritePlaces,
                  _tripRange!.start,
                );
                await provider.createTrip(
                  title: title,
                  start: _tripRange!.start,
                  end: _tripRange!.end,
                  startMinuteOfDay: _tripStartTime == null
                      ? null
                      : (_tripStartTime!.hour * 60) + _tripStartTime!.minute,
                  endMinuteOfDay: _tripEndTime == null
                      ? null
                      : (_tripEndTime!.hour * 60) + _tripEndTime!.minute,
                  initialLocations: initialLocations,
                );
                _tripTitleCtrl.clear();
                setState(() {
                  _tripRange = null;
                  _tripStartTime = null;
                  _tripEndTime = null;
                  _selectedFavoritePlaceIds.clear();
                });
              },
              child: const Text('Tạo chuyến đi'),
            ),
          ],
        ),
      ),
    );
  }

  List<Place> _selectedFavoritePlaces(List<Place> favoritePlaces) {
    return favoritePlaces
        .where((place) => _selectedFavoritePlaceIds.contains(place.id))
        .toList();
  }

  List<TripLocation> _buildLocationsFromFavoritePlaces(
    List<Place> favoritePlaces,
    DateTime tripStart,
  ) {
    final normalizedStart = DateTime(
      tripStart.year,
      tripStart.month,
      tripStart.day,
    );
    final seed = DateTime.now().microsecondsSinceEpoch;
    return favoritePlaces
        .asMap()
        .entries
        .map((entry) {
          final place = entry.value;
          final note = place.address.trim();
          return TripLocation(
            id: 'fav_${seed}_${entry.key}',
            name: place.name.trim(),
            day: normalizedStart,
            note: note.isEmpty ? null : note,
          );
        })
        .where((location) => location.name.isNotEmpty)
        .toList();
  }

  Future<Set<String>?> _showFavoritePlacesPicker(
    BuildContext context,
    List<Place> favoritePlaces, {
    required Set<String> initialSelection,
  }) {
    final selected = Set<String>.from(initialSelection);
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn địa điểm yêu thích',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selected.length}/${favoritePlaces.length} địa điểm được chọn',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: favoritePlaces.length,
                          itemBuilder: (context, index) {
                            final place = favoritePlaces[index];
                            final checked = selected.contains(place.id);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(place.name),
                              subtitle: Text(
                                place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selected.add(place.id);
                                  } else {
                                    selected.remove(place.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                selected.clear();
                              });
                            },
                            child: const Text('Bỏ chọn'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Hủy'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(Set<String>.from(selected)),
                            child: const Text('Xác nhận'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTripSelector(
    BuildContext context,
    TripPlannerProvider provider,
    ExpenseProvider expenseProvider,
  ) {
    final selectedTripId = provider.activeTrip?.id;
    final selectedTrip = provider.activeTrip;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedTripId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chọn chuyến đi'),
              items: provider.trips
                  .map(
                    (trip) => DropdownMenuItem<String>(
                      value: trip.id,
                      child: Text(trip.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                await provider.setActiveTrip(value);
              },
            ),
            if (selectedTrip != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_fmtDate(selectedTrip.startDate)} ${_fmtMinute(selectedTrip.startMinuteOfDay)} - ${_fmtDate(selectedTrip.endDate)} ${_fmtMinute(selectedTrip.endMinuteOfDay)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa chuyến đi',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await _showEditTripDialog(
                        context,
                        provider,
                        selectedTrip,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Xóa chuyến đi',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Xóa chuyến đi'),
                            content: const Text(
                              'Bạn có chắc muốn xóa chuyến đi này?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Hủy'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Xóa'),
                              ),
                            ],
                          );
                        },
                      );
                      if (shouldDelete == true) {
                        await provider.deleteTrip(selectedTrip.id);
                        await expenseProvider.deleteExpensesByTrip(
                          selectedTrip.id,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseShortcut(
    BuildContext context,
    Trip trip,
    ExpenseProvider expenseProvider,
  ) {
    final total = expenseProvider.totalByTrip(trip.id);
    return Card(
      child: ListTile(
        title: const Text('Quản lý chi phí'),
        subtitle: Text('Tổng hiện tại: ${_fmtCurrency(total)}'),
        trailing: FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamed(AppRoutes.expense, arguments: trip.id);
          },
          child: const Text('Mở chi phí'),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(
    BuildContext context,
    TripPlannerProvider provider,
    Trip trip,
    DateTime selectedDate,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TableCalendar<dynamic>(
          firstDay: trip.startDate,
          lastDay: trip.endDate,
          focusedDay: selectedDate,
          selectedDayPredicate: (day) => _isSameDate(day, selectedDate),
          calendarFormat: CalendarFormat.week,
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          onDaySelected: (selected, focused) {
            provider.setSelectedDate(selected);
          },
        ),
      ),
    );
  }

  Widget _buildAddLocationCard(
    BuildContext context,
    TripPlannerProvider provider,
    Trip trip,
    DateTime selectedDate,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thêm địa điểm cho ${_fmtDate(selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Tên địa điểm'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationNoteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _locationTime ?? TimeOfDay.now(),
                      );
                      if (time == null) {
                        return;
                      }
                      setState(() {
                        _locationTime = time;
                      });
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _locationTime == null
                          ? 'Chọn giờ (lịch trình)'
                          : _locationTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                final name = _locationCtrl.text.trim();
                if (name.isEmpty) {
                  _showSnack(context, 'Nhập tên địa điểm.');
                  return;
                }
                final minuteOfDay = _locationTime == null
                    ? null
                    : (_locationTime!.hour * 60) + _locationTime!.minute;

                await provider.addLocation(
                  tripId: trip.id,
                  name: name,
                  day: selectedDate,
                  minuteOfDay: minuteOfDay,
                  note: _locationNoteCtrl.text,
                );

                _locationCtrl.clear();
                _locationNoteCtrl.clear();
                setState(() {
                  _locationTime = null;
                });
              },
              child: const Text('Thêm địa điểm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    TripPlannerProvider provider,
    Trip trip,
    DateTime selectedDate,
  ) {
    final locations = provider.locationsByDay(trip.id, selectedDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch trình ngày ${_fmtDate(selectedDate)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhấn giữ biểu tượng kéo để sắp xếp địa điểm.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (locations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa có địa điểm trong ngày này.'),
              )
            else
              ReorderableListView.builder(
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: locations.length,
                onReorder: (oldIndex, newIndex) async {
                  await provider.reorderLocationsForDay(
                    tripId: trip.id,
                    day: selectedDate,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
                },
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return Card(
                    key: ValueKey(location.id),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(location.name),
                      subtitle: Text(
                        '${_minuteToLabel(location.minuteOfDay)}${location.note == null ? '' : ' - ${location.note}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.drag_indicator),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sửa địa điểm',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await _showEditLocationDialog(
                                context,
                                provider,
                                trip,
                                location,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Xóa địa điểm',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final shouldDelete = await _confirmDeleteLocation(
                                context,
                                location.name,
                              );
                              if (shouldDelete != true) {
                                return;
                              }
                              await provider.removeLocation(
                                tripId: trip.id,
                                locationId: location.id,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

  String _fmtCurrency(double amount) {
    final normalized = amount.toStringAsFixed(0);
    return '$normalized VND';
  }

  String _fmtMinute(int? minuteOfDay) {
    if (minuteOfDay == null) {
      return '';
    }
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _minuteToLabel(int? minuteOfDay) {
    if (minuteOfDay == null) {
      return 'Chưa đặt giờ';
    }
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<bool?> _confirmDeleteLocation(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa địa điểm'),
          content: Text('Bạn có chắc muốn xóa địa điểm "$name" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTripDialog(
    BuildContext context,
    TripPlannerProvider provider,
    Trip trip,
  ) async {
    final titleCtrl = TextEditingController(text: trip.title);
    DateTimeRange range = DateTimeRange(
      start: trip.startDate,
      end: trip.endDate,
    );
    var startMinuteOfDay = trip.startMinuteOfDay;
    var endMinuteOfDay = trip.endMinuteOfDay;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setDialogState) {
            return AlertDialog(
              title: const Text('Chỉnh sửa chuyến đi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên chuyến đi',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: stfContext,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                          initialDateRange: range,
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          range = picked;
                        });
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        '${_fmtDate(range.start)} - ${_fmtDate(range.end)}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final initial = startMinuteOfDay == null
                                  ? const TimeOfDay(hour: 8, minute: 0)
                                  : TimeOfDay(
                                      hour: startMinuteOfDay! ~/ 60,
                                      minute: startMinuteOfDay! % 60,
                                    );
                              final picked = await showTimePicker(
                                context: stfContext,
                                initialTime: initial,
                              );
                              if (picked == null) {
                                return;
                              }
                              setDialogState(() {
                                startMinuteOfDay =
                                    (picked.hour * 60) + picked.minute;
                              });
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              startMinuteOfDay == null
                                  ? 'Giờ bắt đầu'
                                  : 'Bắt đầu: ${_fmtMinute(startMinuteOfDay)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final initial = endMinuteOfDay == null
                                  ? const TimeOfDay(hour: 18, minute: 0)
                                  : TimeOfDay(
                                      hour: endMinuteOfDay! ~/ 60,
                                      minute: endMinuteOfDay! % 60,
                                    );
                              final picked = await showTimePicker(
                                context: stfContext,
                                initialTime: initial,
                              );
                              if (picked == null) {
                                return;
                              }
                              setDialogState(() {
                                endMinuteOfDay =
                                    (picked.hour * 60) + picked.minute;
                              });
                            },
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              endMinuteOfDay == null
                                  ? 'Giờ kết thúc'
                                  : 'Kết thúc: ${_fmtMinute(endMinuteOfDay)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      _showSnack(context, 'Nhập tên chuyến đi.');
                      return;
                    }

                    try {
                      await provider.updateTrip(
                        tripId: trip.id,
                        title: title,
                        start: range.start,
                        end: range.end,
                        startMinuteOfDay: startMinuteOfDay,
                        endMinuteOfDay: endMinuteOfDay,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        _showSnack(context, 'Đã cập nhật chuyến đi.');
                      }
                    } catch (error) {
                      _showSnack(context, error.toString());
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      titleCtrl.dispose();
    });
  }

  Future<void> _showEditLocationDialog(
    BuildContext context,
    TripPlannerProvider provider,
    Trip trip,
    TripLocation location,
  ) async {
    final nameCtrl = TextEditingController(text: location.name);
    final noteCtrl = TextEditingController(text: location.note ?? '');
    var day = location.day;
    var minuteOfDay = location.minuteOfDay;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setDialogState) {
            return AlertDialog(
              title: const Text('Chỉnh sửa địa điểm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên địa điểm',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: stfContext,
                          firstDate: trip.startDate,
                          lastDate: trip.endDate,
                          initialDate: day,
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          day = picked;
                        });
                      },
                      icon: const Icon(Icons.event),
                      label: Text(_fmtDate(day)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final initial = minuteOfDay == null
                            ? TimeOfDay.now()
                            : TimeOfDay(
                                hour: minuteOfDay! ~/ 60,
                                minute: minuteOfDay! % 60,
                              );
                        final picked = await showTimePicker(
                          context: stfContext,
                          initialTime: initial,
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          minuteOfDay = (picked.hour * 60) + picked.minute;
                        });
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(_minuteToLabel(minuteOfDay)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      _showSnack(context, 'Nhập tên địa điểm.');
                      return;
                    }

                    try {
                      await provider.updateLocation(
                        tripId: trip.id,
                        locationId: location.id,
                        name: name,
                        day: day,
                        minuteOfDay: minuteOfDay,
                        note: noteCtrl.text,
                      );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        _showSnack(context, 'Đã cập nhật địa điểm.');
                      }
                    } catch (error) {
                      _showSnack(context, error.toString());
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      nameCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  void _showSnack(BuildContext context, String message) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context) ??
          ScaffoldMessenger.maybeOf(this.context);
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
