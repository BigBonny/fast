import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../l10n/app_strings.dart';
import '../resto_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/resto/menu_ai_scanner_screen.dart';
import '../screens/resto/resto_reservations_screen.dart';
import '../screens/resto/resto_staff_screen.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'fast_night_surface.dart';
import 'fast_ui.dart';

/// Slide-in menu for FAST Pro, the twin of the customer drawer:
/// night-surface header with the wordmark and the restaurant name, plain
/// icon rows (Mon Service / Commandes / Menu / Réglages), the way into
/// client mode, the advanced tools (Statistiques, Intelligence IA, Mon
/// équipe, Réservations), legal links and a red outlined logout.
class RestoDrawer extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onReplayTutorial;

  const RestoDrawer({
    super.key,
    required this.onNavigate,
    required this.onReplayTutorial,
  });

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
    final auth = context.watch<AuthProvider>();
    final restoName = resto.settings?.name ?? provider.tr('my_service');
    final fast = context.fast;
    final topInset = MediaQuery.paddingOf(context).top;

    return Drawer(
      backgroundColor: fast.card,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          // ─── Header ───
          // The night surface runs under the status bar, so its icons
          // are forced light.
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: _header(context, restoName, auth.user?.email, topInset),
          ),

          // ─── Main navigation ───
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: FASTSpace.s8),
                children: [
                  _row(
                    context,
                    icon: Icons.storefront_outlined,
                    label: provider.tr('my_service'),
                    onTap: () => _go(context, 4),
                  ),
                  _row(
                    context,
                    icon: Icons.receipt_long_outlined,
                    label: provider.tr('nav_orders'),
                    onTap: () => _go(context, 0),
                  ),
                  _row(
                    context,
                    icon: Icons.restaurant_menu_outlined,
                    label: provider.tr('menu'),
                    onTap: () => _go(context, 1),
                  ),
                  _settingsItem(context, provider, resto),
                  _groupDivider(context),
                  _clientBanner(context, provider),
                  _groupDivider(context),

                  _sectionLabel(context, provider.tr('advanced_tools')),
                  _row(
                    context,
                    icon: Icons.insights_outlined,
                    label: provider.tr('stats'),
                    onTap: () => _go(context, 2),
                  ),
                  _row(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    label: provider.tr('ai_intel'),
                    subtitle: provider.tr('ai_intel_sub'),
                    onTap: () => _push(context, const MenuAiScannerScreen()),
                  ),
                  _row(
                    context,
                    icon: Icons.groups_outlined,
                    label: provider.tr('my_team'),
                    subtitle: provider.tr('my_team_sub'),
                    onTap: () => _push(context, const RestoStaffScreen()),
                  ),
                  _row(
                    context,
                    icon: Icons.event_outlined,
                    label: provider.tr('reservations'),
                    onTap: () =>
                        _push(context, const RestoReservationsScreen()),
                  ),
                  _groupDivider(context),

                  _sectionLabel(context, provider.tr('legal')),
                  _row(
                    context,
                    icon: Icons.description_outlined,
                    label: provider.tr('cgu'),
                    onTap: () => _showLegal(context, 'CGU'),
                  ),
                  _row(
                    context,
                    icon: Icons.shield_outlined,
                    label: provider.tr('privacy'),
                    onTap: () => _showLegal(context, tr(context, 'privacy')),
                  ),
                ],
              ),
            ),
          ),

          // ─── Logout ───
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FASTSpace.s16,
                FASTSpace.s8,
                FASTSpace.s16,
                FASTSpace.s16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.isLoggingOut
                      ? null
                      : () {
                          final auth = context.read<AuthProvider>();
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          auth.logout();
                        },
                  icon: const Icon(
                    Icons.logout,
                    color: FASTBrand.error,
                    size: 18,
                  ),
                  label: Text(
                    provider.tr('logout'),
                    style: const TextStyle(
                      color: FASTBrand.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: FASTBrand.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String restoName,
    String? email,
    double topInset,
  ) {
    return ClipRect(
      child: SizedBox(
        width: double.infinity,
        child: FastNightSurface(
          radius: 0,
          padding: EdgeInsetsDirectional.fromSTEB(
            FASTSpace.s16,
            topInset + FASTSpace.s8,
            FASTSpace.s4,
            FASTSpace.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        FASTBrand.neonGradient.createShader(b),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 22),
                        const SizedBox(width: 2),
                        Text(
                          'FAST',
                          style: FASTText.title.copyWith(
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FASTSpace.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: FASTPro.teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                      border: Border.all(
                        color: FASTPro.teal.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'PRO',
                      style: FASTText.label.copyWith(color: FASTPro.teal),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: FastNightSurface.onNightMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: FASTSpace.s12),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: FASTSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restoName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.title.copyWith(
                        color: FastNightSurface.onNight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RESTAURATEUR PRO',
                      style: FASTText.caption.copyWith(
                        color: FastNightSurface.onNightMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
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
            ],
          ),
        ),
      ),
    );
  }

  static TextStyle _rowStyle(BuildContext context) => FASTText.item.copyWith(
    fontWeight: FontWeight.w600,
    color: context.fast.t1,
  );

  Widget _groupDivider(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FASTSpace.s8),
    child: Divider(
      height: 1,
      thickness: 1,
      indent: FASTSpace.s16,
      endIndent: FASTSpace.s16,
      color: context.fast.line,
    ),
  );

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      FASTSpace.s16,
      FASTSpace.s8,
      FASTSpace.s16,
      FASTSpace.s4,
    ),
    child: Text(
      fastLabelCase(context, text),
      style: FASTText.label.copyWith(color: context.fast.t3),
    ),
  );

  /// Plain row: neutral line icon, label, optional caption, chevron.
  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
      horizontalTitleGap: FASTSpace.s12,
      leading: Icon(icon, color: context.fast.t2, size: 22),
      title: Text(label, style: _rowStyle(context)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: FASTText.caption.copyWith(color: context.fast.t2),
            ),
      trailing: Icon(Icons.chevron_right, color: context.fast.t3, size: 20),
      shape: const RoundedRectangleBorder(),
    );
  }

  /// Outline card: the way out of FAST Pro into the customer experience.
  Widget _clientBanner(BuildContext context, FASTProvider provider) {
    final fast = context.fast;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s16,
        vertical: FASTSpace.s4,
      ),
      child: Material(
        color: fast.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
          side: BorderSide(color: fast.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            provider.setViewAsClient(true);
          },
          child: Padding(
            padding: const EdgeInsets.all(FASTSpace.s16),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: fast.t1, size: 22),
                const SizedBox(width: FASTSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.tr('client_mode'),
                        style: FASTText.item.copyWith(color: fast.t1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.tr('client_mode_sub'),
                        style: FASTText.caption.copyWith(color: fast.t2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FASTSpace.s8),
                Icon(Icons.arrow_forward, color: fast.t2, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsItem(
    BuildContext context,
    FASTProvider provider,
    RestoProvider resto,
  ) {
    final fast = context.fast;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
        leading: Icon(Icons.settings_outlined, color: fast.t2, size: 22),
        title: Text(provider.tr('settings'), style: _rowStyle(context)),
        iconColor: fast.t2,
        collapsedIconColor: fast.t3,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(
          FASTSpace.s16,
          0,
          FASTSpace.s16,
          FASTSpace.s12,
        ),
        children: [
          // Rush mode toggle — magenta is the rush colour everywhere.
          FastSwitchTile(
            title: Text(
              provider.tr('rush_mode'),
              style: FASTText.body.copyWith(
                color: fast.t1,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              provider.tr('rush_desc'),
              style: FASTText.caption.copyWith(color: fast.t2),
            ),
            leading: const Icon(
              Icons.local_fire_department_outlined,
              color: FASTPro.magenta,
              size: 22,
            ),
            accent: FASTPro.magenta,
            value: resto.isRushMode,
            onChanged: (_) => resto.toggleRushMode(),
          ),
          const SizedBox(height: FASTSpace.s8),
          // Theme picker
          Row(
            children: [
              _themeOpt(
                context,
                provider,
                ThemeMode.system,
                Icons.phone_android,
                provider.tr('theme_auto'),
              ),
              const SizedBox(width: FASTSpace.s8),
              _themeOpt(
                context,
                provider,
                ThemeMode.light,
                Icons.wb_sunny_outlined,
                provider.tr('theme_light'),
              ),
              const SizedBox(width: FASTSpace.s8),
              _themeOpt(
                context,
                provider,
                ThemeMode.dark,
                Icons.nightlight_outlined,
                provider.tr('theme_dark'),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s8),
          _languagePicker(context, provider),
          const SizedBox(height: FASTSpace.s8),
          // Advanced settings + tutorial shortcuts
          _miniItem(
            context,
            Icons.tune,
            provider.tr('advanced_settings'),
            () => _go(context, 3),
          ),
          _miniItem(
            context,
            Icons.help_outline,
            provider.tr('replay_tutorial'),
            () {
              Navigator.of(context).pop();
              onReplayTutorial();
            },
          ),
        ],
      ),
    );
  }

  Widget _miniItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final fast = context.fast;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fast.t2),
            const SizedBox(width: FASTSpace.s12),
            Expanded(
              child: Text(
                label,
                style: FASTText.body.copyWith(
                  color: fast.t1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: fast.t3),
          ],
        ),
      ),
    );
  }

  Widget _languagePicker(BuildContext context, FASTProvider provider) {
    final fast = context.fast;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(FASTRadius.sm),
      borderSide: BorderSide(color: color),
    );
    return DropdownButtonFormField<String>(
      initialValue: provider.appLanguage,
      isDense: true,
      isExpanded: true,
      icon: Icon(Icons.expand_more, color: fast.t2, size: 20),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FASTSpace.s12,
          vertical: 10,
        ),
        border: border(fast.line),
        enabledBorder: border(fast.line),
        focusedBorder: border(FASTPro.teal),
        filled: true,
        fillColor: fast.cardHigh,
      ),
      style: FASTText.body.copyWith(color: fast.t1),
      dropdownColor: fast.card,
      items: AppStrings.languages
          .map(
            (l) => DropdownMenuItem(
              value: l.$1,
              child: Text(l.$2, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) provider.setAppLanguage(v);
      },
    );
  }

  Widget _themeOpt(
    BuildContext context,
    FASTProvider provider,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final fast = context.fast;
    final sel = provider.themeMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = sel ? (isDark ? FASTPro.teal : FASTPro.tealDark) : fast.t2;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          provider.setThemeMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? FASTPro.teal.withValues(alpha: 0.14) : fast.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            border: Border.all(color: sel ? FASTPro.teal : fast.line),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
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

  void _showLegal(BuildContext context, String type) {
    final content = type == 'CGU'
        ? tr(context, 'terms_intro') +
              tr(context, 'fast_service_desc') +
              tr(context, 'legal_orders')
        : tr(context, 'privacy_collect') +
              tr(context, 'privacy_data') +
              tr(context, 'data_rights');
    final fast = context.fast;

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
          side: BorderSide(color: fast.line),
        ),
        title: Text(
          type == 'CGU' ? tr(context, 'terms_title') : tr(context, 'privacy'),
          style: FASTText.item.copyWith(color: fast.t1),
        ),
        content: Text(
          content,
          style: FASTText.caption.copyWith(color: fast.t2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: fast.t1,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              tr(context, 'close'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
