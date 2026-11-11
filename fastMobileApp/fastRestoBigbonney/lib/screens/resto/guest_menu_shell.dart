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
    final fast = context.fast;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        backgroundColor: fast.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: FASTSpace.s16,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => FASTBrand.neonGradient.createShader(b),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 22),
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
            Flexible(
              child: Container(
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
                  tr(context, 'guest_badge'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.label.copyWith(
                    color: isDark ? FASTPro.teal : FASTPro.tealDark,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'settings'),
            icon: Icon(Icons.settings_outlined, color: fast.t1),
            onPressed: () => _showSettings(context),
          ),
          IconButton(
            tooltip: tr(context, 'logout'),
            icon: const Icon(Icons.logout, color: FASTBrand.error),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(width: FASTSpace.s8),
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FASTRadius.md),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s12,
            FASTSpace.s16,
            FASTSpace.s24,
          ),
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
                style: FASTText.title.copyWith(color: sheetContext.fast.t1),
              ),
              const SizedBox(height: 16),
              // Client mode — order like a customer with the same account
              Material(
                color: sheetContext.fast.cardHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FASTRadius.md),
                  side: BorderSide(color: sheetContext.fast.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final fast = context.read<FASTProvider>();
                    fast.loadFromApi();
                    fast.setViewAsClient(true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(FASTSpace.s16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: sheetContext.fast.t1,
                          size: 22,
                        ),
                        const SizedBox(width: FASTSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fast.tr('client_mode'),
                                style: FASTText.item.copyWith(
                                  color: sheetContext.fast.t1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fast.tr('client_mode_sub'),
                                style: FASTText.caption.copyWith(
                                  color: sheetContext.fast.t2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: FASTSpace.s8),
                        Icon(
                          Icons.arrow_forward,
                          color: sheetContext.fast.t2,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FASTSpace.s24),
              Text(
                fastLabelCase(sheetContext, fast.tr('lang_label')),
                style: FASTText.label.copyWith(color: sheetContext.fast.t2),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: fast.appLanguage,
                dropdownColor: sheetContext.fast.card,
                style: FASTText.body.copyWith(color: sheetContext.fast.t1),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: sheetContext.fast.t3,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: sheetContext.fast.cardHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    borderSide: BorderSide(color: sheetContext.fast.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    borderSide: BorderSide(color: sheetContext.fast.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    borderSide: const BorderSide(
                      color: FASTPro.teal,
                      width: 1.5,
                    ),
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
              const SizedBox(height: FASTSpace.s24),
              Text(
                fastLabelCase(sheetContext, fast.tr('theme_interface')),
                style: FASTText.label.copyWith(color: sheetContext.fast.t2),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.system,
                    Icons.phone_android,
                    fast.tr('theme_auto'),
                  ),
                  const SizedBox(width: 8),
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.light,
                    Icons.wb_sunny_outlined,
                    fast.tr('theme_light'),
                  ),
                  const SizedBox(width: 8),
                  _themeOption(
                    sheetContext,
                    fast,
                    ThemeMode.dark,
                    Icons.nightlight_outlined,
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
    final shades = context.fast;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? (isDark ? FASTPro.teal : FASTPro.tealDark)
        : shades.t2;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          fast.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? FASTPro.teal.withValues(alpha: 0.14)
                : shades.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            border: Border.all(color: selected ? FASTPro.teal : shades.line),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 18),
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
}
