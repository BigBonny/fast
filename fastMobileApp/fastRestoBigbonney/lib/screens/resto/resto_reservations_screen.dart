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
    final restaurantId = context.read<RestoProvider>().restaurantId;
    if (restaurantId == null) {
      setState(() {
        _loading = false;
        _error = tr(context, 'load_err');
      });
      return;
    }
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
            content: Text(e is ApiException ? e.message : tr(context, 'load_err')),
          ),
        );
      }
    }
  }

  Color _statusColor(String status) => switch (status) {
    'CONFIRMED' => const Color(0xFF10B981),
    'DECLINED' || 'CANCELLED' => const Color(0xFFEF4444),
    _ => const Color(0xFFF59E0B),
  };

  String _statusLabel(String status) => switch (status) {
    'CONFIRMED' => tr(context, 'reservation_confirmed'),
    'DECLINED' || 'CANCELLED' => tr(context, 'reservation_declined'),
    _ => tr(context, 'reservation_pending'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: FASTPro.header,
        title: Text(tr(context, 'reservations')),
        iconTheme: const IconThemeData(color: Color(0xFFF1F5F9)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                tr(context, 'no_items'),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _buildCard(_items[i]),
                        ),
                ),
    );
  }

  Widget _buildCard(Reservation r) {
    final color = _statusColor(r.status);
    final dt = r.dateTime;
    final dateLabel =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.customerName.isEmpty ? '—' : r.customerName,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(r.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.people, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                '${r.partySize}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.note!,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
          if (r.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setStatus(r, 'DECLINED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    child: Text(tr(context, 'reservation_declined')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setStatus(r, 'CONFIRMED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr(context, 'reservation_confirmed')),
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
