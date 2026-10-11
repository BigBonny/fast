import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'auth_screen.dart';
import '../provider.dart';
import '../theme.dart';
import '../widgets/fast_glow_background.dart';

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
                  const SizedBox(height: 40),
                  // Logo — ⚡ FAST ⚡ wordmark + tagline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: FASTBrand.amber, size: 40),
                      const SizedBox(width: 6),
                      const Text(
                        'FAST',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.bolt, color: FASTBrand.amber, size: 40),
                    ],
                  ),
                  const Text(
                    'Chaque minute compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFFD8D0E8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 48),

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
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
                            ).createShader(bounds),
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
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB8AECF),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Orange underline accent
                  Center(
                    child: Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Client card — light card, person icon
                  _RoleCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AuthScreen(initialRole: 'CLIENT'),
                      ),
                    ),
                    cardColor: const Color(0xFFF6F1EA),
                    icon: Icons.person_outline,
                    iconColor: const Color(0xFFF97316),
                    iconBg: const Color(0xFFFDE8D7),
                    title: fast.tr('iam_client'),
                    titleColor: const Color(0xFF1A1425),
                    description: fast.tr('client_desc'),
                    descColor: const Color(0xFF5F5870),
                    chevronColor: const Color(0xFFF0E5D8),
                    chevronIconColor: const Color(0xFF1A1425),
                  ),
                  const SizedBox(height: 16),

                  // Pro card — amber glass card
                  _RoleCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AuthScreen(initialRole: 'RESTAURANT'),
                      ),
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xCCB45309), Color(0xCCEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: const Color(0x80FBBF24),
                    icon: Icons.restaurant,
                    iconColor: const Color(0xFFFBBF24),
                    iconBg: const Color(0x40FDE68A),
                    title: fast.tr('iam_pro'),
                    titleColor: Colors.white,
                    description: fast.tr('pro_desc'),
                    descColor: const Color(0xFFFDE8D7),
                    chevronColor: const Color(0x40FFFFFF),
                    chevronIconColor: Colors.white,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.titleColor,
    required this.description,
    required this.descColor,
    required this.chevronColor,
    required this.chevronIconColor,
    this.cardColor,
    this.gradient,
    this.borderColor,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Color titleColor;
  final String description;
  final Color descColor;
  final Color chevronColor;
  final Color chevronIconColor;
  final Color? cardColor;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: cardColor,
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.2)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: descColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: chevronColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: chevronIconColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
