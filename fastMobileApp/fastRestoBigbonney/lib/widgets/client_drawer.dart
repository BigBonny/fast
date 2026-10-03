import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../screens/account_screen.dart';
import '../theme.dart';
import '../l10n/tr.dart';

/// Base44-style slide-in account menu for the client app:
/// gradient header with logo + avatar + points pill, tinted icon rows,
/// expandable Réglages (theme picker), and a red outlined logout button.
class ClientDrawer extends StatelessWidget {
  const ClientDrawer({super.key});

  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)],
  );

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color _bg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0F172A) : Colors.white;
  static Color _text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color _subtext(BuildContext context) =>
      _isDark(context) ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
  static Color _chipBg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color _chipBorder(BuildContext context) =>
      _isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FASTProvider>();

    return Drawer(
      backgroundColor: _bg(context),
      child: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
              decoration: const BoxDecoration(gradient: _headerGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFFA855F7)],
                        ).createShader(b),
                        child: const Text(
                          '⚡FAST⚡',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            fontSize: 22,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF60A5FA), Color(0xFFA855F7)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          provider.userInitial.isNotEmpty
                              ? provider.userInitial
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.userName.isNotEmpty
                                  ? provider.userName
                                  : 'Mon compte',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            if (provider.userEmail.isNotEmpty)
                              Text(
                                provider.userEmail,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${provider.userPoints} Points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '· Portefeuille FAST',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Menu items ───
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _item(
                    context,
                    icon: Icons.person_outline,
                    iconColor: const Color(0xFFA855F7),
                    label: provider.tr('my_account'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AccountScreen()));
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFF60A5FA),
                    label: provider.tr('my_orders'),
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.navigateToScreen('commandes');
                    },
                  ),
                  _settingsItem(context, provider),
                  _item(
                    context,
                    icon: Icons.favorite_border,
                    iconColor: const Color(0xFFF472B6),
                    label: provider.tr('favorites'),
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.navigateToScreen('home');
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFF34D399),
                    label: provider.tr('addresses'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AccountScreen()));
                    },
                  ),
                  // Owners who switched to client mode get a way back
                  if (context.watch<AuthProvider>().isRestaurant)
                    _item(
                      context,
                      icon: Icons.storefront,
                      iconColor: const Color(0xFF00C8B3),
                      label: provider.tr('pro_space'),
                      onTap: () async {
                        await provider.setViewAsClient(false);
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    ),
                  _item(
                    context,
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF38BDF8),
                    label: provider.tr('privacy'),
                    onTap: () => _showLegal(context, tr(context, 'privacy')),
                  ),
                  _item(
                    context,
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFFFBBF24),
                    label: provider.tr('cgu'),
                    onTap: () => _showLegal(context, 'CGU'),
                  ),
                ],
              ),
            ),

            // ─── Logout ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final auth = context.read<AuthProvider>();
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout,
                      color: Color(0xFFEF4444), size: 18),
                  label: Text(
                    provider.tr('logout'),
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: _text(context),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _settingsItem(BuildContext context, FASTProvider provider) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.settings_outlined,
              color: Color(0xFF94A3B8), size: 18),
        ),
        title: Text(
          provider.tr('settings'),
          style: TextStyle(
            color: _text(context),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        iconColor: const Color(0xFF94A3B8),
        collapsedIconColor: const Color(0xFF94A3B8),
        childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
        children: [
          Row(
            children: [
              _themeOpt(context, provider, ThemeMode.system,
                  Icons.phone_android, provider.tr('theme_auto')),
              const SizedBox(width: 8),
              _themeOpt(context, provider, ThemeMode.light,
                  Icons.wb_sunny_outlined, provider.tr('theme_light')),
              const SizedBox(width: 8),
              _themeOpt(context, provider, ThemeMode.dark,
                  Icons.nightlight_outlined, provider.tr('theme_dark')),
            ],
          ),
          const SizedBox(height: 8),
          _languagePicker(context, provider),
        ],
      ),
    );
  }

  Widget _languagePicker(BuildContext context, FASTProvider provider) {
    return DropdownButtonFormField<String>(
      initialValue: provider.appLanguage,
      isDense: true,
      isExpanded: true,
      icon: Icon(Icons.expand_more, color: _subtext(context), size: 18),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _chipBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _chipBorder(context)),
        ),
        filled: true,
        fillColor: _chipBg(context),
      ),
      style: TextStyle(color: _text(context), fontSize: 12),
      dropdownColor: _bg(context),
      items: AppStrings.languages
          .map((l) =>
              DropdownMenuItem(value: l.$1, child: Text(l.$2, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: (v) {
        if (v != null) provider.setAppLanguage(v);
      },
    );
  }

  Widget _themeOpt(BuildContext context, FASTProvider provider,
      ThemeMode mode, IconData icon, String label) {
    final sel = provider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel
                ? FASTBrand.amber.withValues(alpha: 0.15)
                : _chipBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? FASTBrand.amber : _chipBorder(context),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16,
                  color: sel ? FASTBrand.amber : _subtext(context)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? FASTBrand.amber : _subtext(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegal(BuildContext context, String type) {
    final content = type == 'CGU'
        ? tr(context, 'terms_intro') +
            tr(context, 'fast_service_desc') +
            tr(context, 'legal_orders')
        : tr(context, 'privacy_collect') +
            tr(context, 'privacy_data') +
            tr(context, 'data_rights');

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _chipBorder(context)),
        ),
        title: Text(
          type == 'CGU' ? tr(context, 'terms_title') : tr(context, 'privacy'),
          style: TextStyle(
            color: _text(context),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: _subtext(context), fontSize: 12, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: FASTBrand.amber,
              foregroundColor: FASTBrand.onAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(tr(context, 'close'),
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
