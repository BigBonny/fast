// lib/screens/resto/resto_staff_screen.dart
//
// Owner-only: create unlimited cook/guest accounts. Cooks log in with
// email+password and land directly on the kitchen board — no stats,
// no payments, no settings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/api_client.dart';
import '../../api/api_config.dart';
import '../../api/api_exceptions.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';
import '../../widgets/fast_parts.dart';
import '../../widgets/fast_ui.dart';

class RestoStaffScreen extends StatefulWidget {
  const RestoStaffScreen({super.key});

  @override
  State<RestoStaffScreen> createState() => _RestoStaffScreenState();
}

class _RestoStaffScreenState extends State<RestoStaffScreen> {
  final _api = ApiClient();
  List<dynamic> _staff = [];
  bool _loading = true;
  String? _error;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get(ApiConfig.staff);
      _staff = data as List<dynamic>;
      try {
        final invite = await _api.get(ApiConfig.staffInviteCode);
        _inviteCode = (invite as Map<String, dynamic>)['code'] as String?;
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        _error = e is ApiException ? e.message : tr(context, 'load_err');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String staffId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
        ),
        title: Text(tr(context, 'del_account_q')),
        content: Text(tr(context, 'staff_lose_access').replaceAll('{n}', name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: ctx.fast.t2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tr(context, 'del'),
              style: const TextStyle(color: FASTBrand.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete(ApiConfig.staffMember(staffId));
      _load();
    } catch (e) {
      if (mounted) {
        _toast(e is ApiException ? e.message : tr(context, 'delete_err'));
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCreateSheet() {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    var role = 'GUEST';
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s24,
            FASTSpace.s16,
            MediaQuery.of(ctx).viewInsets.bottom + FASTSpace.s24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, 'new_cook'),
                  style: FASTText.title.copyWith(color: context.fast.t1),
                ),
                const SizedBox(height: FASTSpace.s4),
                Text(
                  tr(context, 'staff_access'),
                  style: FASTText.caption.copyWith(color: context.fast.t2),
                ),
                const SizedBox(height: FASTSpace.s16),
                _field(
                  nameC,
                  tr(context, 'name_example'),
                  Icons.person_outline,
                ),
                const SizedBox(height: FASTSpace.s12),
                _field(
                  emailC,
                  tr(context, 'email'),
                  Icons.mail_outline,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: FASTSpace.s12),
                _field(
                  passC,
                  tr(context, 'password'),
                  Icons.lock_outline,
                  obscure: true,
                ),
                const SizedBox(height: FASTSpace.s16),
                // Role picker
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _roleChip(
                        ctx,
                        setSheet,
                        'GUEST',
                        tr(context, 'guest_lbl'),
                        tr(context, 'menu_soldout_sub'),
                        role,
                        (r) => role = r,
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      _roleChip(
                        ctx,
                        setSheet,
                        'STAFF',
                        tr(context, 'manager'),
                        tr(context, 'orders_menu'),
                        role,
                        (r) => role = r,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FASTSpace.s24),
                FastButton(
                  kind: FastButtonKind.ink,
                  label: saving
                      ? tr(context, 'creating')
                      : tr(context, 'create_account'),
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameC.text.trim().isEmpty ||
                              emailC.text.trim().isEmpty ||
                              passC.text.length < 6) {
                            _toast(tr(context, 'staff_required'));
                            return;
                          }
                          setSheet(() => saving = true);
                          try {
                            await _api.post(
                              ApiConfig.staff,
                              body: {
                                'name': nameC.text.trim(),
                                'email': emailC.text.trim(),
                                'password': passC.text,
                                'staffRole': role,
                              },
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            setSheet(() => saving = false);
                            _toast(
                              e is ApiException
                                  ? e.message
                                  : tr(context, 'create_err'),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(
    BuildContext ctx,
    StateSetter setSheet,
    String value,
    String label,
    String sub,
    String current,
    void Function(String) onSel,
  ) {
    final sel = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setSheet(() => onSel(value));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FASTSpace.s8,
            vertical: FASTSpace.s12,
          ),
          decoration: BoxDecoration(
            color: sel
                ? FASTPro.teal.withValues(alpha: 0.15)
                : context.fast.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            border: Border.all(
              color: sel ? FASTPro.teal : context.fast.line,
              width: sel ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: FASTText.item.copyWith(
                  color: sel ? FASTPro.teal : context.fast.t1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: FASTText.caption.copyWith(color: context.fast.t2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      cursorColor: FASTPro.teal,
      style: FASTText.body.copyWith(color: context.fast.t1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FASTText.body.copyWith(color: context.fast.t3),
        prefixIcon: Icon(icon, size: 18, color: context.fast.t3),
        filled: true,
        fillColor: context.fast.cardHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border(context.fast.line),
        enabledBorder: border(context.fast.line),
        focusedBorder: border(FASTPro.teal, 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        backgroundColor: fast.bg,
        elevation: 0,
        title: Text(
          tr(context, 'team_guests'),
          style: FASTText.title.copyWith(color: fast.t1),
        ),
      ),
      floatingActionButton: FastButton(
        kind: FastButtonKind.ink,
        expand: false,
        icon: Icons.person_add_alt_1_outlined,
        label: tr(context, 'add_cook'),
        onPressed: _showCreateSheet,
      ),
      body: Column(
        children: [
          if (_inviteCode != null) _buildInviteCard(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: FASTPro.teal),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(FASTSpace.s24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: FASTText.body.copyWith(color: fast.t2),
                          ),
                          const SizedBox(height: FASTSpace.s8),
                          TextButton(
                            onPressed: _load,
                            child: Text(
                              tr(context, 'retry'),
                              style: FASTText.body.copyWith(
                                color: FASTPro.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _staff.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: FastEmpty(
                        icon: Icons.soup_kitchen_outlined,
                        accent: FASTPro.teal,
                        title: tr(context, 'no_cooks'),
                        subtitle: tr(context, 'staff_intro'),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: FASTPro.teal,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(
                        top: FASTSpace.s8,
                        bottom: 120,
                      ),
                      itemCount: _staff.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: fast.line,
                        indent: FASTSpace.s16,
                        endIndent: FASTSpace.s16,
                      ),
                      itemBuilder: (_, i) {
                        final s = _staff[i] as Map<String, dynamic>;
                        final user = s['user'] as Map<String, dynamic>;
                        final isGuest = s['staffRole'] == 'GUEST';
                        return Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            FASTSpace.s16,
                            FASTSpace.s12,
                            FASTSpace.s4,
                            FASTSpace.s12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: fast.cardHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: fast.line),
                                ),
                                child: Text(
                                  (user['name'] as String? ?? '?')
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: FASTText.item.copyWith(color: fast.t1),
                                ),
                              ),
                              const SizedBox(width: FASTSpace.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['name'] as String? ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: FASTText.item.copyWith(
                                        color: fast.t1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user['email'] as String? ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: FASTText.caption.copyWith(
                                        color: fast.t2,
                                      ),
                                    ),
                                    const SizedBox(height: FASTSpace.s8),
                                    FastTag(
                                      isGuest
                                          ? tr(context, 'guest_badge')
                                          : 'MANAGER',
                                      kind: isGuest
                                          ? FastTagKind.neutral
                                          : FastTagKind.neutral,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: FASTBrand.error,
                                  size: 20,
                                ),
                                onPressed: () => _delete(
                                  s['id'] as String,
                                  user['name'] as String? ?? '',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// F13 — the owner's shareable invite code: staff/guests join with
  /// first+last name and this code on the role-selection screen.
  Widget _buildInviteCard() {
    final fast = context.fast;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s12,
        FASTSpace.s16,
        FASTSpace.s8,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        FASTSpace.s16,
        FASTSpace.s12,
        FASTSpace.s4,
        FASTSpace.s12,
      ),
      decoration: BoxDecoration(
        color: fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: fast.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: FASTPro.teal, size: 20),
          const SizedBox(width: FASTSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fastLabelCase(context, tr(context, 'invite_code')),
                  style: FASTText.label.copyWith(color: fast.t2),
                ),
                const SizedBox(height: FASTSpace.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _inviteCode!,
                    maxLines: 1,
                    style: FASTText.price.copyWith(
                      color: fast.t1,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr(context, 'copy_code'),
            icon: Icon(Icons.copy, size: 20, color: fast.t2),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _inviteCode!));
              _toast(tr(context, 'invite_code'));
            },
          ),
          IconButton(
            tooltip: tr(context, 'rotate_code'),
            icon: Icon(Icons.refresh, size: 20, color: fast.t2),
            onPressed: () async {
              try {
                final data = await _api.post(
                  '${ApiConfig.staffInviteCode}/rotate',
                );
                if (!mounted) return;
                setState(() {
                  _inviteCode =
                      (data as Map<String, dynamic>)['code'] as String?;
                });
              } catch (e) {
                if (mounted) {
                  _toast(
                    e is ApiException ? e.message : tr(context, 'load_err'),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
