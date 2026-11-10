// lib/widgets/notification_center.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../provider.dart';
import '../services/local_push_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'fast_ui.dart';

class NotificationCenter extends StatelessWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);
    final notifications = provider.notifications;

    return Dialog(
      backgroundColor: context.fast.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FASTRadius.md),
        side: BorderSide(color: context.fast.line),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(FASTSpace.s16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      color: context.fast.t1,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: FASTText.item.copyWith(color: context.fast.t1),
                    ),
                    if (notifications.any((n) => !n.isRead))
                      Container(
                        margin: const EdgeInsetsDirectional.only(start: 8),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: FASTBrand.amber,
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
      child: SingleChildScrollView(
        child: FastEmpty(
          icon: Icons.notifications_off_outlined,
          title: tr(context, 'no_notifs'),
          subtitle: tr(context, 'notifs_hint'),
          accent: context.fast.t2,
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
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: notifications.length,
            separatorBuilder: (context, _) =>
                Divider(height: 1, thickness: 1, color: context.fast.line),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final unread = !notif.isRead;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.fast.cardHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(notif.type),
                        color: context.fast.t1,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: FASTText.body.copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: context.fast.t1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: FASTSpace.s8),
                              Text(
                                notif.timestamp,
                                style: FASTText.caption.copyWith(
                                  color: context.fast.t3,
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin: const EdgeInsetsDirectional.only(
                                    start: FASTSpace.s8,
                                    top: 4,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: FASTBrand.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: FASTSpace.s4),
                          Text(
                            notif.body,
                            style: FASTText.body.copyWith(
                              color: context.fast.t2,
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
        Divider(height: 1, thickness: 1, color: context.fast.line),
        const SizedBox(height: FASTSpace.s8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              activeProvider.clearNotifications();
            },
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: FASTBrand.error,
            ),
            label: Text(
              tr(context, 'clear_all'),
              style: FASTText.body.copyWith(
                color: FASTBrand.error,
                fontWeight: FontWeight.w700,
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
}

/// Shows a soft amber notice when the OS has notifications disabled for
/// the app (the request dialog stops appearing after a denial — only the
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
        margin: const EdgeInsets.only(bottom: FASTSpace.s12),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: context.fast.amberSoftBg,
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          border: Border.all(color: context.fast.amberSoftBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: context.fast.t1,
              size: 20,
            ),
            const SizedBox(width: FASTSpace.s8),
            Expanded(
              child: Text(
                tr(context, 'notif_off_banner'),
                style: FASTText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.fast.t1,
                ),
              ),
            ),
            TextButton(
              onPressed: () => LocalPushService.instance.openSystemSettings(),
              style: TextButton.styleFrom(foregroundColor: context.fast.t1),
              child: Text(
                tr(context, 'notif_enable'),
                style: FASTText.label.copyWith(letterSpacing: 0),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        onPressed: () => LocalPushService.instance.show(
          title: 'FAST',
          body: tr(context, 'notif_test_body'),
        ),
        style: TextButton.styleFrom(foregroundColor: context.fast.t2),
        icon: const Icon(Icons.send_outlined, size: 16),
        label: Text(tr(context, 'notif_test_send'), style: FASTText.caption),
      ),
    );
  }
}
