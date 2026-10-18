import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../provider.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/tr.dart';
import 'resto_menu_screen.dart';

/// Minimal shell for GUEST staff accounts: menu access only
/// (mark dishes sold out / available). No orders board, no stats,
/// no payments, no private restaurant info.
class GuestMenuShell extends StatefulWidget {
  const GuestMenuShell({super.key});

  @override
  State<GuestMenuShell> createState() => _GuestMenuShellState();
}

class _GuestMenuShellState extends State<GuestMenuShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<RestoProvider>();
    final restoId =
        auth.user?.restaurantId ?? auth.user?.restaurant?['id'] as String?;
    if (restoId != null) {
      await prov.loadFromApi(restaurantId: restoId, menuOnly: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: FASTPro.header,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => FASTPro.logoGradient.createShader(b),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: FASTPro.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: FASTPro.teal.withValues(alpha: 0.4)),
              ),
              child: Text(
                tr(context, 'guest_badge'),
                style: const TextStyle(
                  color: FASTPro.teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => _showSettings(context),
          ),
          IconButton(
            tooltip: tr(context, 'logout'),
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const RestoMenuScreen(),
    );
  }

  /// Guest accounts are real accounts — they get the same personal
  /// preferences as anyone else: language, theme, and client mode so
  /// they can also order as a customer with the same login.
  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final fast = sheetContext.watch<FASTProvider>();
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.fast.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.fast.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(sheetContext, 'settings'),
                style: TextStyle(
                  color: sheetContext.fast.t1,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              // Client mode — order like a customer with the same account
              Material(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final fast = context.read<FASTProvider>();
                    fast.loadFromApi();
                    fast.setViewAsClient(true);
                  },
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C8B3), Color(0xFF0EA5E9)],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fast.tr('client_mode'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                fast.tr('client_mode_sub'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fast.tr('lang_label'),
                style: TextStyle(
                  color: sheetContext.fast.t2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: fast.appLanguage,
                dropdownColor: sheetContext.fast.card,
                style: TextStyle(color: sheetContext.fast.t1, fontSize: 14),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: sheetContext.fast.t3,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: sheetContext.fast.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: sheetContext.fast.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: sheetContext.fast.line),
                  ),
                ),
                items: AppStrings.languages
                    .map(
                      (l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) fast.setAppLanguage(v);
                },
              ),
              const SizedBox(height: 16),
              Text(
                fast.tr('theme_interface'),
                style: TextStyle(
                  color: sheetContext.fast.t2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.system,
                    Icons.brightness_auto,
                    fast.tr('theme_auto'),
                  ),
                  const SizedBox(width: 8),
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.light,
                    Icons.light_mode,
                    fast.tr('theme_light'),
                  ),
                  const SizedBox(width: 8),
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.dark,
                    Icons.dark_mode,
                    fast.tr('theme_dark'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption(
    BuildContext context,
    FASTProvider fast,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final selected = fast.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => fast.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF10B981) : context.fast.line,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : context.fast.t2,
                size: 16,
              ),
              const SizedBox(height: 4),
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
}
