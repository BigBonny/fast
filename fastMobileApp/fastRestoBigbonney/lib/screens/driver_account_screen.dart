// lib/screens/driver_account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';

class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  final _deliveryService = DeliveryService();
  bool _loading = true;
  double _earningsPlaceholder = 0;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _deliveryService.getDriverProfile();
      if (!mounted) return;
      setState(() {
        _earningsPlaceholder =
            (profile['totalEarnings'] as num?)?.toDouble() ?? 0;
        _schedules = (profile['schedules'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final initial = (user?.name.isNotEmpty ?? false)
        ? user!.name[0].toUpperCase()
        : 'L';

    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr(context, 'driver_account'),
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: FASTBrand.onAmber,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? tr(context, 'driver_lbl'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.fast.t1,
                            ),
                          ),
                          if (user?.email.isNotEmpty ?? false)
                            Text(
                              user!.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.fast.t2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.fast.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.fast.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: Color(0xFFF59E0B),
                        size: 28,
                      ),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_earningsPlaceholder.toStringAsFixed(2)} €',
                            style: TextStyle(
                              color: context.fast.t1,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            tr(context, 'earnings_preview'),
                            style: TextStyle(
                              color: context.fast.t2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: context.fast.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.fast.line),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFF10B981),
                        ),
                        title: Text(
                          tr(context, 'my_planning'),
                          style: TextStyle(
                            color: context.fast.t1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _schedules.isEmpty
                              ? tr(context, 'no_slots')
                              : tr(
                                  context,
                                  'slots_count',
                                ).replaceAll('{n}', '${_schedules.length}'),
                          style: TextStyle(
                            color: context.fast.t2,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new,
                          color: context.fast.t3,
                          size: 18,
                        ),
                        onTap: () => launchUrl(
                          Uri.parse('https://fast-resto.app/livreur/planning'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      Divider(height: 1, color: context.fast.line),
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: Color(0xFFEF4444),
                        ),
                        title: Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.isLoggingOut) {
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    tr(context, 'logging_out'),
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Text(
                              tr(context, 'logout'),
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: Text(
                    tr(context, 'driver_tagline'),
                    style: TextStyle(color: context.fast.faint, fontSize: 11),
                  ),
                ),
              ],
            ),
    );
  }
}
