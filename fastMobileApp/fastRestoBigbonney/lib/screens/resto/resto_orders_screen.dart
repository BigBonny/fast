import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../services/order_service.dart';
import '../../api/api_exceptions.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';

class RestoOrdersScreen extends StatefulWidget {
  const RestoOrdersScreen({super.key});

  @override
  State<RestoOrdersScreen> createState() => _RestoOrdersScreenState();
}

class _RestoOrdersScreenState extends State<RestoOrdersScreen> {
  Timer? _uiTimer;
  final _orderService = OrderService();
  final Set<String> _expandedOrders = {};

  @override
  void initState() {
    super.initState();
    // Refresh UI every second for countdown timers (only when there are active orders)
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<RestoProvider>();
      final hasActive = provider.restoOrders.any(
        (o) =>
            o.status == OrderStatus.placed || o.status == OrderStatus.preparing,
      );
      if (hasActive) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptOrder(
    Order order,
    RestoProvider rProv, {
    int? prepMinutes,
  }) async {
    try {
      await _orderService.updateOrderStatus(
        order.id,
        'PREPARING',
        prepTimeMinutes: prepMinutes,
      );
      if (!mounted) return;
      order.status = OrderStatus.preparing;
      order.prepStartedAt = DateTime.now().toIso8601String();
      final prepTimeMin =
          prepMinutes ??
          (rProv.isRushMode
              ? (rProv.settings?.rushPrepTime ?? 25)
              : (rProv.settings?.normalPrepTime ?? 15));
      order.prepTimerSeconds = prepTimeMin * 60;
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'accept_err'))));
      }
    }
  }

  Future<void> _markReady(Order order) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'READY_FOR_PICKUP');
      if (!mounted) return;
      order.status = OrderStatus.readyForPickup;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _refuseOrder(Order order) async {
    try {
      await _orderService.updateOrderStatus(order.id, 'CANCELLED');
      if (!mounted) return;
      order.status = OrderStatus.cancelled;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _cancelOrder(Order order, bool billAnyway) async {
    try {
      await _orderService.updateOrderStatus(
        order.id,
        'CANCELLED',
        isBilledAnyway: billAnyway,
      );
      if (!mounted) return;
      order.status = OrderStatus.cancelled;
      order.isBilledAnyway = billAnyway;
      setState(() {});
    } catch (_) {}
  }

  void _showQrScanDialog(Order order) {
    final controller = MobileScannerController();
    final codeController = TextEditingController();
    var handled = false;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.fast.card,
        title: Text(
          tr(context, 'scan_qr_title'),
          style: TextStyle(color: context.fast.t1),
        ),
        content: SizedBox(
          height: 400,
          width: 300,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 240,
                  width: 280,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) async {
                      if (handled) return;
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code == null || code.isEmpty) return;
                      handled = true;
                      Navigator.pop(dialogContext);
                      await _verifyPickup(order, code);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: context.fast.t1, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: tr(context, 'enter_code'),
                        hintStyle: TextStyle(color: context.fast.t3),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (v) async {
                        if (v.trim().isEmpty || handled) return;
                        handled = true;
                        Navigator.pop(dialogContext);
                        await _verifyPickup(order, v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check, color: Color(0xFF10B981)),
                    onPressed: () async {
                      final v = codeController.text.trim();
                      if (v.isEmpty || handled) return;
                      handled = true;
                      Navigator.pop(dialogContext);
                      await _verifyPickup(order, v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(dialogContext);
            },
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  Future<void> _verifyPickup(Order order, String token) async {
    try {
      final updated = await _orderService.verifyPickup(
        orderId: order.id,
        pickupToken: token,
      );
      order.status = updated.status;
      _onHandoverDone();
    } catch (e) {
      _showHandoverError(e);
    }
  }

  /// Code typed (or QR scanned) from the top bar — no need to find the
  /// order card first; the backend matches it among active pickups.
  Future<void> _redeemCode(String code) async {
    try {
      final updated = await _orderService.redeemPickup(code);
      if (!mounted) return;
      final rProv = context.read<RestoProvider>();
      for (final o in rProv.restoOrders) {
        if (o.id == updated.id) o.status = updated.status;
      }
      _onHandoverDone();
    } catch (e) {
      _showHandoverError(e);
    }
  }

  void _onHandoverDone() {
    if (!mounted) return;
    setState(() {});
    unawaited(context.read<RestoProvider>().refreshOrders());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr(context, 'handover_ok'))));
  }

  void _showHandoverError(Object e) {
    if (!mounted) return;
    final msg = e is ApiException && e.message.isNotEmpty
        ? e.message
        : tr(context, 'qr_invalid');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showRedeemDialog() {
    final controller = MobileScannerController();
    final codeController = TextEditingController();
    var handled = false;

    Future<void> submit(BuildContext dialogContext, String value) async {
      if (handled || value.trim().isEmpty) return;
      handled = true;
      Navigator.pop(dialogContext);
      await _redeemCode(value.trim());
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.fast.card,
        title: Text(
          tr(context, 'redeem_code'),
          style: TextStyle(color: context.fast.t1),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: context.fast.t1,
                  fontSize: 20,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '1234-FAST',
                  hintStyle: TextStyle(color: context.fast.t3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (v) => submit(dialogContext, v),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: 280,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null) submit(dialogContext, code);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
          ElevatedButton(
            onPressed: () => submit(dialogContext, codeController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text(tr(context, 'validate_lbl')),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
      codeController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rProv = Provider.of<RestoProvider>(context);

    final activeOrders = rProv.restoOrders
        .where(
          (o) =>
              o.status == OrderStatus.placed ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.readyForPickup,
        )
        .toList();
    final billedCancelledOrders = rProv.restoOrders
        .where((o) => o.status == OrderStatus.cancelled && o.isBilledAnyway)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(context, 'orders_active'),
                style: TextStyle(
                  color: context.fast.t1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, 'live_lbl'),
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showRedeemDialog,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: Text(tr(context, 'redeem_code')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          if (activeOrders.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Text(
                      tr(context, 'no_active_orders'),
                      style: TextStyle(
                        color: context.fast.t2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(context, 'orders_realtime_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.fast.t3, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ...activeOrders.map((o) => _buildOrderCard(o, rProv)),

          if (billedCancelledOrders.isNotEmpty) ...[
            SizedBox(height: 32),
            Divider(color: context.fast.line),
            SizedBox(height: 16),
            Text(
              tr(context, 'cancelled_billed'),
              style: TextStyle(
                color: context.fast.t1,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...billedCancelledOrders.map((o) => _buildCancelledCard(o)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, RestoProvider rProv) {
    String timerText = '--:--';
    if (order.status == OrderStatus.preparing && order.prepStartedAt != null) {
      final start = DateTime.parse(order.prepStartedAt!);
      final elapsed = DateTime.now().difference(start).inSeconds;
      final remaining = order.prepTimerSeconds - elapsed;
      if (remaining > 0) {
        final m = (remaining / 60).floor().toString().padLeft(2, '0');
        final s = (remaining % 60).toString().padLeft(2, '0');
        timerText = '$m:$s';
      } else {
        timerText = tr(context, 'late');
      }
    }
    Color statusColor = context.fast.faint;
    if (order.status == OrderStatus.placed) statusColor = Color(0xFF10B981);
    // Violet, not amber: yellow is reserved for "client is on the way" so
    // a freshly auto-accepted order never looks en route.
    if (order.status == OrderStatus.preparing) statusColor = Color(0xFF8B5CF6);
    if (order.status == OrderStatus.readyForPickup) {
      statusColor = Color(0xFF3B82F6);
    }

    // Client proximity — live gpsProgress pushed by the client app only
    // once they have genuinely started moving (or tapped "Je pars").
    // Yellow = en route, orange = close, red = at the door.
    Color? proxColor;
    String? proxLabel;
    if (order.fulfillmentType == FulfillmentType.pickup) {
      if (order.isReadyAtEntrance || order.gpsProgress >= 90) {
        proxColor = const Color(0xFFEF4444);
        proxLabel = tr(context, 'client_almost');
      } else if (order.gpsProgress >= 40) {
        proxColor = const Color(0xFFF97316);
        proxLabel = tr(context, 'prox_close');
      } else if (order.gpsProgress > 0) {
        proxColor = const Color(0xFFFACC15);
        proxLabel = tr(context, 'prox_far');
      } else {
        proxLabel = tr(context, 'client_not_left');
      }
    }
    final Color accentColor = proxColor ?? statusColor;
    final bool enRouteYellow = proxColor == const Color(0xFFFACC15);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: enRouteYellow
            ? const Color(
                0xFFFACC15,
              ).withValues(alpha: 0.08)
            : context.fast.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: proxColor != null ? 0.9 : 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '#${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0)}',
                  style: TextStyle(
                    color: context.fast.t1,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (order.groupCode != null)
                  Text(
                    order.groupCode!,
                    style: const TextStyle(
                      color: FASTPro.teal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (proxLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: proxColor ?? context.fast.faint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      proxLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (order.clientDelayMin > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tr(context, 'client_eta').replaceAll(
                        '{n}',
                        '${order.clientDelayMin}',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Text(
                  orderStatusLabel(context, order.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_expandedOrders.contains(order.id))
                  InkWell(
                    onTap: () =>
                        setState(() => _expandedOrders.add(order.id)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 16,
                            color: context.fast.t3,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(
                                context,
                                'articles_count',
                              ).replaceAll('{n}', '${order.items.length}'),
                              style: TextStyle(
                                color: context.fast.t2,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            tr(context, 'see_details'),
                            style: const TextStyle(
                              color: FASTPro.teal,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 18,
                            color: FASTPro.teal,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...order.items.map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: TextStyle(
                              color: context.fast.t1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.menuItem.name,
                                  style: TextStyle(color: context.fast.t1),
                                ),
                                if (item.selectedOptions.isNotEmpty)
                                  Text(
                                    item.selectedOptions.join(', '),
                                    style: TextStyle(
                                      color: context.fast.t2,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (item.allergyNotes.isNotEmpty)
                                  Text(
                                    '${tr(context, 'note_lbl')}: ${item.allergyNotes}',
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _expandedOrders.remove(order.id),
                      ),
                      icon: const Icon(Icons.expand_less, size: 16),
                      label: Text(
                        tr(context, 'reduce'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                if (order.fulfillmentType == FulfillmentType.pickup) ...[
                  const SizedBox(height: 4),
                  // Base44-style approach bar: teal → magenta gradient fill
                  // showing how far along their walk the client is.
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: proxColor ?? context.fast.t3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr(context, 'client_near').replaceAll(
                          '{n}',
                          '${(order.userWalkTimeMinutes * (1 - order.gpsProgress / 100)).ceil().clamp(0, 999)}',
                        ),
                        style: TextStyle(
                          color: context.fast.t2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tr(context, 'pct_route').replaceAll(
                          '{n}',
                          '${order.gpsProgress.clamp(0, 100).round()}',
                        ),
                        style: TextStyle(
                          color: proxColor ?? context.fast.t3,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Container(
                            color: context.fast.faint.withValues(alpha: 0.3),
                          ),
                          FractionallySizedBox(
                            widthFactor: (order.gpsProgress / 100).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00C8B3),
                                    Color(0xFFFF0066),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Divider(color: context.fast.line, height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr(context, 'total_lbl')}: €${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: context.fast.t1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (order.status == OrderStatus.preparing)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FASTBrand.onAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timerText,
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (order.status == OrderStatus.placed) ...[
                  Text(
                    tr(context, 'accept_in'),
                    style: TextStyle(
                      color: context.fast.t3,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in [5, 8, 10, 15, 20, 25])
                        InkWell(
                          onTap: () =>
                              _acceptOrder(order, rProv, prepMinutes: t),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '$t min',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOrder(order, rProv),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(tr(context, 'accept_auto')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _refuseOrder(order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        child: Text(tr(context, 'decline')),
                      ),
                    ],
                  ),
                ],

                if (order.status == OrderStatus.preparing)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markReady(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(tr(context, 'ready_serve')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (order.fulfillmentType == FulfillmentType.pickup) ...[
                        IconButton.outlined(
                          tooltip: tr(context, 'redeem_code'),
                          onPressed: () => _showQrScanDialog(order),
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton(
                        onPressed: () => _cancelOrder(order, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        child: Text(tr(context, 'cancel_billed')),
                      ),
                    ],
                  ),

                if (order.status == OrderStatus.readyForPickup)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: Color(0xFF3B82F6),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              tr(context, 'client_enroute'),
                              style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showQrScanDialog(order),
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: Text(
                            tr(context, 'scan_qr_btn'),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(Order order) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '#${order.id.split('-').last}',
            style: TextStyle(color: context.fast.t2),
          ),
          Text(
            '€${order.total.toStringAsFixed(2)}',
            style: TextStyle(
              color: context.fast.t1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
