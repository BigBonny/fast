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
import '../../widgets/fast_parts.dart';
import '../../widgets/fast_ui.dart';
import 'client_proximity.dart';

/// Preparing = violet. Yellow is reserved for "client is on the way".
const Color _kPreparing = Color(0xFF8B5CF6);

/// Filled pill, 48 high, for the order actions (colour = meaning).
ButtonStyle _pillFilled(Color bg) => ElevatedButton.styleFrom(
  backgroundColor: bg,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 48),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
);

/// Outlined pill, 48 high, in the action's own colour.
ButtonStyle _pillOutline(Color color) => OutlinedButton.styleFrom(
  foregroundColor: color,
  side: BorderSide(color: color),
  minimumSize: const Size(0, 48),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
);

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
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        content: SizedBox(
          height: 400,
          width: 300,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FASTRadius.sm),
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
                      style: FASTText.body.copyWith(color: context.fast.t1),
                      decoration: InputDecoration(
                        hintText: tr(context, 'enter_code'),
                        hintStyle: TextStyle(color: context.fast.t3),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FASTRadius.sm),
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
                    icon: const Icon(Icons.check, color: FASTBrand.success),
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

  /// Typed pickup code entry — no camera. Used from the "Valider un
  /// code" button under each order card's scan-QR action.
  void _showCodeDialog(Order order) {
    final codeController = TextEditingController();
    var handled = false;

    Future<void> submit(BuildContext dialogContext) async {
      final v = codeController.text.trim();
      if (handled || v.isEmpty) return;
      handled = true;
      Navigator.pop(dialogContext);
      await _verifyPickup(order, v);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.fast.card,
        title: Text(
          tr(context, 'redeem_code'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: FASTText.price.copyWith(
              color: context.fast.t1,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '1234-FAST',
              hintStyle: TextStyle(color: context.fast.t3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FASTRadius.sm),
              ),
            ),
            onSubmitted: (_) => submit(dialogContext),
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
            onPressed: () => submit(dialogContext),
            style: _pillFilled(FASTBrand.success),
            child: Text(tr(context, 'validate_lbl')),
          ),
        ],
      ),
    ).whenComplete(codeController.dispose);
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
        padding: const EdgeInsetsDirectional.fromSTEB(
          FASTSpace.s16,
          FASTSpace.s16,
          FASTSpace.s16,
          96,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'orders_active'),
                  style: FASTText.title.copyWith(color: context.fast.t1),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FASTBrand.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(FASTRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: FASTBrand.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, 'live_lbl'),
                      style: FASTText.caption.copyWith(
                        color: FASTBrand.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          if (activeOrders.isEmpty)
            FastEmpty(
              icon: Icons.receipt_long_outlined,
              title: tr(context, 'no_active_orders'),
              subtitle: tr(context, 'orders_realtime_hint'),
              accent: context.fast.t2,
            ),
          ...activeOrders.map((o) => _buildOrderCard(o, rProv)),

          if (billedCancelledOrders.isNotEmpty) ...[
            const SizedBox(height: FASTSpace.s24),
            Divider(color: context.fast.line),
            const SizedBox(height: FASTSpace.s16),
            Text(
              fastLabelCase(context, tr(context, 'cancelled_billed')),
              style: FASTText.label.copyWith(color: context.fast.t2),
            ),
            const SizedBox(height: FASTSpace.s12),
            ...billedCancelledOrders.map((o) => _buildCancelledCard(o)),
          ],
        ],
      ),
    );
  }

  /// Header chip: a filled pill. Colours are passed in by the caller and
  /// carry the order's meaning — this only gives them a shape.
  Widget _headerChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FASTRadius.pill),
      ),
      child: Text(
        text,
        style: FASTText.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
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
    if (order.status == OrderStatus.placed) statusColor = FASTBrand.success;
    // Violet, not amber: yellow is reserved for "client is on the way" so
    // a freshly auto-accepted order never looks en route.
    if (order.status == OrderStatus.preparing) statusColor = _kPreparing;
    if (order.status == OrderStatus.readyForPickup) {
      statusColor = FASTBrand.info;
    }

    // Client proximity (see client_proximity.dart): green = not left yet,
    // yellow = en route, red = 2 min away or at the door.
    final prox = clientProximity(order);
    final Color? proxColor = prox?.color;
    final String? proxLabel = prox == null ? null : tr(context, prox.labelKey);
    final bool proxTints = prox?.tintsCard ?? false;
    final Color accentColor = proxTints ? prox!.color : statusColor;
    final bool enRouteYellow = prox == ClientProximity.enRoute;

    return Container(
      margin: const EdgeInsets.only(bottom: FASTSpace.s16),
      decoration: BoxDecoration(
        color: enRouteYellow
            ? kProxYellow.withValues(alpha: 0.08)
            : context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(
          color: accentColor.withValues(alpha: proxTints ? 0.9 : 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: FASTSpace.s16,
              vertical: FASTSpace.s12,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FASTRadius.md - 2),
              ),
            ),
            child: Wrap(
              spacing: FASTSpace.s8,
              runSpacing: FASTSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '#${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0)}',
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
                if (order.groupCode != null)
                  Text(
                    order.groupCode!,
                    style: FASTText.body.copyWith(
                      color: FASTPro.teal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (proxLabel != null)
                  _headerChip(
                    proxLabel,
                    proxColor ?? context.fast.faint,
                    prox?.onColor ?? Colors.white,
                  ),
                if (order.clientDelayMin > 0)
                  _headerChip(
                    tr(
                      context,
                      'client_eta',
                    ).replaceAll('{n}', '${order.clientDelayMin}'),
                    FASTBrand.info,
                    Colors.white,
                  ),
                Text(
                  orderStatusLabel(context, order.status),
                  style: FASTText.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(FASTSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_expandedOrders.contains(order.id))
                  InkWell(
                    onTap: () => setState(() => _expandedOrders.add(order.id)),
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: context.fast.t3,
                          ),
                          const SizedBox(width: FASTSpace.s8),
                          Expanded(
                            child: Text(
                              tr(
                                context,
                                'articles_count',
                              ).replaceAll('{n}', '${order.items.length}'),
                              style: FASTText.body.copyWith(
                                color: context.fast.t2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            tr(context, 'see_details'),
                            style: FASTText.caption.copyWith(
                              color: FASTPro.teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: FASTSpace.s4),
                          const Icon(
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
                      padding: const EdgeInsets.only(bottom: FASTSpace.s8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: FASTText.price.copyWith(
                              color: context.fast.t1,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(width: FASTSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.menuItem.name,
                                  style: FASTText.body.copyWith(
                                    color: context.fast.t1,
                                  ),
                                ),
                                if (item.selectedOptions.isNotEmpty)
                                  Text(
                                    item.selectedOptions.join(', '),
                                    style: FASTText.caption.copyWith(
                                      color: context.fast.t2,
                                    ),
                                  ),
                                if (item.allergyNotes.isNotEmpty)
                                  Text(
                                    '${tr(context, 'note_lbl')}: ${item.allergyNotes}',
                                    style: FASTText.caption.copyWith(
                                      color: FASTBrand.error,
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
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _expandedOrders.remove(order.id)),
                      style: TextButton.styleFrom(
                        foregroundColor: FASTPro.teal,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.expand_less, size: 18),
                      label: Text(
                        tr(context, 'reduce'),
                        style: FASTText.caption.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                if (order.fulfillmentType == FulfillmentType.pickup) ...[
                  const SizedBox(height: FASTSpace.s4),
                  // Base44-style approach bar: teal → magenta gradient fill
                  // showing how far along their walk the client is.
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: proxColor ?? context.fast.t3,
                      ),
                      const SizedBox(width: FASTSpace.s4),
                      Expanded(
                        child: Text(
                          tr(context, 'client_near').replaceAll(
                            '{n}',
                            '${(order.userWalkTimeMinutes * (1 - order.gpsProgress / 100)).ceil().clamp(0, 999)}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FASTText.caption.copyWith(
                            color: context.fast.t2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Text(
                        tr(context, 'pct_route').replaceAll(
                          '{n}',
                          '${order.gpsProgress.clamp(0, 100).round()}',
                        ),
                        style: FASTText.price.copyWith(
                          color: proxColor ?? context.fast.t3,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FASTRadius.pill),
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
                                  colors: [FASTPro.teal, FASTPro.magenta],
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
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${tr(context, 'total_lbl')}  ',
                              style: FASTText.body.copyWith(
                                color: context.fast.t2,
                              ),
                            ),
                            TextSpan(
                              text: fastPriceLabel(order.total),
                              style: FASTText.price.copyWith(
                                color: context.fast.t1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (order.status == OrderStatus.preparing)
                      Container(
                        margin: const EdgeInsetsDirectional.only(
                          start: FASTSpace.s12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FASTBrand.onAmber,
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          border: Border.all(color: context.fast.line),
                        ),
                        // Prep countdown. Teal: a readout, not a status —
                        // yellow/amber here would read as "en route".
                        child: Text(
                          timerText,
                          style: FASTText.price.copyWith(color: FASTPro.teal),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: FASTSpace.s16),

                if (order.status == OrderStatus.placed) ...[
                  Text(
                    fastLabelCase(context, tr(context, 'accept_in')),
                    style: FASTText.label.copyWith(color: context.fast.t2),
                  ),
                  const SizedBox(height: FASTSpace.s8),
                  Wrap(
                    spacing: FASTSpace.s8,
                    runSpacing: FASTSpace.s8,
                    children: [
                      for (final t in [5, 8, 10, 15, 20, 25])
                        InkWell(
                          onTap: () =>
                              _acceptOrder(order, rProv, prepMinutes: t),
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: FASTBrand.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                FASTRadius.pill,
                              ),
                              border: Border.all(
                                color: FASTBrand.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '$t min',
                              style: FASTText.price.copyWith(
                                color: FASTBrand.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: FASTSpace.s12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOrder(order, rProv),
                          style: _pillFilled(FASTBrand.success),
                          child: Text(tr(context, 'accept_auto')),
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s12),
                      OutlinedButton(
                        onPressed: () => _refuseOrder(order),
                        style: _pillOutline(FASTBrand.error),
                        child: Text(tr(context, 'decline')),
                      ),
                    ],
                  ),
                ],

                if (order.status == OrderStatus.preparing)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _markReady(order),
                              style: _pillFilled(FASTBrand.info),
                              child: Text(tr(context, 'ready_serve')),
                            ),
                          ),
                          if (order.fulfillmentType ==
                              FulfillmentType.pickup) ...[
                            const SizedBox(width: FASTSpace.s8),
                            IconButton.outlined(
                              tooltip: tr(context, 'scan_qr_title'),
                              onPressed: () => _showQrScanDialog(order),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                color: FASTBrand.success,
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: tr(context, 'redeem_code'),
                              onPressed: () => _showCodeDialog(order),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                Icons.pin_outlined,
                                color: FASTBrand.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: FASTSpace.s8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _refuseOrder(order),
                              style: _pillOutline(FASTBrand.error),
                              child: Text(
                                tr(context, 'decline'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: FASTSpace.s12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cancelOrder(order, true),
                              style: _pillOutline(FASTBrand.error),
                              child: Text(
                                tr(context, 'cancel_billed'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                if (order.status == OrderStatus.readyForPickup)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FASTSpace.s12,
                          vertical: FASTSpace.s8,
                        ),
                        decoration: BoxDecoration(
                          color: FASTBrand.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(FASTRadius.sm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              color: FASTBrand.info,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tr(context, 'client_enroute'),
                                style: FASTText.body.copyWith(
                                  color: FASTBrand.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FASTSpace.s12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showQrScanDialog(order),
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: Text(tr(context, 'scan_qr_btn')),
                          style: _pillFilled(FASTBrand.success),
                        ),
                      ),
                      const SizedBox(height: FASTSpace.s8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCodeDialog(order),
                          icon: const Icon(Icons.pin_outlined, size: 18),
                          label: Text(tr(context, 'redeem_code')),
                          style: _pillOutline(FASTBrand.success),
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
      margin: const EdgeInsets.only(bottom: FASTSpace.s8),
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '#${order.id.split('-').last}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FASTText.body.copyWith(color: context.fast.t2),
            ),
          ),
          const SizedBox(width: FASTSpace.s12),
          Text(
            fastPriceLabel(order.total),
            style: FASTText.price.copyWith(color: context.fast.t1),
          ),
        ],
      ),
    );
  }
}
