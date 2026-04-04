import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/provider/auth_provider.dart';
import '../../notification/notification_service.dart';
import '../../notification/widgets/pending_notifications_widget.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.displayName;
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $userName',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Bạn muốn đi đâu hôm nay?',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _openNotifications(context),
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await NotificationService.instance
        .ensurePermissionRequestedOnFirstModuleAccess();

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: const SingleChildScrollView(
              child: PendingNotificationsWidget(),
            ),
          ),
        );
      },
    );
  }
}
