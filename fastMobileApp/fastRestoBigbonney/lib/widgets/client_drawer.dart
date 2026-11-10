import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../screens/account_screen.dart';
import '../screens/assistant_screen.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'fast_night_surface.dart';

/// Slide-in account menu for the client app: night-surface header with
/// the wordmark, the user's name and the points pill, plain icon rows,
/// expandable Réglages (theme + language pickers), and a red outlined
/// logout button.
class ClientDrawer extends StatelessWidget {
  const ClientDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FASTProvider>();
    final fast = context.fast;
    final topInset = MediaQuery.paddingOf(context).top;

    return Drawer(
      backgroundColor: fast.card,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          // ─── Header ───
          // The night surface runs under the status bar, so its icons
          // are forced light. Clipped so the glow stays inside the header.
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: _header(context, provider, topInset),
          ),

          // ─── Menu items ───
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: FASTSpace.s8),
                children: [
                  _item(
                    context,
                    icon: Icons.person_outline,
                    label: provider.tr('my_account'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    label: provider.tr('my_orders'),
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.navigateToScreen('commandes');
                    },
                  ),
                  _settingsItem(context, provider),
                  _item(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    label: provider.tr('assistant_title'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AssistantScreen(),
                        ),
                      );
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.favorite_border,
                    label: provider.tr('favorites'),
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.navigateToScreen('home');
                    },
                  ),
                  _item(
                    context,
                    icon: Icons.location_on_outlined,
                    label: provider.tr('addresses'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
                  ),
                  _groupDivider(context),
                  // Owners/staff who switched to client mode get a way back
                  if (context.watch<AuthProvider>().isRestaurant ||
                      (context.watch<AuthProvider>().user?.isStaff ??
                          false)) ...[
                    _proBanner(context, provider),
                    _groupDivider(context),
                  ],
                  _item(
                    context,
                    icon: Icons.shield_outlined,
                    label: provider.tr('privacy'),
                    onTap: () => _showLegal(context, tr(context, 'privacy')),
                  ),
                  _item(
                    context,
                    icon: Icons.description_outlined,
                    label: provider.tr('cgu'),
                    onTap: () => _showLegal(context, 'CGU'),
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
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final auth = context.read<AuthProvider>();
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
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

  Widget _header(BuildContext context, FASTProvider provider, double topInset) {
    return Column(
      children: [
        ClipRect(
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
                      const Icon(Icons.bolt, color: FASTBrand.amber, size: 22),
                      const SizedBox(width: 2),
                      Text(
                        'FAST',
                        style: FASTText.title.copyWith(
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1,
                          color: FastNightSurface.onNight,
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
                    padding: const EdgeInsetsDirectional.only(
                      end: FASTSpace.s12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.userName.isNotEmpty
                              ? provider.userName
                              : tr(context, 'my_account'),
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
                        const SizedBox(height: FASTSpace.s16),
                        _pointsPill(provider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dark pill with the points balance — on the night surface only.
  Widget _pointsPill(FASTProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s12,
        vertical: FASTSpace.s8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(FASTRadius.pill),
        border: Border.all(color: FASTBrand.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_outlined, color: FASTBrand.amber, size: 16),
          const SizedBox(width: FASTSpace.s4),
          Text(
            '${provider.userPoints} ${provider.tr('tab_points')}',
            style: FASTText.price.copyWith(
              fontSize: 14,
              color: FASTBrand.amber,
            ),
          ),
          const SizedBox(width: FASTSpace.s4),
          Flexible(
            child: Text(
              '· ${provider.tr('points_wallet')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FASTText.caption.copyWith(
                color: FastNightSurface.onNightMuted,
              ),
            ),
          ),
        ],
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

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
      horizontalTitleGap: FASTSpace.s12,
      leading: Icon(icon, color: context.fast.t2, size: 22),
      title: Text(label, style: _rowStyle(context)),
      trailing: Icon(Icons.chevron_right, color: context.fast.t3, size: 20),
      shape: const RoundedRectangleBorder(),
    );
  }

  Widget _settingsItem(BuildContext context, FASTProvider provider) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
        leading: Icon(
          Icons.settings_outlined,
          color: context.fast.t2,
          size: 22,
        ),
        title: Text(provider.tr('settings'), style: _rowStyle(context)),
        iconColor: context.fast.t2,
        collapsedIconColor: context.fast.t3,
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(
          FASTSpace.s16,
          0,
          FASTSpace.s16,
          FASTSpace.s12,
        ),
        children: [
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
        ],
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
        focusedBorder: border(fast.ink),
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

  /// Ink card so restaurant owners instantly spot the way back into
  /// FAST Pro while browsing the client experience.
  Widget _proBanner(BuildContext context, FASTProvider provider) {
    final fast = context.fast;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s16,
        vertical: FASTSpace.s4,
      ),
      child: Material(
        color: fast.ink,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            provider.setViewAsClient(false);
          },
          child: Padding(
            padding: const EdgeInsets.all(FASTSpace.s16),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: fast.onInk, size: 22),
                const SizedBox(width: FASTSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAST PRO',
                        style: FASTText.label.copyWith(
                          fontSize: 14,
                          color: fast.onInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.tr('pro_space'),
                        style: FASTText.caption.copyWith(
                          color: fast.onInk.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: fast.onInk, size: 20),
              ],
            ),
          ),
        ),
      ),
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
    final fg = sel ? fast.onInk : fast.t2;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          provider.setThemeMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? fast.ink : fast.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            border: Border.all(color: sel ? fast.ink : fast.line),
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
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: fast.ink,
              foregroundColor: fast.onInk,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
