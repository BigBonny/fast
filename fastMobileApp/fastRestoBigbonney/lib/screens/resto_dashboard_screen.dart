import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/tr.dart';

class RestoDashboardScreen extends StatelessWidget {
        RestoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        title: Text(
          tr(context, 'dashboard'),
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
              tr(context, 'wip_title'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.fast.t1),
            ),
                  SizedBox(height: 8), Text(
              tr(context, 'wip_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.fast.t2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
