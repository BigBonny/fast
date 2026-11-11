// lib/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../api/api_exceptions.dart';
import '../providers/auth_provider.dart';
import '../widgets/fast_night_surface.dart';
import '../widgets/fast_ui.dart';
import '../widgets/notification_center.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'saved_addresses_screen.dart';
import 'saved_cards_screen.dart';
import 'admin_requests_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Opening the notifications tab marks everything read — otherwise
    // the unread dot would stay lit forever.
    _tabController.addListener(() {
      if (_tabController.index == 3 && !_tabController.indexIsChanging) {
        context.read<FASTProvider>().markNotificationsRead();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FASTProvider>(context);

    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.fast.t2),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          provider.tr('my_account'),
          style: FASTText.item.copyWith(
            color: context.fast.t1,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Membership card (name, level, points, figures)
          _buildProfileHeader(provider),

          const SizedBox(height: FASTSpace.s8),

          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.fast.line)),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => HapticFeedback.selectionClick(),
              indicatorColor: context.fast.ink,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: context.fast.ink,
              unselectedLabelColor: context.fast.t3,
              labelPadding: const EdgeInsets.symmetric(
                horizontal: FASTSpace.s4,
              ),
              labelStyle: FASTText.label.copyWith(letterSpacing: 0),
              unselectedLabelStyle: FASTText.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.person_outline, size: 20),
                  text: provider.tr('tab_profile'),
                ),
                Tab(
                  icon: const Icon(Icons.bolt_outlined, size: 20),
                  text: provider.tr('tab_points'),
                ),
                Tab(
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  text: provider.tr('tab_addresses'),
                ),
                Tab(
                  icon: const Icon(Icons.notifications_none, size: 20),
                  text: provider.tr('tab_notifs'),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfilTab(provider),
                _buildPointsTab(provider),
                _buildAdressesTab(),
                _buildNotifsTab(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Membership card ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(FASTProvider provider) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FASTSpace.s16,
        FASTSpace.s4,
        FASTSpace.s16,
        0,
      ),
      child: FastNightSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fastLabelCase(context, provider.membershipLevel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.label.copyWith(
                          color: FastNightSurface.onNightMuted,
                        ),
                      ),
                      const SizedBox(height: FASTSpace.s4),
                      Text(
                        provider.userName.isNotEmpty
                            ? provider.userName
                            : provider.tr('your_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.title.copyWith(
                          color: FastNightSurface.onNight,
                        ),
                      ),
                      if (provider.userEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          provider.userEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FASTText.caption.copyWith(
                            color: FastNightSurface.onNightMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FASTSpace.s12),
                _pointsPill(provider.userPoints),
              ],
            ),
            const SizedBox(height: FASTSpace.s16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: FASTSpace.s12),
            _buildStatsRow(provider),
          ],
        ),
      ),
    );
  }

  /// Dark pill with the points balance — sits on the night surface only.
  Widget _pointsPill(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(FASTRadius.pill),
        border: Border.all(color: FASTBrand.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_outlined, color: FASTBrand.gold, size: 16),
          const SizedBox(width: FASTSpace.s4),
          Text(
            '$points PTS',
            style: FASTText.price.copyWith(fontSize: 14, color: FASTBrand.gold),
          ),
        ],
      ),
    );
  }

  // ─── Figures inside the membership card ──────────────────────────────────────
  Widget _buildStatsRow(FASTProvider provider) {
    return Row(
      children: [
        _statCell(
          Icons.receipt_long_outlined,
          '${provider.orders.length}',
          provider.tr('nav_orders'),
        ),
        _statCell(
          Icons.favorite_border,
          '${provider.favorites.length}',
          provider.tr('favorites'),
        ),
        _statCell(
          Icons.bolt_outlined,
          '${provider.userPoints}',
          provider.tr('tab_points'),
        ),
      ],
    );
  }

  Widget _statCell(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: FASTText.price.copyWith(color: FastNightSurface.onNight),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(icon, size: 14, color: FastNightSurface.onNightMuted),
              const SizedBox(width: FASTSpace.s4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.caption.copyWith(
                    color: FastNightSurface.onNightMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared pieces ───────────────────────────────────────────────────────────
  /// Section card: radius 20, hairline border, splashes clipped to it.
  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Material(
      color: context.fast.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FASTRadius.md),
        side: BorderSide(color: context.fast.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding, child: child),
    );
  }

  Widget _hairline() => Divider(
    height: 1,
    thickness: 1,
    indent: FASTSpace.s16,
    endIndent: FASTSpace.s16,
    color: context.fast.line,
  );

  /// Plain settings row: line icon, label, optional chevron.
  Widget _row({
    required IconData icon,
    String? label,
    Widget? title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
    bool chevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(FASTSpace.s16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? context.fast.t2),
            const SizedBox(width: FASTSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title ??
                      Text(
                        label ?? '',
                        style: FASTText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color ?? context.fast.t1,
                        ),
                      ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: FASTText.caption.copyWith(color: context.fast.t2),
                    ),
                  ],
                ],
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: FASTSpace.s8),
              Icon(Icons.chevron_right, color: context.fast.t3, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  ShapeBorder _dialogShape({Color? side}) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(FASTRadius.md),
    side: BorderSide(color: side ?? context.fast.line),
  );

  TextStyle get _dialogTitleStyle =>
      FASTText.item.copyWith(color: context.fast.t1);

  ButtonStyle _inkButtonStyle() => ElevatedButton.styleFrom(
    backgroundColor: context.fast.ink,
    foregroundColor: context.fast.onInk,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    elevation: 0,
  );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: FASTText.body.copyWith(color: context.fast.t3),
    filled: true,
    fillColor: context.fast.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: context.fast.ink, width: 1.5),
    ),
  );

  // ─── Profil Tab ──────────────────────────────────────────────────────────────
  Widget _buildProfilTab(FASTProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        FASTSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal info section
          _sectionLabel(provider.tr('personal_info')),
          const SizedBox(height: FASTSpace.s4),
          Text(
            provider.tr('tagline'),
            style: FASTText.caption.copyWith(color: context.fast.t2),
          ),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: Column(
              children: [
                _editableField(
                  label: provider.tr('full_name'),
                  value: provider.userName,
                  hint: provider.tr('not_provided'),
                  onEdit: () => _showEditDialog(
                    context,
                    provider.tr('name'),
                    provider.userName,
                    (val, _) => provider.updateProfile(name: val),
                  ),
                ),
                _hairline(),
                _editableField(
                  label: provider.tr('phone'),
                  value: provider.userPhone,
                  hint: provider.tr('not_provided'),
                  onEdit: () => _showEditDialog(
                    context,
                    provider.tr('phone'),
                    provider.userPhone,
                    (val, _) => provider.updateProfile(phone: val),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                _hairline(),
                _editableField(
                  label: provider.tr('email'),
                  value: provider.userEmail,
                  hint: provider.tr('not_provided'),
                  onEdit: () => _showEditDialog(
                    context,
                    provider.tr('email'),
                    provider.userEmail,
                    (val, pwd) => provider.updateProfile(
                      email: val,
                      currentPassword: pwd,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    askPassword: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Appearance section
          _sectionLabel(provider.tr('appearance')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            padding: const EdgeInsets.all(FASTSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: context.fast.t2,
                      size: 22,
                    ),
                    const SizedBox(width: FASTSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'theme_interface'),
                            style: FASTText.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.fast.t1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.tr('theme_sub'),
                            style: FASTText.caption.copyWith(
                              color: context.fast.t2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FASTSpace.s16),
                Row(
                  children: [
                    _themeOption(
                      provider,
                      ThemeMode.system,
                      Icons.phone_android,
                      provider.tr('theme_auto'),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    _themeOption(
                      provider,
                      ThemeMode.light,
                      Icons.wb_sunny_outlined,
                      provider.tr('theme_light'),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    _themeOption(
                      provider,
                      ThemeMode.dark,
                      Icons.nightlight_outlined,
                      provider.tr('theme_dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Payment methods
          _sectionLabel(provider.tr('payment_methods')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: _row(
              icon: Icons.credit_card_outlined,
              label: provider.tr('bank_card'),
              subtitle: provider.tr('manage_payments'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedCardsScreen()),
              ),
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Account security
          _sectionLabel(provider.tr('account_security')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: Column(
              children: [
                _row(
                  icon: Icons.lock_outline,
                  label: provider.tr('change_pwd'),
                  onTap: () => _showChangePasswordDialog(context),
                ),
                _hairline(),
                _row(
                  icon: Icons.mail_lock_outlined,
                  label: provider.tr('email_security'),
                  subtitle: provider.tr('email_privacy'),
                  onTap: () => _showEmailSecurityInfo(context, provider),
                ),
              ],
            ),
          ),

          // FAST team only — pipeline of client restaurant requests
          if (context.watch<AuthProvider>().user?.isAdmin ?? false) ...[
            const SizedBox(height: FASTSpace.s40),
            _sectionLabel('FAST'),
            const SizedBox(height: FASTSpace.s12),
            _card(
              child: _row(
                icon: Icons.storefront_outlined,
                label: provider.tr('admin_req_title'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRequestsScreen(),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: FASTSpace.s40),

          // Legal
          _sectionLabel(provider.tr('legal_info')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: Column(
              children: [
                _row(
                  icon: Icons.shield_outlined,
                  label: provider.tr('privacy'),
                  onTap: () => _showLegalInfo(context, tr(context, 'privacy')),
                ),
                _hairline(),
                _row(
                  icon: Icons.description_outlined,
                  label: provider.tr('terms_title'),
                  onTap: () => _showLegalInfo(context, 'CGU'),
                ),
              ],
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Session
          _sectionLabel(provider.tr('session')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: _row(
              icon: Icons.logout,
              chevron: false,
              onTap: () async {
                final auth = context.read<AuthProvider>();
                await auth.logout();
                if (!mounted) return;
                // Pop back to the root so the auth gate can show RoleSelectionScreen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              title: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final style = FASTText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.fast.t1,
                  );
                  if (auth.isLoggingOut) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.fast.t2,
                          ),
                        ),
                        const SizedBox(width: FASTSpace.s12),
                        Flexible(
                          child: Text(
                            context.read<FASTProvider>().tr('logging_out'),
                            style: style,
                          ),
                        ),
                      ],
                    );
                  }
                  return Text(provider.tr('logout'), style: style);
                },
              ),
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Danger zone
          _sectionLabel(tr(context, 'zone_danger')),
          const SizedBox(height: FASTSpace.s12),
          _card(
            child: _row(
              icon: Icons.delete_outline,
              label: tr(context, 'del_my_account'),
              color: FASTBrand.error,
              chevron: false,
              onTap: () => _showDeleteConfirm(context, provider),
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          // Footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FAST Client v1.0 · ${tr(context, 'made_with')} ',
                  style: FASTText.caption.copyWith(color: context.fast.t3),
                ),
                Icon(Icons.bolt_outlined, color: context.fast.t3, size: 14),
              ],
            ),
          ),
          const SizedBox(height: FASTSpace.s16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      fastLabelCase(context, label),
      style: FASTText.label.copyWith(color: context.fast.t2),
    );
  }

  Widget _editableField({
    required String label,
    required String value,
    required String hint,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.all(FASTSpace.s16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fastLabelCase(context, label),
                  style: FASTText.label.copyWith(color: context.fast.t3),
                ),
                const SizedBox(height: FASTSpace.s4),
                Text(
                  value.isNotEmpty ? value : hint,
                  style: FASTText.body.copyWith(
                    color: value.isNotEmpty ? context.fast.t1 : context.fast.t3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FASTSpace.s8),
          GestureDetector(
            onTap: onEdit,
            child: Icon(Icons.edit_outlined, color: context.fast.t2, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    FASTProvider provider,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final selected = provider.themeMode == mode;
    final fg = selected ? context.fast.onInk : context.fast.t2;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          provider.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
          decoration: BoxDecoration(
            color: selected ? context.fast.ink : context.fast.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.sm),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(height: FASTSpace.s4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String fieldName,
    String currentValue,
    Future<void> Function(String value, String? password) onSave, {
    TextInputType keyboardType = TextInputType.text,
    // Changing the sign-in email asks for the current password.
    bool askPassword = false,
  }) {
    final controller = TextEditingController(text: currentValue);
    final pwdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: _dialogShape(),
        title: Text(
          tr(context, 'edit_field').replaceAll('{n}', fieldName),
          style: _dialogTitleStyle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              style: TextStyle(color: context.fast.t1, fontSize: 14),
              decoration: _fieldDecoration(fieldName),
            ),
            if (askPassword) ...[
              const SizedBox(height: FASTSpace.s12),
              TextField(
                controller: pwdController,
                obscureText: true,
                style: TextStyle(color: context.fast.t1, fontSize: 14),
                decoration: _fieldDecoration(tr(context, 'pwd_current')),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await onSave(
                  controller.text.trim(),
                  askPassword ? pwdController.text : null,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        e is ApiException
                            ? e.message
                            : tr(context, 'error_save'),
                      ),
                    ),
                  );
                }
              }
            },
            style: _inkButtonStyle(),
            child: Text(
              tr(context, 'save'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, FASTProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: _dialogShape(side: FASTBrand.error),
        title: Text(
          tr(context, 'del_account_q'),
          style: FASTText.item.copyWith(color: FASTBrand.error),
        ),
        content: Text(
          tr(context, 'del_account_warn'),
          style: FASTText.body.copyWith(color: context.fast.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final deleted = await auth.deleteAccount();
              if (!context.mounted || !ctx.mounted) return;
              if (deleted) {
                provider.deleteAccount();
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(auth.error ?? tr(context, 'del_fail')),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FASTBrand.error,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            child: Text(
              tr(context, 'del'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Points Tab ──────────────────────────────────────────────────────────────
  Widget _buildPointsTab(FASTProvider provider) {
    final completedOrders = provider.orders
        .where((o) => o.status == OrderStatus.completed)
        .toList();
    final noPoints = tr(context, 'no_points').split('\n');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        FASTSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance, level and progress to the next level
          _card(
            padding: const EdgeInsets.all(FASTSpace.s16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${provider.userPoints} points',
                    style: FASTText.display.copyWith(
                      color: context.fast.t1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: FASTSpace.s4),
                  Text(
                    fastLabelCase(context, provider.membershipLevel),
                    style: FASTText.label.copyWith(color: context.fast.t2),
                  ),
                  const SizedBox(height: FASTSpace.s24),
                  _buildLevelProgress(provider.userPoints),
                ],
              ),
            ),
          ),

          const SizedBox(height: FASTSpace.s40),

          _sectionLabel(tr(context, 'points_history')),
          const SizedBox(height: FASTSpace.s12),

          if (completedOrders.isEmpty)
            Center(
              child: FastEmpty(
                icon: Icons.bolt_outlined,
                title: noPoints.first,
                subtitle: noPoints.length > 1
                    ? noPoints.skip(1).join('\n')
                    : null,
              ),
            )
          else
            _card(
              child: Column(
                children: completedOrders.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final order = entry.value;
                  return Column(
                    children: [
                      if (idx > 0) _hairline(),
                      Padding(
                        padding: const EdgeInsets.all(FASTSpace.s16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.restaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FASTText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: context.fast.t1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tr(
                                      context,
                                      'order_done_id',
                                    ).replaceAll('{n}', order.id),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FASTText.caption.copyWith(
                                      color: context.fast.t2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: FASTSpace.s12),
                            Text(
                              '+10 pts',
                              style: FASTText.price.copyWith(
                                fontSize: 14,
                                color: context.fast.t1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: FASTSpace.s40),
        ],
      ),
    );
  }

  Widget _buildLevelProgress(int pts) {
    int nextThreshold;
    String nextLevel;
    int prevThreshold;

    if (pts < 80) {
      prevThreshold = 0;
      nextThreshold = 80;
      nextLevel = tr(context, 'level_member');
    } else if (pts < 200) {
      prevThreshold = 80;
      nextThreshold = 200;
      nextLevel = 'FAST Gold';
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FASTSpace.s12,
          vertical: FASTSpace.s8,
        ),
        decoration: BoxDecoration(
          color: FASTBrand.gold,
          borderRadius: BorderRadius.circular(FASTRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: FASTBrand.onAmber,
              size: 18,
            ),
            const SizedBox(width: FASTSpace.s8),
            Flexible(
              child: Text(
                tr(context, 'max_level'),
                style: FASTText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FASTBrand.onAmber,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final progress = ((pts - prevThreshold) / (nextThreshold - prevThreshold))
        .clamp(0.0, 1.0);
    final remaining = nextThreshold - pts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(FASTRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.fast.line,
            valueColor: const AlwaysStoppedAnimation(FASTBrand.gold),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: FASTSpace.s8),
        // The bar runs from the current level to the next one.
        Row(
          children: [
            Expanded(
              child: Text(
                context.read<FASTProvider>().membershipLevel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.fast.t1,
                ),
              ),
            ),
            const SizedBox(width: FASTSpace.s8),
            Flexible(
              child: Text(
                tr(context, 'to_next_level').replaceAll('{n}', nextLevel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FASTText.caption.copyWith(color: context.fast.t2),
              ),
            ),
          ],
        ),
        const SizedBox(height: FASTSpace.s12),
        Text(
          tr(context, 'pts_remaining').replaceAll('{n}', '$remaining'),
          style: FASTText.body.copyWith(color: context.fast.t2),
        ),
      ],
    );
  }

  // ─── Adresses Tab ────────────────────────────────────────────────────────────
  Widget _buildAdressesTab() {
    return const SavedAddressesScreen(embedded: true);
  }

  // ─── Notifs Tab ──────────────────────────────────────────────────────────────
  Widget _buildNotifsTab(FASTProvider provider) {
    return NotificationCenterList(provider: provider);
  }

  // ─── Change password dialog ─────────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: context.fast.card,
          shape: _dialogShape(),
          title: Text(tr(context, 'change_pwd'), style: _dialogTitleStyle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _passwordField(
                currentCtrl,
                tr(context, 'pwd_current'),
                obscure: true,
              ),
              const SizedBox(height: FASTSpace.s12),
              _passwordField(newCtrl, tr(context, 'pwd_new'), obscure: true),
              const SizedBox(height: FASTSpace.s12),
              _passwordField(
                confirmCtrl,
                tr(context, 'pwd_confirm'),
                obscure: true,
              ),
              if (error != null) ...[
                const SizedBox(height: FASTSpace.s12),
                Text(
                  error!,
                  style: FASTText.caption.copyWith(color: FASTBrand.error),
                ),
              ],
              const SizedBox(height: FASTSpace.s8),
              Text(
                tr(context, 'pwd_rules'),
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(ctx).pop(),
              child: Text(
                tr(context, 'cancel'),
                style: TextStyle(color: context.fast.t2),
              ),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        error = null;
                        loading = true;
                      });
                      if (newCtrl.text != confirmCtrl.text) {
                        setState(() {
                          error = tr(context, 'pwd_mismatch');
                          loading = false;
                        });
                        return;
                      }
                      try {
                        final auth = context.read<AuthProvider>();
                        await auth.changePassword(
                          currentPassword: currentCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr(context, 'pwd_updated'))),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          error = e.toString().replaceFirst('Exception: ', '');
                          loading = false;
                        });
                      }
                    },
              style: _inkButtonStyle(),
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.fast.t2,
                      ),
                    )
                  : Text(
                      tr(context, 'save'),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    bool obscure = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: context.fast.t1, fontSize: 14),
      decoration: _fieldDecoration(label),
    );
  }

  // ─── Email security info ────────────────────────────────────────────────────
  void _showEmailSecurityInfo(BuildContext context, FASTProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: _dialogShape(),
        title: Row(
          children: [
            Icon(Icons.mail_lock_outlined, color: context.fast.t2, size: 22),
            const SizedBox(width: FASTSpace.s8),
            Flexible(
              child: Text(
                tr(context, 'email_security'),
                style: _dialogTitleStyle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'email_assoc'),
              style: FASTText.caption.copyWith(color: context.fast.t2),
            ),
            const SizedBox(height: FASTSpace.s4),
            Text(
              provider.userEmail.isNotEmpty
                  ? provider.userEmail
                  : tr(context, 'not_provided'),
              style: FASTText.body.copyWith(
                color: context.fast.t1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FASTSpace.s16),
            Text(
              tr(context, 'email_change_hint') + tr(context, 'email_used_for'),
              style: FASTText.caption.copyWith(
                color: context.fast.t2,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: _inkButtonStyle(),
            child: Text(
              tr(context, 'close'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Legal info ─────────────────────────────────────────────────────────────
  void _showLegalInfo(BuildContext context, String type) {
    final content = type == 'CGU'
        ? tr(context, 'terms_intro') +
              tr(context, 'fast_service_desc') +
              tr(context, 'legal_orders')
        : tr(context, 'privacy_collect') +
              tr(context, 'privacy_data') +
              tr(context, 'data_rights');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: _dialogShape(),
        title: Text(
          type == 'CGU' ? tr(context, 'terms_title') : tr(context, 'privacy'),
          style: _dialogTitleStyle,
        ),
        content: Text(
          content,
          style: FASTText.caption.copyWith(color: context.fast.t2, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: _inkButtonStyle(),
            child: Text(
              tr(context, 'close'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
