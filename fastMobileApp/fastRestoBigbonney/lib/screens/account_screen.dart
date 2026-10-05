// lib/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';
import '../providers/auth_provider.dart';
import '../widgets/notification_center.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'saved_addresses_screen.dart';
import 'saved_cards_screen.dart';

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
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Profile header
          _buildProfileHeader(provider),

          // Stats row
          _buildStatsRow(provider),

          SizedBox(height: 4),

          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.fast.line)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Color(0xFFF59E0B),
              indicatorWeight: 2,
              labelColor: Color(0xFFF59E0B),
              unselectedLabelColor: context.fast.t3,
              labelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.person_outline, size: 18),
                  text: provider.tr('tab_profile'),
                ),
                Tab(
                  icon: const Icon(Icons.bolt, size: 18),
                  text: provider.tr('tab_points'),
                ),
                Tab(
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  text: provider.tr('tab_addresses'),
                ),
                Tab(
                  icon: const Icon(Icons.notifications_none, size: 18),
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

  // ─── Profile Header ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader(FASTProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              provider.userInitial,
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
                  provider.userName.isNotEmpty
                      ? provider.userName
                      : provider.tr('your_name'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.fast.t1,
                  ),
                ),
                if (provider.userEmail.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    provider.userEmail,
                    style: TextStyle(fontSize: 12, color: context.fast.t2),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: Color(0xFFF59E0B),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.userPoints} PTS · ${provider.membershipLevel}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────────
  Widget _buildStatsRow(FASTProvider provider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fast.line),
      ),
      child: Row(
        children: [
          _statCell(
            '📦',
            '${provider.orders.length}',
            provider.tr('nav_orders'),
          ),
          Container(width: 1, height: 48, color: context.fast.line),
          _statCell(
            '❤️',
            '${provider.favorites.length}',
            provider.tr('favorites'),
          ),
          Container(width: 1, height: 48, color: context.fast.line),
          _statCell('⚡', '${provider.userPoints}', provider.tr('tab_points')),
        ],
      ),
    );
  }

  Widget _statCell(String icon, String value, String label) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.fast.t1,
              ),
            ),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: context.fast.t3)),
          ],
        ),
      ),
    );
  }

  // ─── Profil Tab ──────────────────────────────────────────────────────────────
  Widget _buildProfilTab(FASTProvider provider) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal info section
          _sectionLabel(provider.tr('personal_info')),
          SizedBox(height: 4),
          Text(
            provider.tr('tagline'),
            style: TextStyle(fontSize: 11, color: context.fast.t3, height: 1.4),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
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
                    (val) => provider.updateProfile(name: val),
                  ),
                ),
                Divider(height: 1, color: context.fast.line),
                _editableField(
                  label: provider.tr('phone').toUpperCase(),
                  value: provider.userPhone,
                  hint: provider.tr('not_provided'),
                  onEdit: () => _showEditDialog(
                    context,
                    provider.tr('phone'),
                    provider.userPhone,
                    (val) => provider.updateProfile(phone: val),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                Divider(height: 1, color: context.fast.line),
                _editableField(
                  label: provider.tr('email').toUpperCase(),
                  value: provider.userEmail,
                  hint: provider.tr('not_provided'),
                  onEdit: () => _showEditDialog(
                    context,
                    provider.tr('email'),
                    provider.userEmail,
                    (val) => provider.updateProfile(email: val),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Appearance section
          _sectionLabel(provider.tr('appearance')),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'theme_interface'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.fast.t1,
                          ),
                        ),
                        Text(
                          provider.tr('theme_sub'),
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _themeOption(
                      provider,
                      ThemeMode.system,
                      Icons.phone_android,
                      provider.tr('theme_auto'),
                    ),
                    const SizedBox(width: 8),
                    _themeOption(
                      provider,
                      ThemeMode.light,
                      Icons.wb_sunny_outlined,
                      provider.tr('theme_light'),
                    ),
                    const SizedBox(width: 8),
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

          SizedBox(height: 24),

          // Payment methods
          _sectionLabel(provider.tr('payment_methods')),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedCardsScreen()),
              ),
              leading: Icon(
                Icons.credit_card,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              title: Text(
                provider.tr('bank_card'),
                style: TextStyle(
                  color: context.fast.t1,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                provider.tr('manage_payments'),
                style: TextStyle(color: context.fast.t3, fontSize: 11),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: context.fast.faint,
                size: 18,
              ),
            ),
          ),

          SizedBox(height: 24),

          // Account security
          _sectionLabel(provider.tr('account_security')),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => _showChangePasswordDialog(context),
                  leading: Icon(
                    Icons.lock_outline,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  title: Text(
                    provider.tr('change_pwd'),
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.fast.faint,
                    size: 18,
                  ),
                ),
                Divider(height: 1, color: context.fast.line),
                ListTile(
                  onTap: () => _showEmailSecurityInfo(context, provider),
                  leading: Icon(
                    Icons.mail_lock_outlined,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  title: Text(
                    provider.tr('email_security'),
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    provider.tr('email_privacy'),
                    style: TextStyle(color: context.fast.t3, fontSize: 11),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.fast.faint,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Legal
          _sectionLabel(provider.tr('legal_info')),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => _showLegalInfo(context, tr(context, 'privacy')),
                  leading: Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  title: Text(
                    provider.tr('privacy'),
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.fast.faint,
                    size: 18,
                  ),
                ),
                Divider(height: 1, color: context.fast.line),
                ListTile(
                  onTap: () => _showLegalInfo(context, 'CGU'),
                  leading: Icon(
                    Icons.description_outlined,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  title: Text(
                    provider.tr('terms_title'),
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.fast.faint,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Session
          _sectionLabel(provider.tr('session')),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: ListTile(
              onTap: () async {
                final auth = context.read<AuthProvider>();
                await auth.logout();
                if (!mounted) return;
                // Pop back to the root so the auth gate can show RoleSelectionScreen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              leading: Icon(Icons.logout, color: Color(0xFFF59E0B), size: 20),
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
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          context.read<FASTProvider>().tr('logging_out'),
                          style: TextStyle(
                            color: context.fast.t1,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }
                  return Text(
                    provider.tr('logout'),
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 24),

          // Danger zone
          _sectionLabel(tr(context, 'zone_danger')),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: ListTile(
              onTap: () => _showDeleteConfirm(context, provider),
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              title: Text(
                tr(context, 'del_my_account'),
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          SizedBox(height: 32),

          // Footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FAST Client v1.0 · ${tr(context, 'made_with')} ',
                  style: TextStyle(fontSize: 11, color: context.fast.faint),
                ),
                Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: context.fast.t3,
      ),
    );
  }

  Widget _editableField({
    required String label,
    required String value,
    required String hint,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: context.fast.t3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : hint,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isNotEmpty
                        ? context.fast.t1
                        : context.fast.faint,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Icon(Icons.edit_outlined, color: context.fast.t3, size: 18),
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
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Color(0xFF10B981) : context.fast.line,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : context.fast.t2,
                size: 16,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : context.fast.t2,
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
    Function(String) onSave, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.fast.line),
        ),
        title: Text(
          tr(context, 'edit_field').replaceAll('{n}', fieldName),
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          style: TextStyle(color: context.fast.t1, fontSize: 14),
          decoration: InputDecoration(
            hintText: fieldName,
            hintStyle: TextStyle(color: context.fast.faint),
            filled: true,
            fillColor: context.fast.bg,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fast.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fast.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF59E0B)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(color: context.fast.t3)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await onSave(controller.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(tr(context, 'error_save'))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF59E0B),
              foregroundColor: FASTBrand.onAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Enregistrer',
              style: TextStyle(fontWeight: FontWeight.bold),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        title: Text(
          'Supprimer le compte ?',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: Text(
          tr(context, 'del_account_warn'),
          style: TextStyle(color: context.fast.t2, fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: TextStyle(color: context.fast.t3)),
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(fontWeight: FontWeight.bold),
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points balance card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider.userPoints} points',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: context.fast.t1,
                      ),
                    ),
                    Text(
                      provider.membershipLevel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Progress to next level
          _buildLevelProgress(provider.userPoints),

          SizedBox(height: 20),

          _sectionLabel(tr(context, 'points_history')),
          SizedBox(height: 8),

          if (completedOrders.isEmpty)
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.fast.line),
              ),
              child: Center(
                child: Text(
                  tr(context, 'no_points'),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fast.t3,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.fast.line),
              ),
              child: Column(
                children: completedOrders.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final order = entry.value;
                  return Column(
                    children: [
                      if (idx > 0) Divider(height: 1, color: context.fast.line),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Color(0xFFF59E0B),
                                size: 14,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.restaurantName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: context.fast.t1,
                                    ),
                                  ),
                                  Text(
                                    tr(
                                      context,
                                      'order_done_id',
                                    ).replaceAll('{n}', order.id),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.fast.t3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              '+10 pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
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

          const SizedBox(height: 40),
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
      nextLevel = 'FAST Member';
    } else if (pts < 200) {
      prevThreshold = 80;
      nextThreshold = 200;
      nextLevel = 'FAST Gold';
    } else {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Text(
              tr(context, 'max_level'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      );
    }

    final progress = ((pts - prevThreshold) / (nextThreshold - prevThreshold))
        .clamp(0.0, 1.0);
    final remaining = nextThreshold - pts;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fast.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(context, 'to_next_level').replaceAll('{n}', nextLevel),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.fast.t1,
                ),
              ),
              Text(
                '$remaining pts restants',
                style: TextStyle(fontSize: 11, color: context.fast.t3),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.fast.line,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
              minHeight: 6,
            ),
          ),
        ],
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.fast.line),
          ),
          title: Text(
            tr(context, 'change_pwd'),
            style: TextStyle(
              color: context.fast.t1,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _passwordField(
                currentCtrl,
                tr(context, 'pwd_current'),
                obscure: true,
              ),
              SizedBox(height: 12),
              _passwordField(newCtrl, tr(context, 'pwd_new'), obscure: true),
              SizedBox(height: 12),
              _passwordField(
                confirmCtrl,
                tr(context, 'pwd_confirm'),
                obscure: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                  ),
                ),
              ],
              SizedBox(height: 8),
              Text(
                tr(context, 'pwd_rules'),
                style: TextStyle(color: context.fast.faint, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(ctx).pop(),
              child: Text(
                tr(context, 'cancel'),
                style: TextStyle(color: context.fast.t3),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF59E0B),
                foregroundColor: FASTBrand.onAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FASTBrand.onAmber,
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
      style: TextStyle(color: context.fast.t1, fontSize: 13),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: context.fast.faint, fontSize: 12),
        filled: true,
        fillColor: context.fast.bg,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.fast.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.fast.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
        ),
      ),
    );
  }

  // ─── Email security info ────────────────────────────────────────────────────
  void _showEmailSecurityInfo(BuildContext context, FASTProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.fast.line),
        ),
        title: Row(
          children: [
            Icon(Icons.mail_lock_outlined, color: Color(0xFFF59E0B), size: 20),
            SizedBox(width: 8),
            Text(
              tr(context, 'email_security'),
              style: TextStyle(
                color: context.fast.t1,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
              style: TextStyle(color: context.fast.t3, fontSize: 11),
            ),
            SizedBox(height: 4),
            Text(
              provider.userEmail.isNotEmpty
                  ? provider.userEmail
                  : tr(context, 'not_provided'),
              style: TextStyle(
                color: context.fast.t1,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 16),
            Text(
              tr(context, 'email_change_hint') + tr(context, 'email_used_for'),
              style: TextStyle(
                color: context.fast.t2,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF59E0B),
              foregroundColor: FASTBrand.onAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.fast.line),
        ),
        title: Text(
          type == 'CGU' ? tr(context, 'terms_title') : tr(context, 'privacy'),
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: context.fast.t2, fontSize: 12, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF59E0B),
              foregroundColor: FASTBrand.onAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
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
