import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import '../widgets/fast_ui.dart';

class RestoDashboardScreen extends StatelessWidget {
  const RestoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Scaffold(
      backgroundColor: fast.bg,
      appBar: AppBar(
        title: Text(
          tr(context, 'dashboard'),
          style: FASTText.title.copyWith(color: fast.t1),
        ),
        backgroundColor: fast.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: FastEmpty(
          icon: Icons.construction_outlined,
          title: tr(context, 'wip_title'),
          subtitle: tr(context, 'wip_desc'),
          accent: FASTPro.teal,
        ),
      ),
    );
  }
}
