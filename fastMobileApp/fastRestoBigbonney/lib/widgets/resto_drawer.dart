import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../resto_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

/// Base44-style slide-in menu for Fast Pro (restaurant accounts):
/// gradient header with wordmark + restaurant avatar, tinted icon rows,
/// expandable Réglages (theme + rush mode + tutorial), red outlined logout.
class RestoDrawer extends StatelessWidget {
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onReplayTutorial;

  const RestoDrawer({
    super.key,
    required this.onNavigate,
    required this.onReplayTutorial,
  });

  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)],
  );

  void _go(BuildContext context, int index) {
    Navigator.of(context).pop();
    onNavigate(index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FASTProvider>();
    final resto = context.watch<RestoProvider>();
    final settings = resto.settings;
    final restoName = settings?.name ?? 'Mon Restaurant';
    final initial =
        restoName.isNotEmpty ? restoName.characters.first.toUpperCase() : 'R';

    return Drawer(
      backgroundColor: context.fast.bg,
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
                        shaderCallback: (b) =>
                            FASTPro.logoGradient.createShader(b),
                        child: const Text(
                          '⚡ FAST PRO',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 3,
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
                          gradient: FASTPro.logoGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
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
                              restoName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (settings != null && settings.city.isNotEmpty)
                              Text(
                                '${settings.cuisineType} · ${settings.city}',
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
                      color: FASTPro.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Partenaire · FAST Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
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
                    label: 'Mon compte',
                    onTap: () => _go(context, 4),
                  ),
                  _item(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFF60A5FA),
                    label: 'Mes commandes',
                    onTap: () => _go(context, 0),
                  ),
                  _settingsItem(context, provider, resto),
                  _item(
                    context,
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF38BDF8),
                    label: 'Confidentialité',
                    onTap: () => _showLegal(context, 'Confidentialité'),
                  ),
                  _item(
                    context,
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFFFBBF24),
                    label: 'CGU',
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
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout,
                      color: Color(0xFFEF4444), size: 18),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(
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
          color: context.fast.t1,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _settingsItem(
      BuildContext context, FASTProvider provider, RestoProvider resto) {
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
          'Réglages',
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        iconColor: context.fast.t3,
        collapsedIconColor: context.fast.t3,
        childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
        children: [
          // Rush mode toggle
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Mode Rush',
              style: TextStyle(
                color: context.fast.t1,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Temps de prépa allongés',
              style: TextStyle(color: context.fast.t3, fontSize: 11),
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
                  Icons.phone_android, 'Auto'),
              const SizedBox(width: 8),
              _themeOpt(context, provider, ThemeMode.light,
                  Icons.wb_sunny_outlined, 'Clair'),
              const SizedBox(width: 8),
              _themeOpt(context, provider, ThemeMode.dark,
                  Icons.nightlight_outlined, 'Sombre'),
            ],
          ),
          const SizedBox(height: 8),
          // Advanced settings + tutorial shortcuts
          _miniItem(context, Icons.tune, 'Paramètres avancés',
              () => _go(context, 3)),
          _miniItem(context, Icons.help_outline, 'Revoir le tutoriel', () {
            Navigator.of(context).pop();
            onReplayTutorial();
          }),
        ],
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
                color: context.fast.t2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
                sel ? FASTPro.teal.withValues(alpha: 0.15) : context.fast.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? FASTPro.teal : context.fast.line,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16, color: sel ? FASTPro.teal : context.fast.t2),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: sel ? FASTPro.teal : context.fast.t2,
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
        ? 'En utilisant FAST, vous acceptez nos conditions générales d\'utilisation. '
            'FAST est un service de commande Click & Collect et de livraison pour restaurants. '
            'Les commandes sont préparées par les restaurants partenaires. Les paiements sont '
            'sécurisés par Stripe. Vous pouvez demander la suppression de votre compte à tout moment.'
        : 'FAST collecte votre nom, e-mail, téléphone et position (avec votre accord) pour '
            'permettre la commande et la livraison. Vos données ne sont jamais vendues. '
            'Vous pouvez les modifier ou supprimer votre compte à tout moment depuis cette page.';

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.fast.line),
        ),
        title: Text(
          type == 'CGU' ? 'Conditions générales' : 'Confidentialité',
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
              backgroundColor: FASTPro.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Fermer',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
