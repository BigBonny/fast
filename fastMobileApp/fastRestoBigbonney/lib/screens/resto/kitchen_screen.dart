// lib/screens/resto/kitchen_screen.dart
//
// Kitchen display for STAFF/GUEST cook accounts — always dark, fullscreen,
// big readable order cards. No stats, no payments, no settings: just the
// live order board (polls every 15s via RestoProvider).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../provider.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _orderService = OrderService();
  Timer? _uiTimer;
  bool _loaded = false;

  static const _bg = Color(0xFF020617);
  static const _card = Color(0xFF0F172A);
  static const _line = Color(0xFF1E293B);
  static const _t1 = Color(0xFFF1F5F9);
  static const _t2 = Color(0xFFCBD5E1);
  static const _t3 = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Tick every second so prep countdowns stay live.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final orders = context.read<RestoProvider>().restoOrders;
      if (orders.any((o) => o.status == OrderStatus.preparing)) {
        setState(() {});
      }
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<RestoProvider>();
    final restoId =
        auth.user?.restaurantId ?? auth.user?.restaurant?['id'] as String? ?? prov.restaurantId;
    if (restoId != null) {
      await prov.loadFromApi(restaurantId: restoId);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _accept(Order o, RestoProvider prov, {int? prepMinutes}) async {
    try {
      await _orderService.updateOrderStatus(
        o.id,
        'PREPARING',
        prepTimeMinutes: prepMinutes,
      );
      o.status = OrderStatus.preparing;
      o.prepStartedAt = DateTime.now().toIso8601String();
      final min =
          prepMinutes ??
          (prov.isRushMode
              ? (prov.settings?.rushPrepTime ?? 25)
              : (prov.settings?.normalPrepTime ?? 15));
      o.prepTimerSeconds = min * 60;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _toast(tr(context, 'err_retry'));
    }
  }

  Future<void> _ready(Order o) async {
    try {
      await _orderService.updateOrderStatus(o.id, 'READY_FOR_PICKUP');
      o.status = OrderStatus.readyForPickup;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _toast(tr(context, 'err_retry'));
    }
  }

  Future<void> _refuse(Order o) async {
    try {
      await _orderService.updateOrderStatus(o.id, 'CANCELLED');
      o.status = OrderStatus.cancelled;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _toast(tr(context, 'err_retry'));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timerText(Order o) {
    if (o.status != OrderStatus.preparing || o.prepStartedAt == null) {
      return '--:--';
    }
    final elapsed = DateTime.now()
        .difference(DateTime.parse(o.prepStartedAt!))
        .inSeconds;
    final remaining = o.prepTimerSeconds - elapsed;
    if (remaining <= 0) return context.read<FASTProvider>().tr('late');
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RestoProvider>();
    final auth = context.watch<AuthProvider>();
    final fast = context.watch<FASTProvider>();

    final active =
        prov.restoOrders
            .where(
              (o) =>
                  o.status == OrderStatus.placed ||
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.readyForPickup,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (b) => FASTPro.logoGradient.createShader(b),
          child: Text(
            '⚡ FAST PRO — ${fast.tr('kitchen').toUpperCase()}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          // Live indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                const SizedBox(width: 5),
                Text(
                  fast.tr('live'),
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width >= 600)
            Center(
            child: Text(
              auth.user?.name ?? '',
              style: const TextStyle(
                color: _t3,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: fast.tr(auth.isRestaurant ? 'leave_kitchen' : 'logout'),
            icon: Icon(auth.isRestaurant ? Icons.close : Icons.logout,
                color: const Color(0xFFEF4444), size: 20),
            onPressed: auth.isLoggingOut ? null : () async {
              if (auth.isRestaurant) {
                // Kitchen is pushed over the pro shell for owners — pop
                // back to it, falling back to the root if it somehow
                // became the first route.
                final popped = await Navigator.of(context).maybePop();
                if (!popped && context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              } else {
                context.read<RestoProvider>().stopPolling();
                auth.logout();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: FASTPro.teal))
          : active.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧑‍🍳', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    fast.tr('no_orders'),
                    style: const TextStyle(
                      color: _t2,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fast.tr('no_orders_sub'),
                    style: const TextStyle(color: _t3, fontSize: 12),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (ctx, constraints) {
                // Kitchen tablets get a 2-column grid, phones a list.
                final cols = constraints.maxWidth > 720 ? 2 : 1;
                return RefreshIndicator(
                  color: FASTPro.teal,
                  backgroundColor: _card,
                  onRefresh: () => prov.refreshOrders(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: (cols == 2 ? 330 : 360) * MediaQuery.textScalerOf(ctx).scale(1),
                    ),
                    itemCount: active.length,
                    itemBuilder: (_, i) => _orderCard(active[i], prov),
                  ),
                );
              },
            ),
    );
  }

  Widget _orderCard(Order o, RestoProvider prov) {
    final fast = context.watch<FASTProvider>();
    Color statusColor;
    String statusLabel;
    switch (o.status) {
      case OrderStatus.placed:
        statusColor = const Color(0xFF10B981);
        statusLabel = fast.tr('status_new');
        break;
      case OrderStatus.preparing:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = fast.tr('status_prep');
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = fast.tr('status_ready');
    }

    // Client proximity — green far / orange close / red at the door.
    Color? proxColor;
    String? proxLabel;
    if (o.fulfillmentType == FulfillmentType.pickup) {
      if (o.isReadyAtEntrance || o.gpsProgress >= 90) {
        proxColor = const Color(0xFFEF4444);
        proxLabel = fast.tr('prox_here');
      } else if (o.gpsProgress >= 40) {
        proxColor = const Color(0xFFF97316);
        proxLabel = fast.tr('prox_close');
      } else {
        proxColor = const Color(0xFF10B981);
        proxLabel = fast.tr('prox_far');
      }
    }
    final accent = proxColor ?? statusColor;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: accent.withValues(alpha: 0.12),
            child: Row(
              children: [
                Text(
                  '#${o.id.substring(o.id.length > 6 ? o.id.length - 6 : 0)}',
                  style: const TextStyle(
                    color: _t1,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (o.groupCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: FASTPro.teal.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '👥 ${o.groupCode!}',
                      style: const TextStyle(
                        color: FASTPro.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (proxLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: proxColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      proxLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Items — big and readable from across the kitchen
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...o.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                            color: FASTPro.teal,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.menuItem.name,
                                style: const TextStyle(
                                  color: _t1,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item.selectedOptions.isNotEmpty)
                                Text(
                                  item.selectedOptions.join(', '),
                                  style: const TextStyle(
                                    color: _t3,
                                    fontSize: 11,
                                  ),
                                ),
                              if (item.allergyNotes.isNotEmpty)
                                Text(
                                  '⚠️ ${item.allergyNotes}',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer: timer + actions
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (o.status == OrderStatus.preparing)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _timerText(o),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (o.status == OrderStatus.placed) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final t in [5, 8, 10, 15, 20])
                        InkWell(
                          onTap: () => _accept(o, prov, prepMinutes: t),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              "$t ${fast.tr('min_abbr')}",
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _accept(o, prov),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            fast.tr('accept'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _refuse(o),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(fast.tr('refuse')),
                      ),
                    ],
                  ),
                ],
                if (o.status == OrderStatus.preparing)
                  ElevatedButton.icon(
                    onPressed: () => _ready(o),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text(
                      fast.tr('ready_serve'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                if (o.status == OrderStatus.readyForPickup)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        fast.tr('waiting_client'),
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
