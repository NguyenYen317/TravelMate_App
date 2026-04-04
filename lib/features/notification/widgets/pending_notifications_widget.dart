import 'package:flutter/material.dart';

import '../notification_service.dart';

class PendingNotificationsWidget extends StatefulWidget {
  const PendingNotificationsWidget({super.key});

  @override
  State<PendingNotificationsWidget> createState() =>
      _PendingNotificationsWidgetState();
}

class _PendingNotificationsWidgetState
    extends State<PendingNotificationsWidget> {
  bool _isLoading = false;
  List<PendingTripNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
    });

    final items = await NotificationService.instance.getPendingNotifications();

    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _cancelAll() async {
    setState(() {
      _isLoading = true;
    });

    await NotificationService.instance.cancelAllPendingNotifications();
    await _reload();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tắt tất cả thông báo đang chờ.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Smart Assistant Notifications',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Làm mới',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty)
              const Text('Không có thông báo nào đang chờ.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text('Đến giờ đi ${item.locationName}'),
                    subtitle: Text(
                      '${item.tripTitle} - ${_fmtDateTime(item.scheduledAt)}',
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _isLoading || _items.isEmpty ? null : _cancelAll,
              icon: const Icon(Icons.notifications_off_outlined),
              label: const Text('Tắt tất cả thông báo'),
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
