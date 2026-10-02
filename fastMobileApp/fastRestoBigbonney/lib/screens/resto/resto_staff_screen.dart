// lib/screens/resto/resto_staff_screen.dart
//
// Owner-only: create unlimited cook/guest accounts. Cooks log in with
// email+password and land directly on the kitchen board — no stats,
// no payments, no settings.

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_config.dart';
import '../../api/api_exceptions.dart';
import '../../theme.dart';

class RestoStaffScreen extends StatefulWidget {
  const RestoStaffScreen({super.key});

  @override
  State<RestoStaffScreen> createState() => _RestoStaffScreenState();
}

class _RestoStaffScreenState extends State<RestoStaffScreen> {
  final _api = ApiClient();
  List<dynamic> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get(ApiConfig.staff);
      _staff = data as List<dynamic>;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Erreur de chargement';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String staffId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
            '$name perdra immédiatement l\'accès au tableau des commandes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete(ApiConfig.staffMember(staffId));
      _load();
    } catch (e) {
      _toast(e is ApiException ? e.message : 'Erreur de suppression');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCreateSheet() {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    var role = 'GUEST';
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouveau compte cuisinier',
                  style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'Le compte donne accès uniquement au tableau des commandes.',
                style: TextStyle(color: context.fast.t3, fontSize: 11),
              ),
              const SizedBox(height: 16),
              _field(nameC, 'Nom (ex: Karim)', Icons.person_outline),
              const SizedBox(height: 10),
              _field(emailC, 'Email', Icons.mail_outline,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _field(passC, 'Mot de passe', Icons.lock_outline,
                  obscure: true),
              const SizedBox(height: 14),
              // Role picker
              Row(
                children: [
                  _roleChip(ctx, setSheet, 'GUEST', 'Cuisinier',
                      'Tableau uniquement', role, (r) => role = r),
                  const SizedBox(width: 8),
                  _roleChip(ctx, setSheet, 'STAFF', 'Manager',
                      'Commandes + menu', role, (r) => role = r),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameC.text.trim().isEmpty ||
                            emailC.text.trim().isEmpty ||
                            passC.text.length < 6) {
                          _toast('Nom, email et mot de passe (6+) requis');
                          return;
                        }
                        setSheet(() => saving = true);
                        try {
                          await _api.post(ApiConfig.staff, body: {
                            'name': nameC.text.trim(),
                            'email': emailC.text.trim(),
                            'password': passC.text,
                            'staffRole': role,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } catch (e) {
                          setSheet(() => saving = false);
                          _toast(e is ApiException
                              ? e.message
                              : 'Erreur de création');
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FASTPro.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(saving ? 'Création…' : 'Créer le compte',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleChip(BuildContext ctx, StateSetter setSheet, String value,
      String label, String sub, String current, void Function(String) onSel) {
    final sel = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setSheet(() => onSel(value)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? FASTPro.teal.withValues(alpha: 0.15)
                : context.fast.cardHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? FASTPro.teal : context.fast.line,
                width: sel ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: sel ? FASTPro.teal : context.fast.t1,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              Text(sub,
                  style: TextStyle(color: context.fast.t3, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType? type, bool obscure = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: TextStyle(color: context.fast.t1, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.fast.t3),
        prefixIcon: Icon(icon, size: 18, color: context.fast.t3),
        filled: true,
        fillColor: context.fast.cardHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.fast.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.fast.line),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        title: Text('Équipe & comptes invités',
            style: TextStyle(
                color: context.fast.t1,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: FASTPro.teal,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter un cuisinier',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FASTPro.teal))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: TextStyle(color: context.fast.t2)),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Réessayer')),
                    ],
                  ),
                )
              : _staff.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🧑‍🍳',
                                style: TextStyle(fontSize: 44)),
                            const SizedBox(height: 10),
                            Text('Aucun compte cuisinier',
                                style: TextStyle(
                                    color: context.fast.t1,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(
                              'Créez des comptes pour vos cuisiniers : ils auront accès uniquement au tableau des commandes, sans statistiques ni paiements.',
                              style: TextStyle(
                                  color: context.fast.t3, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: FASTPro.teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _staff.length,
                        itemBuilder: (_, i) {
                          final s = _staff[i] as Map<String, dynamic>;
                          final user = s['user'] as Map<String, dynamic>;
                          final isGuest = s['staffRole'] == 'GUEST';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.fast.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.fast.line),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      FASTPro.teal.withValues(alpha: 0.15),
                                  child: Text(
                                    (user['name'] as String? ?? '?')
                                        .characters
                                        .first
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: FASTPro.teal,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user['name'] as String? ?? '',
                                          style: TextStyle(
                                              color: context.fast.t1,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14)),
                                      Text(user['email'] as String? ?? '',
                                          style: TextStyle(
                                              color: context.fast.t3,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isGuest
                                            ? FASTPro.magenta
                                            : FASTPro.teal)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isGuest ? 'CUISINIER' : 'MANAGER',
                                    style: TextStyle(
                                        color: isGuest
                                            ? FASTPro.magenta
                                            : FASTPro.teal,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _delete(
                                      s['id'] as String,
                                      user['name'] as String? ?? ''),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
