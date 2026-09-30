import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../theme.dart';

class RoleSelectionScreen extends StatelessWidget {
        const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    SizedBox(height: 24),
              // Logo — website wordmark style
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.bolt, color: FASTBrand.onAmber, size: 34),
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                      ).createShader(bounds),
                      child: const Text(
                        'FAST',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 4, top: 30),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C8B3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
                    SizedBox(height: 32), Text(
                'Bienvenue sur FAST',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.fast.t1,
                  letterSpacing: -0.5,
                ),
              ),
                    SizedBox(height: 8), Text(
                'Choisissez votre profil pour continuer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.fast.t2,
                ),
              ),
                    SizedBox(height: 64),
              
              // Client Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'CLIENT'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.fast.card,
                  foregroundColor: context.fast.t1,
                  padding: EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: context.fast.line),
                  ),
                  elevation: 0,
                ),
                child:       Column(
                  children: [ Icon(Icons.person_outline, size: 36, color: Color(0xFFF59E0B)),
                    SizedBox(height: 16), Text(
                      'Je suis un Client',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4), Text(
                      'Commander, payer, réserver et votre repas est prêt juste à votre arrivée.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: context.fast.t2, fontWeight: FontWeight.normal, height: 1.4),
                    ),
                  ],
                ),
              ),
              
                    SizedBox(height: 20),
              
              // Resto Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'RESTAURANT'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  foregroundColor: FASTBrand.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Column(
                  children: [ Icon(Icons.restaurant, size: 36),
                    SizedBox(height: 16), Text(
                      'Je suis un Pro',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4), Text(
                      'FAST Pro — Gérer mon restaurant',
                      style: TextStyle(fontSize: 12, color: Color(0xCC09090B), fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
                    SizedBox(height: 20),

              // Driver Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(initialRole: 'LIVREUR'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.fast.card,
                  foregroundColor: context.fast.t1,
                  padding: EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: context.fast.faint),
                  ),
                  elevation: 0,
                ),
                child:       Column(
                  children: [ Icon(Icons.delivery_dining_outlined, size: 34, color: Color(0xFF10B981)),
                    SizedBox(height: 12), Text(
                      'Je suis un Livreur',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4), Text(
                      'Occasionnel ou permanent',
                      style: TextStyle(fontSize: 12, color: context.fast.t2, fontWeight: FontWeight.normal),
                    ),
                    SizedBox(height: 4), Text(
                      'Livraison à domicile',
                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
