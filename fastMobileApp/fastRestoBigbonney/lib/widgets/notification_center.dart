// lib/widgets/notification_center.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../provider.dart';
import '../services/local_push_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';

class NotificationCenter extends StatelessWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final notifications = provider.notifications;

    return Dialog(
      backgroundColor: context.fast.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: context.fast.line),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: context.fast.t1,
                      ),
                    ),
                    if (notifications.any((n) => !n.isRead))
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: context.fast.t2),
                ),
              ],
            ),
            Divider(color: context.fast.line, height: 24),

            // Notifications List
            Expanded(child: NotificationCenterList(provider: provider)),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterList extends StatelessWidget {
  final FASTProvider? provider;
  const NotificationCenterList({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    final activeProvider = provider ?? Provider.of<FASTProvider>(context);
    final notifications = activeProvider.notifications;

    return Column(
      children: [
        const _PushPermissionBanner(),
        Expanded(
          child: notifications.isEmpty
              ? _buildEmpty(context)
              : _buildList(context, activeProvider, notifications),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: context.fast.line,
              ),
              SizedBox(height: 12),
              Text(
                tr(context, 'no_notifs'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.fast.t2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                tr(context, 'notifs_hint'),
                style: TextStyle(fontSize: 11, color: context.fast.t3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildList(
    BuildContext context,
    FASTProvider activeProvider,
    List<PushNotification> notifications,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.fast.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.fast.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIconColor(
                          context,
                          notif.type,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIcon(notif.type),
                        color: _getIconColor(context, notif.type),
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: context.fast.t1,
                                  ),
                                ),
                              ),
                              Text(
                                notif.timestamp,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: context.fast.t3,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            notif.body,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.fast.t2,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Divider(color: context.fast.line, height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              activeProvider.clearNotifications();
            },
            icon: const Icon(
              Icons.delete_outline,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            label: Text(
              tr(context, 'clear_all'),
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'status':
        return Icons.restaurant_menu_outlined;
      case 'rating':
        return Icons.star_border_outlined;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(BuildContext context, String type) {
    switch (type) {
      case 'success':
        return Color(0xFF10B981); // Emerald 500
      case 'status':
        return Color(0xFFF59E0B); // Amber 500
      case 'rating':
        return Color(0xFF3B82F6); // Blue 500
      case 'info':
      default:
        return context.fast.t2; // Muted grey
    }
  }
}

/// Shows an amber warning when the OS has notifications disabled for the
/// app (the request dialog stops appearing after a denial — only the
/// settings screen can fix it). When enabled, offers a self-test button.
class _PushPermissionBanner extends StatefulWidget {
  const _PushPermissionBanner();

  @override
  State<_PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<_PushPermissionBanner>
    with WidgetsBindingObserver {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await LocalPushService.instance.isEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    if (enabled == null) return const SizedBox.shrink();
    if (!enabled) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(context, 'notif_off_banner'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: context.fast.t1,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  LocalPushService.instance.openSystemSettings(),
              child: Text(
                tr(context, 'notif_enable'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => LocalPushService.instance.show(
          title: 'FAST',
          body: tr(context, 'notif_test_body'),
        ),
        icon: const Icon(Icons.send_outlined, size: 14),
        label: Text(
          tr(context, 'notif_test_send'),
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}
