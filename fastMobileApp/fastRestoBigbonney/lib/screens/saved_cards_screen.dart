import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_exceptions.dart';
import '../l10n/tr.dart';
import '../theme.dart';

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> with WidgetsBindingObserver {
  final _api = ApiClient();
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  bool _busy = false;
  bool _pendingSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingSetup) {
      _pendingSetup = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(ApiConfig.paymentMethods) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _cards = data.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : tr(context, 'err_retry');
      });
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final data = await _api.post(ApiConfig.setupPaymentMethod) as Map<String, dynamic>;
      if (!mounted) return;
      final uri = Uri.parse(data['url'] as String);
      if (uri.scheme != 'https' || uri.host != 'checkout.stripe.com') {
        throw ApiException(tr(context, 'payment_unavailable'), 503);
      }
      _pendingSetup = true;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _pendingSetup = false;
        throw ApiException('Stripe', 503);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : tr(context, 'err_retry'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr(context, 'del')),
      content: Text('${card['brand']} •••• ${card['last4']}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, 'cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, 'del'))),
      ],
    ));
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _api.delete(ApiConfig.paymentMethod(card['id'] as String));
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : tr(context, 'err_retry'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'bank_card'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(tr(context, 'card_setup_info'), style: TextStyle(color: context.fast.t2)),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: FASTBrand.error)),
              TextButton(onPressed: _load, child: Text(tr(context, 'retry'))),
            ] else if (_cards.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(tr(context, 'no_saved_cards'))),
            for (final card in _cards)
              Card(child: ListTile(
                leading: const Icon(Icons.credit_card),
                title: Text('${card['brand']} •••• ${card['last4']}'),
                subtitle: Text(tr(context, 'card_expires').replaceAll('{n}', '${card['expMonth']}/${card['expYear']}')),
                trailing: IconButton(tooltip: tr(context, 'del'), onPressed: _busy ? null : () => _remove(card),
                    icon: const Icon(Icons.delete_outline, color: FASTBrand.error)),
              )),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _busy ? null : _add, icon: const Icon(Icons.add),
                label: Text(tr(context, 'card_add'))),
          ],
        ),
      ),
    );
  }
}
