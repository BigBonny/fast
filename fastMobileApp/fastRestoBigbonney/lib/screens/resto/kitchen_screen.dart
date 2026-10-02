// lib/screens/resto/kitchen_screen.dart
//
// Kitchen display for STAFF/GUEST cook accounts — always dark, fullscreen,
// big readable order cards. No stats, no payments, no settings: just the
// live order board (polls every 15s via RestoProvider).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../theme.dart';

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
        auth.user?.restaurantId ?? auth.user?.restaurant?['id'] as String?;
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
      await _orderService.updateOrderStatus(o.id, 'PREPARING',
          prepTimeMinutes: prepMinutes);
      o.status = OrderStatus.preparing;
      o.prepStartedAt = DateTime.now().toIso8601String();
      final min = prepMinutes ??
          (prov.isRushMode
              ? (prov.settings?.rushPrepTime ?? 25)
              : (prov.settings?.normalPrepTime ?? 15));
      o.prepTimerSeconds = min * 60;
      setState(() {});
    } catch (_) {
      _toast('Erreur lors de l\'acceptation');
    }
  }

  Future<void> _ready(Order o) async {
    try {
      await _orderService.updateOrderStatus(o.id, 'READY_FOR_PICKUP');
      o.status = OrderStatus.readyForPickup;
      setState(() {});
    } catch (_) {
      _toast('Erreur — réessayez');
    }
  }

  Future<void> _refuse(Order o) async {
    try {
      await _orderService.updateOrderStatus(o.id, 'CANCELLED');
      o.status = OrderStatus.cancelled;
      setState(() {});
    } catch (_) {
      _toast('Erreur — réessayez');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _timerText(Order o) {
    if (o.status != OrderStatus.preparing || o.prepStartedAt == null) {
      return '--:--';
    }
    final elapsed =
        DateTime.now().difference(DateTime.parse(o.prepStartedAt!)).inSeconds;
    final remaining = o.prepTimerSeconds - elapsed;
    if (remaining <= 0) return 'EN RETARD';
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RestoProvider>();
    final auth = context.watch<AuthProvider>();

    final active = prov.restoOrders
        .where((o) =>
            o.status == OrderStatus.placed ||
            o.status == OrderStatus.preparing ||
            o.status == OrderStatus.readyForPickup)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (b) => FASTPro.logoGradient.createShader(b),
          child: const Text(
            '⚡ FAST PRO — CUISINE',
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
            child: const Row(
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                SizedBox(width: 5),
                Text('EN DIRECT',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: Text(
              auth.user?.name ?? '',
              style: const TextStyle(
                  color: _t3, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
            onPressed: () async {
              context.read<RestoProvider>().stopPolling();
              await auth.logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: FASTPro.teal))
          : active.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧑‍🍳', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('Aucune commande en cours',
                          style: TextStyle(
                              color: _t2,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Le tableau se met à jour automatiquement',
                          style: TextStyle(color: _t3, fontSize: 12)),
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
                          childAspectRatio: cols == 2 ? 1.05 : 1.35,
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
    Color statusColor;
    String statusLabel;
    switch (o.status) {
      case OrderStatus.placed:
        statusColor = const Color(0xFF10B981);
        statusLabel = 'NOUVELLE';
        break;
      case OrderStatus.preparing:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'EN PRÉPA';
        break;
      default:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'PRÊTE';
    }

    // Client proximity — green far / orange close / red at the door.
    Color? proxColor;
    String? proxLabel;
    if (o.fulfillmentType == FulfillmentType.pickup) {
      if (o.isReadyAtEntrance || o.gpsProgress >= 90) {
        proxColor = const Color(0xFFEF4444);
        proxLabel = 'CLIENT DEVANT';
      } else if (o.gpsProgress >= 40) {
        proxColor = const Color(0xFFF97316);
        proxLabel = 'CLIENT PROCHE';
      } else {
        proxColor = const Color(0xFF10B981);
        proxLabel = 'CLIENT EN ROUTE';
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
                Text('#${o.id.split('-').last}',
                    style: const TextStyle(
                        color: _t1,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                if (o.groupCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: FASTPro.teal.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('👥 ${o.groupCode!}',
                        style: const TextStyle(
                            color: FASTPro.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
                const Spacer(),
                if (proxLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: proxColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(proxLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10)),
                  ),
                const SizedBox(width: 8),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ],
            ),
          ),

          // Items — big and readable from across the kitchen
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...o.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity}×',
                              style: const TextStyle(
                                  color: FASTPro.teal,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.menuItem.name,
                                    style: const TextStyle(
                                        color: _t1,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                if (item.selectedOptions.isNotEmpty)
                                  Text(item.selectedOptions.join(', '),
                                      style: const TextStyle(
                                          color: _t3, fontSize: 11)),
                                if (item.allergyNotes.isNotEmpty)
                                  Text('⚠️ ${item.allergyNotes}',
                                      style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
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
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_timerText(o),
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
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
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text('$t min',
                                style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Accepter',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _refuse(o),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side:
                              const BorderSide(color: Color(0xFFEF4444)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Refuser'),
                      ),
                    ],
                  ),
                ],
                if (o.status == OrderStatus.preparing)
                  ElevatedButton.icon(
                    onPressed: () => _ready(o),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('PRÊT À SERVIR',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
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
                    child: const Center(
                      child: Text('EN ATTENTE DU CLIENT',
                          style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
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
