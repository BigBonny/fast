import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'auth_screen.dart';
import '../provider.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/fast_glow_background.dart';
import '../widgets/fast_night_surface.dart';
import '../widgets/fast_ui.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fast = context.watch<FASTProvider>();
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: FastGlowBackground(
          expand: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language picker — reachable before login so users can
                  // switch before they ever see the auth form.
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: PopupMenuButton<String>(
                      tooltip: '',
                      icon: const Icon(
                        Icons.language,
                        color: Colors.white70,
                        size: 22,
                      ),
                      color: context.fast.card,
                      initialValue: fast.appLanguage,
                      onSelected: (v) => fast.setAppLanguage(v),
                      itemBuilder: (_) => AppStrings.languages
                          .map(
                            (l) => PopupMenuItem(
                              value: l.$1,
                              child: Text(
                                l.$2,
                                style: TextStyle(
                                  color: context.fast.t1,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // "Bienvenue sur FAST" headline — FAST restyled big + orange
                  Builder(
                    builder: (context) {
                      final welcome = fast.tr('welcome');
                      final idx = welcome.indexOf('FAST');
                      final prefix = idx < 0
                          ? welcome
                          : welcome.substring(0, idx).trimRight();
                      final suffix = idx < 0
                          ? ''
                          : welcome.substring(idx + 4).trimLeft();
                      return Column(
                        children: [
                          if (prefix.isNotEmpty)
                            Text(
                              prefix,
                              textAlign: TextAlign.center,
                              style: FASTText.display.copyWith(
                                color: FastNightSurface.onNight,
                              ),
                            ),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                FASTBrand.neonGradient.createShader(bounds),
                            child: const Text(
                              'FAST',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          if (suffix.isNotEmpty)
                            Text(
                              suffix,
                              textAlign: TextAlign.center,
                              style: FASTText.title.copyWith(
                                color: FastNightSurface.onNight,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fast.tr('welcome_sub'),
                    textAlign: TextAlign.center,
                    style: FASTText.body.copyWith(
                      color: FastNightSurface.onNightMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Curved neon underline accent
                  const Center(child: _CurvedUnderline()),
                  const SizedBox(height: FASTSpace.s40),

                  // Client card — light surface, gold icon on near-black
                  _RoleCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AuthScreen(initialRole: 'CLIENT'),
                      ),
                    ),
                    night: false,
                    icon: Icons.person_outline,
                    iconColor: FASTBrand.gold,
                    title: fast.tr('iam_client'),
                    description: fast.tr('client_desc'),
                  ),
                  const SizedBox(height: FASTSpace.s16),

                  // Pro card — night surface, teal icon
                  _RoleCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AuthScreen(initialRole: 'RESTAURANT'),
                      ),
                    ),
                    night: true,
                    icon: Icons.storefront_outlined,
                    iconColor: FASTPro.teal,
                    title: fast.tr('iam_pro'),
                    description: fast.tr('pro_desc'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small neon swoosh under the welcome subtitle — a shallow arc
/// dipping in the middle, like the reference design.
class _CurvedUnderline extends StatelessWidget {
  const _CurvedUnderline();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(96, 14),
      painter: _CurvedUnderlinePainter(),
    );
  }
}

class _CurvedUnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width,
        size.height * 0.2,
      );
    final paint = Paint()
      ..shader = FASTBrand.neonGradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One of the two entry cards. The customer card is a light surface and
/// the Pro card a night surface, in both theme modes: this screen always
/// sits on the dark glow background.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.onTap,
    required this.night,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final VoidCallback onTap;
  final bool night;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    const light = FASTShades.light;
    final titleColor = night ? FastNightSurface.onNight : light.t1;
    final descColor = night ? FastNightSurface.onNightMuted : light.t2;
    final chevronColor = night ? FastNightSurface.onNightMuted : light.t3;

    final content = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: night
                ? iconColor.withValues(alpha: 0.14)
                : FASTBrand.onAmber,
            shape: BoxShape.circle,
            border: night
                ? Border.all(color: iconColor.withValues(alpha: 0.4))
                : null,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: FASTSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FASTText.item.copyWith(color: titleColor)),
              const SizedBox(height: FASTSpace.s4),
              Text(
                description,
                style: FASTText.body.copyWith(color: descColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: FASTSpace.s12),
        Icon(Icons.chevron_right, color: chevronColor, size: 24),
      ],
    );

    const padding = EdgeInsets.symmetric(
      horizontal: FASTSpace.s16,
      vertical: 20,
    );

    return Semantics(
      button: true,
      child: FastTap(
        onTap: onTap,
        pressedScale: 0.98,
        child: night
            ? FastNightSurface(padding: padding, child: content)
            : Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: light.card,
                  borderRadius: BorderRadius.circular(FASTRadius.md),
                  border: Border.all(color: light.line),
                ),
                child: content,
              ),
      ),
    );
  }
}
