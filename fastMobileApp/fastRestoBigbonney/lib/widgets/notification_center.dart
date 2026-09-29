// lib/widgets/notification_center.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../theme.dart';

class NotificationCenter extends StatelessWidget {
        NotificationCenter({super.key});

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
                  children: [ Icon( Icons.notifications_active_outlined,
                      color: Color(0xFFF59E0B),
                    ),
                          SizedBox(width: 8), Text(
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
                ), IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: context.fast.t2),
                ),
              ],
            ),
                  Divider(color: context.fast.line, height: 24),
            
            // Notifications List
            Expanded(
              child: NotificationCenterList(provider: provider),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterList extends StatelessWidget {
  final FASTProvider? provider;
        NotificationCenterList({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    final activeProvider = provider ?? Provider.of<FASTProvider>(context);
    final notifications = activeProvider.notifications;

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ Icon( Icons.notifications_off_outlined,
                size: 48,
                color: context.fast.line,
              ),
                    SizedBox(height: 12), Text(
                'Vous êtes à jour !',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.fast.t2,
                ),
              ),
                    SizedBox(height: 4), Text(
                'Les notifications sur le statut de vos commandes apparaîtront ici.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.fast.t3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
                  border: Border.all(
                    color: context.fast.line,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIconColor(context, notif.type).withValues(alpha: 0.1),
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
                              ), Text(
                                notif.timestamp,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: context.fast.t3,
                                ),
                              ),
                            ],
                          ),
                                SizedBox(height: 4), Text(
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
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            label: const Text(
              'Tout effacer',
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
        return       Color(0xFF10B981); // Emerald 500
      case 'status':
        return       Color(0xFFF59E0B); // Amber 500
      case 'rating':
        return       Color(0xFF3B82F6); // Blue 500
      case 'info':
      default:
        return context.fast.t2; // Muted grey
    }
  }
}
