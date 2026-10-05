import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../l10n/app_strings.dart';
import '../resto_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/resto/menu_ai_scanner_screen.dart';
import '../screens/resto/resto_staff_screen.dart';
import '../theme.dart';
import '../l10n/tr.dart';

/// Base44-style slide-in menu for Fast Pro: compact gradient wordmark,
/// flat sectioned rows (Mon Service / Commandes / Menu / Réglages),
/// OUTILS AVANCÉS section (Statistiques, Intelligence IA, Mon équipe),
/// legal links and red-outlined logout.
class RestoDrawer extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onReplayTutorial;

  const RestoDrawer({
    super.key,
    required this.onNavigate,
    required this.onReplayTutorial,
  });

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color _bg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0F172A) : Colors.white;
  static Color _surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  static Color _text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  static Color _subtext(BuildContext context) =>
      _isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color _chipBg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color _chipBorder(BuildContext context) =>
      _isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  void _go(BuildContext context, int index) {
    Navigator.of(context).pop();
    onNavigate(index);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FASTProvider>();
    final resto = context.watch<RestoProvider>();
    final restoName = resto.settings?.name ?? 'Mon Restaurant';

    return Drawer(
      backgroundColor: _bg(context),
      child: SafeArea(
        child: Column(
          children: [
            // ─── Compact header — matches the app bar wordmark ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 4, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF020617),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            FASTPro.logoGradient.createShader(b),
                        child: const Text(
                          '⚡ FAST',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        'RESTAURATEUR PRO',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      restoName,
                      style: TextStyle(
                        color: _subtext(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ─── Main navigation ───
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _row(context,
                      emoji: '📋',
                      label: provider.tr('my_service'),
                      onTap: () => _go(context, 4)),
                  _row(context,
                      emoji: '🛍️',
                      label: provider.tr('nav_orders'),
                      onTap: () => _go(context, 0)),
                  _row(context,
                      emoji: '🍽️',
                      label: provider.tr('menu'),
                      onTap: () => _go(context, 1)),
                  _settingsItem(context, provider, resto),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          await provider.setViewAsClient(true);
                          if (!context.mounted) return;
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C8B3), Color(0xFF0EA5E9)],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.tr('client_mode'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      provider.tr('client_mode_sub'),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      provider.tr('advanced_tools'),
                      style: TextStyle(
                        color: _subtext(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  _row(context,
                      emoji: '📈',
                      label: provider.tr('stats'),
                      onTap: () => _go(context, 2)),
                  _row(context,
                      emoji: '🤖',
                      label: provider.tr('ai_intel'),
                      subtitle: provider.tr('ai_intel_sub'),
                      onTap: () =>
                          _push(context, const MenuAiScannerScreen())),
                  _row(context,
                      emoji: '👥',
                      label: provider.tr('my_team'),
                      subtitle: provider.tr('my_team_sub'),
                      onTap: () =>
                          _push(context, const RestoStaffScreen())),

                  const SizedBox(height: 14),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      provider.tr('legal'),
                      style: TextStyle(
                        color: _subtext(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  _row(context,
                      emoji: '📄',
                      label: provider.tr('cgu'),
                      onTap: () => _showLegal(context, 'CGU')),
                  _row(context,
                      emoji: '🔐',
                      label: provider.tr('privacy'),
                      onTap: () => _showLegal(context, tr(context, 'privacy'))),
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
                    Navigator.of(context).popUntil((route) => route.isFirst);
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

  /// Base44 row: emoji in a rounded tile + label, full-width card.
  Widget _row(
    BuildContext context, {
    required String emoji,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: _surface(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: _text(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _subtext(context),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: _subtext(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsItem(
      BuildContext context, FASTProvider provider, RestoProvider resto) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: _surface(context),
        borderRadius: BorderRadius.circular(10),
        child: ExpansionTile(
          leading: const Text('⚙️', style: TextStyle(fontSize: 18)),
          title: Text(
            provider.tr('settings'),
            style: TextStyle(
              color: _text(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          iconColor: _subtext(context),
          collapsedIconColor: _subtext(context),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 8, bottom: 8),
          children: [
            // Rush mode toggle
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                provider.tr('rush_mode'),
                style: TextStyle(
                  color: _text(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                provider.tr('rush_desc'),
                style: TextStyle(color: _subtext(context), fontSize: 11),
              ),
              secondary: const Icon(Icons.local_fire_department,
                  color: FASTPro.magenta, size: 20),
              activeThumbColor: FASTPro.magenta,
              value: resto.isRushMode,
              onChanged: (_) => resto.toggleRushMode(),
            ),
            const SizedBox(height: 8),
            // Theme picker
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
            const SizedBox(height: 8),
            // Advanced settings + tutorial shortcuts
            _miniItem(context, Icons.tune, provider.tr('advanced_settings'),
                () => _go(context, 3)),
            _miniItem(context, Icons.help_outline, provider.tr('replay_tutorial'), () {
              Navigator.of(context).pop();
              onReplayTutorial();
            }),
          ],
        ),
      ),
    );
  }

  Widget _miniItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: FASTPro.teal),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: _subtext(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
            color:
                sel ? FASTPro.teal.withValues(alpha: 0.15) : _chipBg(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? FASTPro.teal : _chipBorder(context),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16, color: sel ? FASTPro.teal : _subtext(context)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? FASTPro.teal : _subtext(context),
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
              backgroundColor: FASTPro.teal,
              foregroundColor: Colors.white,
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
