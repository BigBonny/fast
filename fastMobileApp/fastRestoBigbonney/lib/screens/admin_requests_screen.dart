import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_exceptions.dart';
import '../l10n/tr.dart';
import '../services/restaurant_service.dart';
import '../theme.dart';

/// FAST-team pipeline: restaurants clients asked for. Each card keeps the
/// requester's contact info so ops can call the restaurant, onboard it,
/// and notify the client — status flows NEW → CONTACTED → ONBOARDED.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final _service = RestaurantService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String? _filter; // null = all

  static const _statuses = ['NEW', 'CONTACTED', 'ONBOARDED', 'DECLINED'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.listRestaurantRequests(status: _filter);
      if (!mounted) return;
      setState(() {
        _requests = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : tr(context, 'err_retry');
        _loading = false;
      });
    }
  }

  String _statusLabel(String status) => switch (status) {
    'CONTACTED' => tr(context, 'req_st_contacted'),
    'ONBOARDED' => tr(context, 'req_st_onboarded'),
    'DECLINED' => tr(context, 'req_st_declined'),
    _ => tr(context, 'req_st_new'),
  };

  Color _statusColor(String status) => switch (status) {
    'CONTACTED' => const Color(0xFF3B82F6),
    'ONBOARDED' => const Color(0xFF10B981),
    'DECLINED' => context.fast.t3,
    _ => const Color(0xFFF59E0B),
  };

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _call(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isNotEmpty) launchUrl(Uri.parse('tel:$cleaned'));
  }

  Future<void> _pickStatus(Map<String, dynamic> request) async {
    final current = '${request['status'] ?? 'NEW'}';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(ctx, 'admin_req_mark'),
                style: TextStyle(
                  color: ctx.fast.t1,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            for (final s in _statuses)
              ListTile(
                leading: Icon(
                  s == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _statusColor(s),
                  size: 20,
                ),
                title: Text(
                  _statusLabel(s),
                  style: TextStyle(color: ctx.fast.t1, fontSize: 14),
                ),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await _service.updateRestaurantRequestStatus('${request['id']}', picked);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : tr(context, 'err_retry')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        title: Text(tr(context, 'admin_req_title')),
        backgroundColor: context.fast.bg,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in [null, ..._statuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        s == null ? tr(context, 'admin_req_all') : _statusLabel(s),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _filter == s,
                      onSelected: (_) {
                        setState(() => _filter = s);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(_error!, style: TextStyle(color: context.fast.t3)),
                  )
                : _requests.isEmpty
                ? Center(
                    child: Text(
                      tr(context, 'admin_req_empty'),
                      style: TextStyle(color: context.fast.t3),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (_, i) => _requestCard(_requests[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final status = '${r['status'] ?? 'NEW'}';
    final phone = '${r['phone'] ?? ''}'.trim();
    final city = '${r['city'] ?? ''}'.trim();
    final address = '${r['address'] ?? ''}'.trim();
    final note = '${r['note'] ?? ''}'.trim();
    final userName = '${r['userName'] ?? ''}'.trim();
    final userEmail = '${r['userEmail'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r['name'] ?? ''}',
                  style: TextStyle(
                    color: context.fast.t1,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickStatus(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              city,
              address,
              _fmtDate(r['createdAt']),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: TextStyle(color: context.fast.t3, fontSize: 12),
          ),
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _call(phone),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 15,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '“$note”',
                style: TextStyle(
                  color: context.fast.t2,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (userName.isNotEmpty || userEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${tr(context, 'admin_req_client')}: '
                '${[userName, userEmail].where((s) => s.isNotEmpty).join(' · ')}',
                style: TextStyle(color: context.fast.t3, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
