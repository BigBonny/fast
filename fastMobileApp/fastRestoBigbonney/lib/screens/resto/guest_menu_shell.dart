import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
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
      await prov.loadFromApi(restaurantId: restoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: FASTPro.header,
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
}
