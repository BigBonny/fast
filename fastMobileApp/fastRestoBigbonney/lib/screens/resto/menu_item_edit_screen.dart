import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../resto_provider.dart';
import '../../services/menu_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';

class MenuItemEditScreen extends StatefulWidget {
  final MenuItem? item; // null = create mode

  const MenuItemEditScreen({super.key, this.item});

  @override
  State<MenuItemEditScreen> createState() => _MenuItemEditScreenState();
}

class _MenuItemEditScreenState extends State<MenuItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _image;
  late final TextEditingController _category;
  late final TextEditingController _prepTime;
  late final TextEditingController _prepTimeRush;
  late final TextEditingController _videoUrl;
  late bool _available;
  final Set<DietaryPreference> _dietary = {};
  bool _loading = false;

  // Supplements state – loaded from item, synced live to backend on save
  late List<MenuItemSupplement> _supplements;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(
        text: item != null ? item.price.toStringAsFixed(2) : '');
    _image = TextEditingController(text: item?.image ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _prepTime = TextEditingController(
        text: item != null && item.prepTime > 0 ? '${item.prepTime}' : '');
    _prepTimeRush = TextEditingController(
        text: item != null && item.prepTimeRush > 0 ? '${item.prepTimeRush}' : '');
    _videoUrl = TextEditingController(text: item?.videoUrl ?? '');
    _available = item?.available ?? true;
    if (item != null) _dietary.addAll(item.dietaryTags);
    _supplements = List<MenuItemSupplement>.from(item?.supplements ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _image.dispose();
    _category.dispose();
    _prepTime.dispose();
    _prepTimeRush.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': double.parse(_price.text.trim()),
      'image': _image.text.trim(),
      'category': _category.text.trim(),
      'prepTime': int.tryParse(_prepTime.text.trim()) ?? 0,
      'prepTimeRush': int.tryParse(_prepTimeRush.text.trim()) ?? 0,
      'videoUrl': _videoUrl.text.trim(),
      'available': _available,
      'dietaryTags': _dietary.map((d) => d.name.toUpperCase()).toList(),
    };

    final provider = context.read<RestoProvider>();
    bool ok;
    if (_isEdit) {
      ok = await provider.updateMenuItem(widget.item!.id, body);
    } else {
      final item = await provider.addMenuItem(body);
      ok = item != null;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Erreur lors de la sauvegarde'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.fast.card,
        title: Text(tr(context, 'del_dish'),
            style: TextStyle(color: context.fast.t1)),
        content: Text(
          'Voulez-vous vraiment supprimer "${widget.item!.name}" ?',
          style: TextStyle(color: context.fast.t2),
        ),
        actions: [ TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel'),
                style: TextStyle(color: context.fast.t2)),
          ), TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'del'),
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final ok = await context.read<RestoProvider>().deleteMenuItem(widget.item!.id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context, true);
  }

  // ─── Supplement helpers ──────────────────────────────────

  void _showSupplementDialog({MenuItemSupplement? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        title: Text(
          existing == null ? 'Ajouter un supplément' : 'Modifier le supplément',
          style: TextStyle(color: context.fast.t1, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField('Nom du supplément', nameCtrl),
            const SizedBox(height: 12),
            _dialogField(tr(context, 'price_lbl'), priceCtrl,
                keyboard: TextInputType.number),
          ],
        ),
        actions: [ TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, 'cancel'),
                style: TextStyle(color: context.fast.t2)),
          ), TextButton(
            onPressed: () async {
              final n = nameCtrl.text.trim();
              final p = double.tryParse(priceCtrl.text.trim());
              if (n.isEmpty || p == null) return;
              Navigator.pop(ctx);

              final svc = MenuService();
              if (existing == null) {
                // Create mode: if item not saved yet add to local list only
                if (!_isEdit) {
                  setState(() {
                    _supplements.add(MenuItemSupplement(
                      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                      name: n,
                      price: p,
                    ));
                  });
                } else {
                  try {
                    final s = await svc.addSupplement(widget.item!.id, n, p);
                    setState(() => _supplements.add(s));
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(context, 'error_add')),
                        backgroundColor: Color(0xFFEF4444),
                      ));
                    }
                  }
                }
              } else {
                // Update
                if (!existing.id.startsWith('local_')) {
                  try {
                    final s = await svc.updateSupplement(existing.id, n, p);
                    setState(() {
                      final idx = _supplements.indexWhere((x) => x.id == existing.id);
                      if (idx != -1) _supplements[idx] = s;
                    });
                  } catch (_) {}
                } else {
                  setState(() {
                    final idx = _supplements.indexWhere((x) => x.id == existing.id);
                    if (idx != -1) {
                      _supplements[idx] = MenuItemSupplement(
                          id: existing.id, name: n, price: p);
                    }
                  });
                }
              }
            },
            child: Text(
              existing == null ? 'Ajouter' : 'Sauvegarder',
              style: const TextStyle(
                  color: Color(0xFF00C8B3), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplement(MenuItemSupplement s) async {
    if (!s.id.startsWith('local_')) {
      try {
        await MenuService().deleteSupplement(s.id);
      } catch (_) {}
    }
    setState(() => _supplements.removeWhere((x) => x.id == s.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fast.t1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Modifier le plat' : 'Nouveau plat',
          style: TextStyle(
              color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isEdit)
 IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              onPressed: _loading ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            _field(
              controller: _name,
              label: tr(context, 'dish_name_lbl'),
              icon: Icons.restaurant_menu,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
                  SizedBox(height: 16),
            _field(
              controller: _description,
              label: 'Description',
              icon: Icons.notes,
              maxLines: 3,
            ),
                  SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _price,
                    label: tr(context, 'price_lbl'),
                    icon: Icons.euro,
                    keyboard: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requis';
                      if (double.tryParse(v.trim()) == null) return 'Invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _category,
                    label: 'Catégorie',
                    icon: Icons.category_outlined,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
              ],
            ),
                  SizedBox(height: 16),
            _field(
              controller: _image,
              label: 'URL image (optionnel)',
              icon: Icons.image_outlined,
            ),
                  SizedBox(height: 16),
            _field(
              controller: _videoUrl,
              label: 'URL vidéo story (optionnel)',
              icon: Icons.play_circle_outline,
            ),
                  SizedBox(height: 16),
            // Per-dish prep times (minutes, 0/vide = délai restaurant par défaut)
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _prepTime,
                    label: 'Prép. normal (min)',
                    icon: Icons.schedule,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _prepTimeRush,
                    label: 'Prép. rush (min)',
                    icon: Icons.local_fire_department_outlined,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Ex. Kebab 8 min, Agneau 15 min normal / 25 min en rush. Vide = délai par défaut du restaurant.',
                style: TextStyle(color: context.fast.t3, fontSize: 11, height: 1.3),
              ),
            ),
                  SizedBox(height: 24),

            // Available toggle
            Container(
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.fast.line),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [ Icon(Icons.visibility_outlined,
                      color: context.fast.t3, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                    child: Text('Disponible',
                        style: TextStyle(color: context.fast.t1, fontSize: 15)),
                  ),
                  Switch(
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
                  SizedBox(height: 24),

            // Dietary tags
 Text('Labels alimentaires',
                style: TextStyle(
                    color: context.fast.t2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietaryPreference.values.map((pref) {
                final selected = _dietary.contains(pref);
                return FilterChip(
                  label: Text(pref.label,
                      style: TextStyle(
                          color: selected
                              ? FASTBrand.onAmber
                              : context.fast.t1,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _dietary.add(pref);
                    } else {
                      _dietary.remove(pref);
                    }
                  }),
                  selectedColor: Color(0xFF00C8B3),
                  backgroundColor: context.fast.line,
                  checkmarkColor: FASTBrand.onAmber,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                );
              }).toList(),
            ),
                  SizedBox(height: 24),

            // ─── Supplements ──────────────────────────────
            Row(
              children: [ Text(tr(context, 'supplements'),
                    style: TextStyle(
                        color: context.fast.t2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(), TextButton.icon(
                  onPressed: () => _showSupplementDialog(),
                  icon: const Icon(Icons.add, size: 16,
                      color: Color(0xFF00C8B3)),
                  label: Text(tr(context, 'add'),
                      style: TextStyle(
                          color: Color(0xFF00C8B3),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
                  SizedBox(height: 8),
            if (_supplements.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fast.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.fast.line),
                ),
                child:       Center(
                  child: Text(tr(context, 'no_supp'),
                      style: TextStyle(
                          color: context.fast.faint, fontSize: 13)),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: context.fast.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.fast.line),
                ),
                child: Column(
                  children: _supplements.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 0),
                          title: Text(s.name,
                              style: TextStyle(
                                  color: context.fast.t1, fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [ Text('+${s.price.toStringAsFixed(2)}€',
                                  style: const TextStyle(
                                      color: Color(0xFF00C8B3),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8), IconButton(
                                icon: Icon(Icons.edit_outlined,
                                    color: context.fast.t3, size: 18),
                                onPressed: () =>
                                    _showSupplementDialog(existing: s),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 4), IconButton(
                                icon: const Icon(Icons.close,
                                    color: Color(0xFFEF4444), size: 18),
                                onPressed: () => _deleteSupplement(s),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        if (idx < _supplements.length - 1)
                                Divider(
                              height: 1, color: context.fast.line,
                              indent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),

                  SizedBox(height: 32),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00C8B3),
                  foregroundColor: FASTBrand.onAmber,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ?       SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FASTBrand.onAmber))
                    : Text(
                        _isEdit ? 'Sauvegarder' : 'Créer le plat',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: context.fast.t1, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.fast.t3, fontSize: 13),
        filled: true,
        fillColor: context.fast.line,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00C8B3)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon, TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: context.fast.t1, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.fast.t3),
        prefixIcon: Icon(icon, color: context.fast.t3, size: 18),
        filled: true,
        fillColor: context.fast.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00C8B3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
