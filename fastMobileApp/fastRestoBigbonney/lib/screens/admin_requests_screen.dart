import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_exceptions.dart';
import '../l10n/tr.dart';
import '../services/restaurant_service.dart';
import '../theme.dart';
import '../widgets/fast_ui.dart';

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
    'CONTACTED' => FASTBrand.info,
    'ONBOARDED' => FASTBrand.success,
    'DECLINED' => context.fast.t3,
    // New request: teal, the accent with no order-status meaning.
    _ => FASTPro.teal,
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr(ctx, 'admin_req_mark'),
                style: FASTText.title.copyWith(color: ctx.fast.t1),
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
                  style: FASTText.body.copyWith(
                    color: ctx.fast.t1,
                    fontWeight: FontWeight.w600,
                  ),
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
          content: Text(
            e is ApiException ? e.message : tr(context, 'err_retry'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        title: Text(
          tr(context, 'admin_req_title'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        backgroundColor: context.fast.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
              children: [
                for (final s in [null, ..._statuses])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: FASTSpace.s8,
                    ),
                    child: Center(
                      child: _filterChip(
                        s == null
                            ? tr(context, 'admin_req_all')
                            : _statusLabel(s),
                        _filter == s,
                        () {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = s);
                          _load();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: FASTPro.teal),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(FASTSpace.s24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: FASTText.body.copyWith(color: context.fast.t2),
                      ),
                    ),
                  )
                : _requests.isEmpty
                ? Center(
                    child: FastEmpty(
                      icon: Icons.inbox_outlined,
                      title: tr(context, 'admin_req_empty'),
                      accent: FASTPro.teal,
                    ),
                  )
                : RefreshIndicator(
                    color: FASTPro.teal,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(FASTSpace.s16),
                      itemCount: _requests.length,
                      itemBuilder: (_, i) => _requestCard(_requests[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Filter pill: teal when selected, outline otherwise.
  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final fast = context.fast;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: FASTSpace.s16,
          vertical: FASTSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? FASTPro.teal.withValues(alpha: 0.14) : fast.card,
          borderRadius: BorderRadius.circular(FASTRadius.pill),
          border: Border.all(color: selected ? FASTPro.teal : fast.line),
        ),
        child: Text(
          label,
          style: FASTText.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: selected
                ? (isDark ? FASTPro.teal : FASTPro.tealDark)
                : fast.t2,
          ),
        ),
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
      margin: const EdgeInsets.only(bottom: FASTSpace.s12),
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
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
                  style: FASTText.item.copyWith(color: context.fast.t1),
                ),
              ),
              const SizedBox(width: FASTSpace.s8),
              GestureDetector(
                onTap: () => _pickStatus(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FASTSpace.s12,
                    vertical: FASTSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(FASTRadius.pill),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: FASTText.caption.copyWith(
                      color: _statusColor(status),
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
            style: FASTText.caption.copyWith(color: context.fast.t2),
          ),
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _call(phone),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? FASTPro.teal
                          : FASTPro.tealDark,
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    Text(
                      phone,
                      style: FASTText.price.copyWith(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FASTPro.teal
                            : FASTPro.tealDark,
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
                style: FASTText.body.copyWith(
                  color: context.fast.t2,
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
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ),
        ],
      ),
    );
  }
}
