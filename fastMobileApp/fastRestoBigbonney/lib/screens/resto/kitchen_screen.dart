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
import '../../widgets/fast_night_surface.dart';
import '../../widgets/fast_ui.dart';
import 'client_proximity.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _orderService = OrderService();
  Timer? _uiTimer;
  bool _loaded = false;

  // The board is deliberately always dark: the night surface from the
  // brand, with the dark card and hairline of `FASTShades.dark`.
  static const _bg = FastNightSurface.bottom;
  static const _card = Color(0xFF16121B);
  static const _line = Color(0xFF2A2433);
  static const _t1 = FastNightSurface.onNight;
  static const _t3 = FastNightSurface.onNightMuted;

  // Status colours — same values and meaning as the Pro order cards.
  static const _green = FASTBrand.success; // new order / accept
  static const _violet = Color(0xFF8B5CF6); // preparing
  static const _blue = FASTBrand.info; // ready, client ETA
  static const _red = FASTBrand.error; // refuse, allergy, leave

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
        auth.user?.restaurantId ??
        auth.user?.restaurant?['id'] as String? ??
        prov.restaurantId;
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
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => FASTBrand.neonGradient.createShader(b),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 20, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'FAST PRO — ${fast.tr('kitchen').toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Live indicator
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(FASTRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: _green),
                  const SizedBox(width: 6),
                  Text(
                    fast.tr('live'),
                    style: FASTText.label.copyWith(color: _green),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width >= 600)
            Center(
              child: Text(
                auth.user?.name ?? '',
                style: FASTText.caption.copyWith(
                  color: _t3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            tooltip: fast.tr(auth.isRestaurant ? 'leave_kitchen' : 'logout'),
            icon: Icon(
              auth.isRestaurant ? Icons.close : Icons.logout,
              color: _red,
              size: 20,
            ),
            onPressed: auth.isLoggingOut
                ? null
                : () async {
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
              // The board is always dark, whatever the app theme: give the
              // empty state the dark shades.
              child: Theme(
                data: FASTTheme.dark(),
                child: FastEmpty(
                  icon: Icons.soup_kitchen_outlined,
                  title: fast.tr('no_orders'),
                  subtitle: fast.tr('no_orders_sub'),
                  accent: _t3,
                ),
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
                      mainAxisExtent:
                          (cols == 2 ? 330 : 360) *
                          MediaQuery.textScalerOf(ctx).scale(1),
                    ),
                    itemCount: active.length,
                    itemBuilder: (_, i) => _orderCard(active[i], prov),
                  ),
                );
              },
            ),
    );
  }

  /// Header chip: a filled pill. Colours come from the caller (proximity
  /// or ETA) — this only gives them a shape.
  Widget _chip(String text, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(FASTRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Order o, RestoProvider prov) {
    final fast = context.watch<FASTProvider>();
    Color statusColor;
    String statusLabel;
    switch (o.status) {
      case OrderStatus.placed:
        statusColor = _green;
        statusLabel = fast.tr('status_new');
        break;
      case OrderStatus.preparing:
        // Violet, not amber: yellow is reserved for "client is on the way"
        // (same rule as the Pro order cards).
        statusColor = _violet;
        statusLabel = fast.tr('status_prep');
        break;
      default:
        statusColor = _blue;
        statusLabel = fast.tr('status_ready');
    }

    // Client proximity, same rule as the Pro order cards (see
    // client_proximity.dart): green = not left yet, yellow = en route,
    // red = 2 min away or at the door.
    final prox = clientProximity(o);
    final Color? proxColor = prox?.color;
    final String? proxLabel = prox == null ? null : fast.tr(prox.labelKey);
    final accent = (prox?.tintsCard ?? false) ? prox!.color : statusColor;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header strip. The chips wrap under the order number on narrow
          // tickets instead of overflowing.
          Container(
            width: double.infinity,
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
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (o.groupCode != null) ...[
                  const SizedBox(width: 8),
                  _chip(
                    o.groupCode!,
                    FASTPro.teal.withValues(alpha: 0.18),
                    FASTPro.teal,
                    icon: Icons.group_outlined,
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (proxLabel != null)
                        _chip(
                          proxLabel,
                          proxColor ?? Colors.white24,
                          // Dark text on the yellow chip for contrast.
                          prox?.onColor ?? Colors.white,
                        ),
                      if (o.clientDelayMin > 0)
                        _chip(
                          fast
                              .tr('client_eta')
                              .replaceAll('{n}', '${o.clientDelayMin}'),
                          _blue,
                          Colors.white,
                        ),
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
                            fontFeatures: [FontFeature.tabularFigures()],
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
                                    fontSize: 12,
                                  ),
                                ),
                              if (item.allergyNotes.isNotEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: _red,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.allergyNotes,
                                        style: const TextStyle(
                                          color: _red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
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
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(FASTRadius.pill),
                      ),
                      // Prep countdown. Teal: a readout, not a status —
                      // amber here would read as "client en route".
                      child: Text(
                        _timerText(o),
                        style: FASTText.price.copyWith(
                          color: FASTPro.teal,
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
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                FASTRadius.pill,
                              ),
                              border: Border.all(
                                color: _green.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              "$t ${fast.tr('min_abbr')}",
                              style: const TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
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
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: const StadiumBorder(),
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
                          foregroundColor: _red,
                          side: const BorderSide(color: _red),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
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
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                if (o.status == OrderStatus.readyForPickup)
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                    ),
                    child: Text(
                      fast.tr('waiting_client'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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
