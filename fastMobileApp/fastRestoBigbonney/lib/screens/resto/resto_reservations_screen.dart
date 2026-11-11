// lib/screens/resto/resto_reservations_screen.dart
//
// F10 — incoming table-reservation requests. The owner (or staff)
// confirms or declines each one.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_exceptions.dart';
import '../../l10n/tr.dart';
import '../../models.dart';
import '../../resto_provider.dart';
import '../../services/reservation_service.dart';
import '../../theme.dart';
import '../../widgets/fast_ui.dart';

class RestoReservationsScreen extends StatefulWidget {
  const RestoReservationsScreen({super.key});

  @override
  State<RestoReservationsScreen> createState() =>
      _RestoReservationsScreenState();
}

class _RestoReservationsScreenState extends State<RestoReservationsScreen> {
  final _service = ReservationService();
  List<Reservation> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The backend resolves the restaurant from the caller's account —
    // no need to gate on RestoProvider.restaurantId here.
    final restaurantId = context.read<RestoProvider>().restaurantId ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _service.restaurantReservations(restaurantId);
    } catch (e) {
      if (mounted) {
        _error = e is ApiException ? e.message : tr(context, 'load_err');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(Reservation r, String status) async {
    try {
      await _service.setStatus(r.id, status);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : tr(context, 'load_err'),
            ),
          ),
        );
      }
    }
  }

  // Reservation status: green = confirmed, red = declined/cancelled,
  // amber = waiting for an answer. Amber is a status here (pending), kept
  // with its value; this screen has no client-proximity yellow to clash
  // with.
  Color _statusColor(String status) => switch (status) {
    'CONFIRMED' => FASTBrand.success,
    'DECLINED' || 'CANCELLED' => FASTBrand.error,
    _ => FASTBrand.amber,
  };

  String _statusLabel(String status) => switch (status) {
    'CONFIRMED' => tr(context, 'reservation_confirmed'),
    'DECLINED' || 'CANCELLED' => tr(context, 'reservation_declined'),
    _ => tr(context, 'reservation_pending'),
  };

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        backgroundColor: fast.bg,
        title: Text(
          tr(context, 'reservations'),
          style: FASTText.title.copyWith(color: fast.t1),
        ),
        iconTheme: IconThemeData(color: fast.t1),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FASTPro.teal))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(FASTSpace.s24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: FASTText.body.copyWith(color: fast.t2),
                ),
              ),
            )
          : RefreshIndicator(
              color: FASTPro.teal,
              backgroundColor: fast.card,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        FastEmpty(
                          icon: Icons.event_available_outlined,
                          title: tr(context, 'no_items'),
                          accent: fast.t2,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(FASTSpace.s16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: FASTSpace.s12),
                      itemBuilder: (context, i) => _buildCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _meta(IconData icon, String text) {
    final fast = context.fast;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: fast.t3),
        const SizedBox(width: FASTSpace.s4),
        Text(
          text,
          style: FASTText.body.copyWith(
            color: fast.t2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Reservation r) {
    final fast = context.fast;
    final color = _statusColor(r.status);
    final dt = r.dateTime;
    final dateLabel =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.customerName.isEmpty ? '—' : r.customerName,
                  style: FASTText.item.copyWith(color: fast.t1),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(FASTRadius.pill),
                ),
                child: Text(
                  _statusLabel(r.status),
                  style: FASTText.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s8),
          Wrap(
            spacing: FASTSpace.s16,
            runSpacing: FASTSpace.s4,
            children: [
              _meta(Icons.schedule, dateLabel),
              _meta(Icons.people_outline, '${r.partySize}'),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: FASTSpace.s8),
            Text(r.note!, style: FASTText.caption.copyWith(color: fast.t2)),
          ],
          if (r.isPending) ...[
            const SizedBox(height: FASTSpace.s16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setStatus(r, 'DECLINED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FASTBrand.error,
                      side: const BorderSide(color: FASTBrand.error),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      tr(context, 'reservation_declined'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: FASTSpace.s12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setStatus(r, 'CONFIRMED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FASTBrand.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      tr(context, 'reservation_confirmed'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
