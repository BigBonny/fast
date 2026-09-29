import 'package:flutter/material.dart';
import '../theme.dart';

class RestoDashboardScreen extends StatelessWidget {
        RestoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        title: Text(
          'Dashboard Restaurant',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.fast.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ Icon(Icons.construction, size: 64, color: Color(0xFFF59E0B)),
                  SizedBox(height: 16), Text(
              'Espace Restaurant en construction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.fast.t1),
            ),
                  SizedBox(height: 8), Text(
              'Les fonctionnalités définies dans votre cahier des charges\n(Commandes, Menu, Stats...) arriveront bientôt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.fast.t2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
