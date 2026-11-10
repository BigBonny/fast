import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api_exceptions.dart';
import '../provider.dart';
import '../providers/auth_provider.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import '../widgets/fast_ui.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _service = GroupService();
  final _codeController = TextEditingController();
  int _shakeTick = 0;
  Map<String, dynamic>? _group;
  Timer? _refreshTimer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreActiveGroup();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restoreActiveGroup() async {
    try {
      final provider = context.read<FASTProvider>();
      if (provider.activeGroupId != null) {
        await _refresh(provider.activeGroupId!);
      } else {
        final groups = await _service.getMyGroups();
        if (groups.isNotEmpty) {
          await _setGroup(Map<String, dynamic>.from(groups.first as Map));
        }
      }
    } catch (_) {
      // No active group is a valid empty state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final id = _group?['id'] as String?;
      if (id != null) _refresh(id, quiet: true);
    });
  }

  Future<void> _setGroup(Map<String, dynamic> data) async {
    if (!mounted) return;
    final previousStatus = _group?['status'] as String?;
    setState(() {
      _group = data;
      _loading = false;
      _error = null;
    });
    context.read<FASTProvider>().setActiveGroup(
      id: data['id'] as String?,
      code: data['code'] as String?,
      restaurantId: data['restaurantId'] as String?,
    );
    _startPolling();
    final status = data['status'] as String? ?? 'OPEN';
    if (status == 'SUBMITTED' && previousStatus != 'SUBMITTED') {
      HapticFeedback.mediumImpact();
      context.read<FASTProvider>().navigateToScreen('commandes');
    }
  }

  Future<void> _refresh(String id, {bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = true);
    try {
      await _setGroup(await _service.getGroup(id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (!quiet) _error = _message(e);
        });
      }
    }
  }

  Future<void> _create() async {
    final provider = context.read<FASTProvider>();
    if (provider.restaurants.isEmpty) {
      setState(() => _error = provider.tr('no_resto_avail'));
      return;
    }
    String restaurantId =
        provider.selectedRestaurant?.id ?? provider.restaurants.first.id;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.fast.card,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(
              FASTSpace.s16,
              FASTSpace.s24,
              FASTSpace.s16,
              FASTSpace.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.tr('choose_resto'),
                  style: FASTText.title.copyWith(color: context.fast.t1),
                ),
                const SizedBox(height: FASTSpace.s8),
                Text(
                  provider.tr('group_sub'),
                  style: FASTText.body.copyWith(color: context.fast.t2),
                ),
                const SizedBox(height: FASTSpace.s24),
                DropdownButtonFormField<String>(
                  initialValue: restaurantId,
                  isExpanded: true,
                  dropdownColor: context.fast.card,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  style: FASTText.body.copyWith(color: context.fast.t1),
                  icon: Icon(Icons.keyboard_arrow_down, color: context.fast.t2),
                  decoration: _fieldDecoration(
                    context,
                  ).copyWith(labelText: provider.tr('restaurant_lbl')),
                  items: provider.restaurants
                      .map(
                        (restaurant) => DropdownMenuItem(
                          value: restaurant.id,
                          child: Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => restaurantId = value);
                    }
                  },
                ),
                const SizedBox(height: FASTSpace.s24),
                FastButton(
                  label: provider.tr('create_group'),
                  kind: FastButtonKind.ink,
                  onPressed: () => Navigator.pop(sheetContext, restaurantId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _loading = true);
    try {
      await _setGroup(await _service.createGroup(restaurantId: selected));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _join() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await _setGroup(
        await _service.joinGroup(_codeController.text.trim().toUpperCase()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
          _shakeTick++;
        });
      }
    }
  }

  Future<void> _action(Future<Map<String, dynamic>> Function() callback) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _setGroup(await callback());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  /// Members leave; the host cancels the whole group, and every share
  /// already paid is refunded in full.
  Future<void> _leave({bool isHost = false, int paidCount = 0}) async {
    final id = _group?['id'] as String?;
    if (id == null) return;
    if (isHost) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(ctx, 'group_cancel')),
          content: Text(
            paidCount > 0
                ? tr(
                    ctx,
                    'group_cancel_paid_confirm',
                  ).replaceAll('{n}', '$paidCount')
                : tr(ctx, 'group_cancel_confirm'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(ctx, 'back')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(ctx, 'confirm')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final result = await _service.leaveGroup(id);
      _refreshTimer?.cancel();
      if (!mounted) return;
      final refunded = (result['refunded'] as num?)?.toInt() ?? 0;
      if (refunded > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'group_cancelled_refunded',
              ).replaceAll('{n}', '$refunded'),
            ),
          ),
        );
      }
      context.read<FASTProvider>().clearActiveGroup();
      setState(() {
        _group = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _orderMyPart() {
    final restaurantId = _group?['restaurantId'] as String?;
    if (restaurantId == null) return;
    final provider = context.read<FASTProvider>();
    provider.setActiveGroup(
      id: _group!['id'] as String,
      code: _group!['code'] as String?,
      restaurantId: restaurantId,
    );
    provider.navigateToScreen('restaurant');
  }

  Future<void> _copyInvite() async {
    final code = _group?['code'] as String? ?? '';
    final message = context
        .read<FASTProvider>()
        .tr('share_msg')
        .replaceAll('{n}', code);
    try {
      await Share.share(message, subject: tr(context, 'group_invite'));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<FASTProvider>().tr('copied'))),
      );
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : context.read<FASTProvider>().tr('generic_error');

  /// Inputs on this screen: radius 12, `cardHigh` fill, ink focus ring.
  static InputDecoration _fieldDecoration(BuildContext context) {
    final fast = context.fast;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      filled: true,
      fillColor: fast.cardHigh,
      hintStyle: FASTText.body.copyWith(color: fast.t3),
      labelStyle: FASTText.body.copyWith(color: fast.t2),
      floatingLabelStyle: FASTText.body.copyWith(color: fast.t1),
      border: border(fast.line),
      enabledBorder: border(fast.line),
      focusedBorder: border(fast.ink, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: FASTBrand.amber),
      );
    }
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.fast.bg,
        titleSpacing: FASTSpace.s16,
        title: Text(
          context.watch<FASTProvider>().tr('group_order'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = _group?['id'] as String?;
          if (id != null) await _refresh(id, quiet: true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s8,
            FASTSpace.s16,
            100,
          ),
          children: [
            if (_error != null) _errorBanner(),
            if (_group == null) _welcome() else _dashboard(),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: FASTSpace.s16),
    padding: const EdgeInsets.all(FASTSpace.s12),
    decoration: BoxDecoration(
      color: FASTBrand.error.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      border: Border.all(color: FASTBrand.error.withValues(alpha: 0.45)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: FASTBrand.error, size: 20),
        const SizedBox(width: FASTSpace.s12),
        Expanded(
          child: Text(
            _error!,
            style: FASTText.body.copyWith(color: context.fast.t1),
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text) => Text(
    fastLabelCase(context, text),
    style: FASTText.label.copyWith(color: context.fast.t2),
  );

  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FastEmpty(
        icon: Icons.groups_2_outlined,
        title: context.watch<FASTProvider>().tr('group_tagline'),
        action: FastButton(
          label: context.watch<FASTProvider>().tr('create_group'),
          icon: Icons.add,
          kind: FastButtonKind.ink,
          onPressed: _create,
        ),
      ),
      Container(
        padding: const EdgeInsets.all(FASTSpace.s16),
        decoration: BoxDecoration(
          color: context.fast.card,
          borderRadius: BorderRadius.circular(FASTRadius.md),
          border: Border.all(color: context.fast.line),
        ),
        child: Text(
          context.watch<FASTProvider>().tr('group_steps'),
          style: FASTText.body.copyWith(color: context.fast.t2, height: 1.7),
        ),
      ),
      const SizedBox(height: FASTSpace.s40),
      _sectionLabel(context.watch<FASTProvider>().tr('join_code')),
      const SizedBox(height: FASTSpace.s8),
      FastShake(
        trigger: _shakeTick,
        child: TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: FASTText.item.copyWith(color: context.fast.t1),
          decoration: _fieldDecoration(context).copyWith(
            hintText: 'FAST-XXXXXXXX',
            prefixIcon: Icon(Icons.key_outlined, color: context.fast.t2),
            suffixIcon: IconButton(
              tooltip: context.read<FASTProvider>().tr('join'),
              onPressed: _join,
              icon: Icon(Icons.arrow_forward, color: context.fast.t1),
            ),
          ),
          onSubmitted: (_) => _join(),
        ),
      ),
    ],
  );

  Widget _dashboard() {
    final group = _group!;
    final members = (group['members'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final authUserId = context.read<AuthProvider>().user?.id;
    final isHost =
        group['isHost'] as bool? ??
        ((group['hostUserId'] as String?) == authUserId);
    final status = group['status'] as String? ?? 'OPEN';
    final paidCount = members
        .where((member) => member['paymentStatus'] == 'PAID')
        .length;
    final total = members.fold<double>(
      0,
      (sum, member) => sum + ((member['total'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context.watch<FASTProvider>().tr('group_code')),
                  const SizedBox(height: FASTSpace.s4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      group['code'] as String? ?? '',
                      maxLines: 1,
                      style: FASTText.display.copyWith(
                        color: context.fast.t1,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            IconButton(
              tooltip: tr(context, 'copy_invite'),
              onPressed: _copyInvite,
              style: IconButton.styleFrom(
                backgroundColor: context.fast.cardHigh,
                foregroundColor: context.fast.t1,
                side: BorderSide(color: context.fast.line),
              ),
              icon: const Icon(Icons.ios_share_outlined, size: 20),
            ),
            const SizedBox(width: FASTSpace.s4),
            TextButton(
              onPressed: () => _leave(isHost: isHost, paidCount: paidCount),
              style: TextButton.styleFrom(
                foregroundColor: context.fast.t2,
                textStyle: FASTText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Text(
                isHost
                    ? tr(context, 'group_cancel')
                    : context.read<FASTProvider>().tr('quit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FASTSpace.s24),
        _progress(status),
        const SizedBox(height: FASTSpace.s24),
        Container(
          padding: const EdgeInsets.all(FASTSpace.s16),
          decoration: BoxDecoration(
            color: context.fast.card,
            borderRadius: BorderRadius.circular(FASTRadius.md),
            border: Border.all(color: context.fast.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _summary(
                  tr(context, 'members'),
                  '${members.length}',
                  Icons.people_outline,
                ),
              ),
              Expanded(
                child: _summary(
                  tr(context, 'parts_paid'),
                  '$paidCount/${members.length}',
                  Icons.verified_outlined,
                ),
              ),
              Expanded(
                child: _summary(
                  tr(context, 'total'),
                  '${total.toStringAsFixed(2)} €',
                  Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FASTSpace.s40),
        _sectionLabel(tr(context, 'participants')),
        const SizedBox(height: FASTSpace.s12),
        ...members.map(_memberCard),
        const SizedBox(height: FASTSpace.s24),
        if (status == 'OPEN')
          FastButton(
            label: tr(context, 'pay_share'),
            icon: Icons.restaurant_menu,
            kind: FastButtonKind.ink,
            onPressed: _orderMyPart,
          ),
        if (isHost && status == 'OPEN') ...[
          const SizedBox(height: FASTSpace.s12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _action(() => _service.lockGroup(group['id'] as String)),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.fast.t1,
                side: BorderSide(color: context.fast.faint),
                shape: const StadiumBorder(),
                textStyle: FASTText.body.copyWith(fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(tr(context, 'close_invites')),
            ),
          ),
        ],
        if (isHost && status == 'LOCKED') ...[
          FastButton(
            label: paidCount == 0
                ? tr(context, 'waiting_payment')
                : tr(context, 'send_parts').replaceAll('{n}', '$paidCount'),
            icon: Icons.send_outlined,
            kind: FastButtonKind.ink,
            onPressed: paidCount == 0
                ? null
                : () => _action(
                    () => _service.submitGroup(group['id'] as String),
                  ),
          ),
          const SizedBox(height: FASTSpace.s8),
          Text(
            tr(context, 'group_unpaid_warn'),
            textAlign: TextAlign.center,
            style: FASTText.caption.copyWith(color: context.fast.t2),
          ),
        ],
        if (status == 'SUBMITTED') const _SubmittedCard(),
      ],
    );
  }

  Widget _progress(String status) {
    final steps = ['OPEN', 'LOCKED', 'SUBMITTED'];
    final current = steps.indexOf(status).clamp(0, 2);
    final labels = [
      tr(context, 'invites_lbl'),
      tr(context, 'payments_lbl'),
      tr(context, 'sent_lbl'),
    ];
    return Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index <= current
                      ? FASTBrand.amber
                      : context.fast.faint,
                  borderRadius: BorderRadius.circular(FASTRadius.pill),
                ),
              ),
              const SizedBox(height: FASTSpace.s8),
              Text(
                labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: FASTText.caption.copyWith(
                  color: index <= current ? context.fast.t1 : context.fast.t3,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: context.fast.t2, size: 20),
      const SizedBox(height: FASTSpace.s8),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FASTText.price.copyWith(color: context.fast.t1),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: FASTText.caption.copyWith(color: context.fast.t2),
      ),
    ],
  );

  Widget _memberCard(Map<String, dynamic> member) {
    final user = member['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? tr(context, 'participant');
    final paymentStatus = member['paymentStatus'] as String? ?? 'DRAFT';
    final paid = paymentStatus == 'PAID';
    return Container(
      margin: const EdgeInsets.only(bottom: FASTSpace.s8),
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: paid
                ? FASTBrand.success.withValues(alpha: 0.16)
                : context.fast.cardHigh,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: FASTText.item.copyWith(
                color: paid ? FASTBrand.success : context.fast.t1,
              ),
            ),
          ),
          const SizedBox(width: FASTSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.body.copyWith(
                    color: context.fast.t1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paid
                      ? tr(context, 'part_paid')
                      : paymentStatus == 'READY'
                      ? tr(context, 'paying')
                      : tr(context, 'compose_part'),
                  style: FASTText.caption.copyWith(
                    color: paid ? FASTBrand.success : context.fast.t2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FASTSpace.s8),
          Text(
            '${((member['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} €',
            style: FASTText.price.copyWith(color: context.fast.t1),
          ),
          const SizedBox(width: FASTSpace.s8),
          Icon(
            paid ? Icons.check_circle : Icons.hourglass_empty,
            size: 20,
            color: paid ? FASTBrand.success : context.fast.t3,
          ),
        ],
      ),
    );
  }
}

class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FASTSpace.s24),
    decoration: BoxDecoration(
      color: FASTBrand.success.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(FASTRadius.md),
      border: Border.all(color: FASTBrand.success.withValues(alpha: 0.45)),
    ),
    child: Column(
      children: [
        const Icon(Icons.task_alt, color: FASTBrand.success, size: 36),
        const SizedBox(height: FASTSpace.s12),
        Text(
          tr(context, 'group_sent_title'),
          textAlign: TextAlign.center,
          style: FASTText.item.copyWith(color: context.fast.t1),
        ),
        const SizedBox(height: FASTSpace.s8),
        Text(
          tr(context, 'group_sent_sub'),
          textAlign: TextAlign.center,
          style: FASTText.body.copyWith(color: context.fast.t2),
        ),
      ],
    ),
  );
}
