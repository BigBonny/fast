import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../resto_provider.dart';
import '../../services/menu_service.dart';
import '../../services/upload_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';
import '../../widgets/fast_image.dart';
import '../../widgets/fast_parts.dart';
import '../../widgets/fast_ui.dart';

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
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhoto = false;
  bool _uploadingVideo = false;
  bool _generatingPhoto = false;

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
      // The field holds the restaurateur's BASE price — the backend stores
      // the FAST-marked-up price for customers. Prefill basePrice so
      // re-saving doesn't double-apply the markup.
      text: item != null
          ? (item.basePrice ?? item.price).toStringAsFixed(2)
          : '',
    );
    _image = TextEditingController(text: item?.image ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _prepTime = TextEditingController(
      text: item != null && item.prepTime > 0 ? '${item.prepTime}' : '',
    );
    _prepTimeRush = TextEditingController(
      text: item != null && item.prepTimeRush > 0 ? '${item.prepTimeRush}' : '',
    );
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

  bool _enhancing = false;

  Future<void> _enhanceDescription() async {
    setState(() => _enhancing = true);
    try {
      final desc = await MenuService().enhanceDescription(widget.item!.id);
      if (mounted && desc.isNotEmpty) {
        setState(() => _description.text = desc);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'error_save'))));
      }
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }

  // ─── Dish media (photo + story video) ───────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await UploadService().uploadFile(file.path);
      if (mounted) setState(() => _image.text = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'error_save'))));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingVideo = true);
    try {
      final url = await UploadService().uploadFile(file.path);
      if (mounted) setState(() => _videoUrl.text = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'error_save'))));
      }
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  /// AI dish photo — cahier des charges: a realistic, approximate
  /// photo is generated whenever the owner hasn't added their own.
  /// Explicit ("Photo IA" button) and automatic on save when the
  /// field is still empty.
  Future<void> _generateAiPhoto({bool silent = false}) async {
    if (_generatingPhoto) return;
    setState(() => _generatingPhoto = true);
    try {
      final url = await MenuService().generateDishPhoto(
        name: _name.text.trim().isNotEmpty
            ? _name.text.trim()
            : (widget.item?.name ?? ''),
        description: _description.text.trim(),
        category: _category.text.trim(),
      );
      if (mounted && url.isNotEmpty) {
        setState(() => _image.text = url);
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'error_save'))));
      }
    } finally {
      if (mounted) setState(() => _generatingPhoto = false);
    }
  }

  Widget _mediaBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    const color = FASTPro.teal;
    return FastTap(
      onTap: loading ? null : onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
        decoration: BoxDecoration(
          color: context.fast.cardHigh,
          borderRadius: BorderRadius.circular(FASTRadius.pill),
          border: Border.all(color: context.fast.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: FASTSpace.s8),
            Text(
              label,
              style: FASTText.caption.copyWith(
                color: context.fast.t1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small section label above a group of fields.
  Widget _sectionLabel(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: context.fast.t3),
          const SizedBox(width: FASTSpace.s8),
        ],
        Flexible(
          child: Text(
            fastLabelCase(context, text),
            style: FASTText.label.copyWith(color: context.fast.t2),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _image,
      builder: (context, value, _) {
        final url = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(
              tr(context, 'media_photo'),
              icon: Icons.image_outlined,
            ),
            const SizedBox(height: FASTSpace.s12),
            if (url.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FASTRadius.sm),
                    child: FastImage(
                      url,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 150,
                        color: context.fast.cardHigh,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: FASTSpace.s8,
                    end: FASTSpace.s8,
                    child: FastTap(
                      onTap: () => setState(() => _image.text = ''),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.fast.cardHigh,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  border: Border.all(color: context.fast.line),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: context.fast.t3,
                  size: 28,
                ),
              ),
            const SizedBox(height: FASTSpace.s12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mediaBtn(
                  icon: Icons.photo_camera_outlined,
                  label: tr(context, 'media_take'),
                  loading: _uploadingPhoto,
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
                _mediaBtn(
                  icon: Icons.photo_library_outlined,
                  label: tr(context, 'media_gallery'),
                  loading: _uploadingPhoto,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
                _mediaBtn(
                  icon: Icons.auto_awesome,
                  label: tr(context, 'media_ai'),
                  loading: _generatingPhoto,
                  onTap: _generateAiPhoto,
                ),
              ],
            ),
            const SizedBox(height: FASTSpace.s12),
            _field(
              controller: _image,
              label: tr(context, 'image_url_optional'),
              icon: Icons.link,
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _videoUrl,
      builder: (context, value, _) {
        final url = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(
              tr(context, 'media_video_lbl'),
              icon: Icons.play_circle_outline,
            ),
            const SizedBox(height: FASTSpace.s12),
            if (url.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FASTSpace.s12,
                  vertical: FASTSpace.s12,
                ),
                margin: const EdgeInsets.only(bottom: FASTSpace.s12),
                decoration: BoxDecoration(
                  color: context.fast.cardHigh,
                  borderRadius: BorderRadius.circular(FASTRadius.sm),
                  border: Border.all(color: context.fast.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      size: 20,
                      color: FASTPro.teal,
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    Expanded(
                      child: Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.caption.copyWith(
                          color: context.fast.t2,
                        ),
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    FastTap(
                      onTap: () => setState(() => _videoUrl.text = ''),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.fast.t2,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mediaBtn(
                  icon: Icons.videocam_outlined,
                  label: tr(context, 'media_take'),
                  loading: _uploadingVideo,
                  onTap: () => _pickVideo(ImageSource.camera),
                ),
                _mediaBtn(
                  icon: Icons.video_library_outlined,
                  label: tr(context, 'media_gallery'),
                  loading: _uploadingVideo,
                  onTap: () => _pickVideo(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: FASTSpace.s12),
            _field(
              controller: _videoUrl,
              label: tr(context, 'video_url_lbl'),
              icon: Icons.link,
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // No owner photo → generate the realistic AI photo now so the
    // dish never displays without an image.
    final provider = context.read<RestoProvider>();
    if (_image.text.trim().isEmpty) {
      await _generateAiPhoto(silent: true);
    }

    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      // Backend treats this as the BASE price and applies the FAST markup.
      'basePrice': parseAmount(_price.text) ?? 0,
      'image': _image.text.trim(),
      'category': _category.text.trim(),
      'prepTime': (int.tryParse(_prepTime.text.trim()) ?? 0).clamp(0, 120),
      'prepTimeRush': (int.tryParse(_prepTimeRush.text.trim()) ?? 0).clamp(
        0,
        120,
      ),
      'videoUrl': _videoUrl.text.trim(),
      'isAvailable': _available,
      'dietaryTags': _dietary.map((d) => d.apiValue).toList(),
    };

    bool ok;
    if (_isEdit) {
      ok = await provider.updateMenuItem(widget.item!.id, body);
    } else {
      final item = await provider.addMenuItem(body);
      ok = item != null;
      if (item != null && _supplements.isNotEmpty) {
        // Create mode keeps supplements local until the dish exists —
        // persist them now that it has an id.
        final created = <MenuItemSupplement>[];
        for (final s in _supplements) {
          try {
            created.add(
              await MenuService().addSupplement(item.id, s.name, s.price),
            );
          } catch (_) {}
        }
        if (created.isNotEmpty) {
          provider.replaceMenuItem(
            item.copyWith(supplements: [...item.supplements, ...created]),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? tr(context, 'error_save')),
          backgroundColor: FASTBrand.error,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
        ),
        title: Text(
          tr(context, 'del_dish'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        content: Text(
          tr(context, 'del_dish_confirm').replaceAll('{n}', widget.item!.name),
          style: FASTText.body.copyWith(color: context.fast.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr(context, 'del'),
              style: TextStyle(color: FASTBrand.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final ok = await context.read<RestoProvider>().deleteMenuItem(
      widget.item!.id,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context, true);
  }

  // ─── Supplement helpers ──────────────────────────────────

  void _showSupplementDialog({MenuItemSupplement? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.fast.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FASTRadius.md),
        ),
        title: Text(
          existing == null ? tr(context, 'add_supp') : tr(context, 'edit_supp'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(tr(context, 'supp_name'), nameCtrl),
            const SizedBox(height: 12),
            _dialogField(
              tr(context, 'price_lbl'),
              priceCtrl,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: context.fast.t2),
            ),
          ),
          TextButton(
            onPressed: () async {
              final n = nameCtrl.text.trim();
              final p = parseAmount(priceCtrl.text);
              if (n.isEmpty || p == null || p < 0) return;
              Navigator.pop(ctx);

              final svc = MenuService();
              if (existing == null) {
                // Create mode: if item not saved yet add to local list only
                if (!_isEdit) {
                  setState(() {
                    _supplements.add(
                      MenuItemSupplement(
                        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                        name: n,
                        price: p,
                      ),
                    );
                  });
                } else {
                  try {
                    final s = await svc.addSupplement(widget.item!.id, n, p);
                    if (!mounted) return;
                    setState(() => _supplements.add(s));
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(context, 'error_add')),
                          backgroundColor: FASTBrand.error,
                        ),
                      );
                    }
                  }
                }
              } else {
                // Update
                if (!existing.id.startsWith('local_')) {
                  try {
                    final s = await svc.updateSupplement(existing.id, n, p);
                    if (!mounted) return;
                    setState(() {
                      final idx = _supplements.indexWhere(
                        (x) => x.id == existing.id,
                      );
                      if (idx != -1) _supplements[idx] = s;
                    });
                  } catch (_) {
                    if (mounted) _showSupplementError('error_save');
                  }
                } else {
                  setState(() {
                    final idx = _supplements.indexWhere(
                      (x) => x.id == existing.id,
                    );
                    if (idx != -1) {
                      _supplements[idx] = MenuItemSupplement(
                        id: existing.id,
                        name: n,
                        price: p,
                      );
                    }
                  });
                }
              }
            },
            child: Text(
              tr(context, existing == null ? 'add' : 'save'),
              style: const TextStyle(
                color: FASTPro.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Removes the supplement locally only once the server confirmed it.
  /// Before, a failed delete (offline, 403) still hid it here while it
  /// stayed visible to customers.
  Future<void> _deleteSupplement(MenuItemSupplement s) async {
    if (!s.id.startsWith('local_')) {
      try {
        await MenuService().deleteSupplement(s.id);
      } catch (_) {
        if (mounted) _showSupplementError('delete_err');
        return;
      }
    }
    if (!mounted) return;
    setState(() => _supplements.removeWhere((x) => x.id == s.id));
  }

  void _showSupplementError(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, key)),
        backgroundColor: FASTBrand.error,
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fast.t1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? tr(context, 'edit_dish') : tr(context, 'new_dish'),
          style: FASTText.title.copyWith(color: context.fast.t1),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: FASTBrand.error),
              onPressed: _loading ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(FASTSpace.s16),
          children: [
            _field(
              controller: _name,
              label: tr(context, 'dish_name_lbl'),
              icon: Icons.restaurant_menu,
              maxLength: 200,
              validator: (v) => v == null || v.trim().isEmpty
                  ? tr(context, 'required_f')
                  : null,
            ),
            SizedBox(height: 16),
            _field(
              controller: _description,
              label: tr(context, 'description'),
              icon: Icons.notes,
              maxLines: 3,
              maxLength: 2000,
            ),
            // F06 — AI proposes a description the owner reviews before
            // saving; nothing is applied automatically.
            if (_isEdit)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _enhancing ? null : _enhanceDescription,
                  icon: _enhancing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FASTPro.teal,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: FASTPro.teal,
                        ),
                  label: Text(
                    tr(context, 'ai_suggest_desc'),
                    style: FASTText.caption.copyWith(
                      color: FASTPro.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _price,
                    label: tr(context, 'price_lbl'),
                    icon: Icons.euro,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return tr(context, 'required_f');
                      }
                      final amount = parseAmount(v);
                      if (amount == null || amount <= 0) {
                        return tr(context, 'invalid_f');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _category,
                    label: tr(context, 'category_lbl'),
                    icon: Icons.category_outlined,
                    maxLength: 50,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? tr(context, 'required_f')
                        : null,
                  ),
                ),
              ],
            ),
            // F03 — live preview of the FAST final price from the base
            // price the restaurateur just typed.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _price,
              builder: (context, value, _) {
                final base = parseAmount(value.text);
                if (base == null || base <= 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: FASTSpace.s8,
                    start: FASTSpace.s4,
                  ),
                  child: Text(
                    '${tr(context, 'fast_price_hint')} '
                    '${computeFastPrice(base).toStringAsFixed(2)} €',
                    style: FASTText.caption.copyWith(color: context.fast.t2),
                  ),
                );
              },
            ),
            const SizedBox(height: FASTSpace.s24),
            _buildPhotoSection(context),
            const SizedBox(height: FASTSpace.s24),
            _buildVideoSection(context),
            const SizedBox(height: FASTSpace.s24),
            // Per-dish prep times (minutes, 0/vide = délai restaurant par défaut)
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _prepTime,
                    label: tr(context, 'prep_normal_min'),
                    icon: Icons.schedule,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _prepTimeRush,
                    label: tr(context, 'prep_rush_min'),
                    icon: Icons.local_fire_department_outlined,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: FASTSpace.s8,
                start: FASTSpace.s4,
              ),
              child: Text(
                tr(context, 'prep_example'),
                style: FASTText.caption.copyWith(color: context.fast.t3),
              ),
            ),
            SizedBox(height: 24),

            // Available toggle
            Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: context.fast.line),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: context.fast.t3,
                    size: 20,
                  ),
                  const SizedBox(width: FASTSpace.s12),
                  Expanded(
                    child: Text(
                      tr(context, 'available'),
                      style: FASTText.item.copyWith(color: context.fast.t1),
                    ),
                  ),
                  FastSwitch(
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                    accent: FASTPro.teal,
                  ),
                  const SizedBox(width: FASTSpace.s4),
                ],
              ),
            ),
            const SizedBox(height: FASTSpace.s24),

            // Dietary tags
            _sectionLabel(tr(context, 'food_labels')),
            const SizedBox(height: FASTSpace.s12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietaryPreference.values.map((pref) {
                final selected = _dietary.contains(pref);
                return Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final v = !selected;
                      setState(() {
                        if (v) {
                          _dietary.add(pref);
                        } else {
                          _dietary.remove(pref);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FASTSpace.s16,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? FASTPro.teal : context.fast.cardHigh,
                        borderRadius: BorderRadius.circular(FASTRadius.pill),
                        border: Border.all(
                          color: selected ? FASTPro.teal : context.fast.line,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: FASTBrand.onAmber,
                            ),
                            const SizedBox(width: FASTSpace.s4),
                          ],
                          Text(
                            pref.label,
                            style: FASTText.body.copyWith(
                              color: selected
                                  ? FASTBrand.onAmber
                                  : context.fast.t1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // ─── Supplements ──────────────────────────────
            Row(
              children: [
                Expanded(child: _sectionLabel(tr(context, 'supplements'))),
                TextButton.icon(
                  onPressed: () => _showSupplementDialog(),
                  icon: const Icon(Icons.add, size: 18, color: FASTPro.teal),
                  label: Text(
                    tr(context, 'add'),
                    style: FASTText.body.copyWith(
                      color: FASTPro.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FASTSpace.s4),
            if (_supplements.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: FASTSpace.s16),
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: context.fast.line),
                  ),
                ),
                child: Text(
                  tr(context, 'no_supp'),
                  style: FASTText.body.copyWith(color: context.fast.t3),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: context.fast.line),
                  ),
                ),
                child: Column(
                  children: _supplements.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: FASTSpace.s4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: FASTText.body.copyWith(
                                    color: context.fast.t1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: FASTSpace.s12),
                              Text(
                                '+${fastPriceLabel(s.price)}',
                                style: FASTText.price.copyWith(
                                  color: context.fast.t1,
                                ),
                              ),
                              const SizedBox(width: FASTSpace.s4),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: context.fast.t2,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showSupplementDialog(existing: s),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: FASTBrand.error,
                                  size: 20,
                                ),
                                onPressed: () => _deleteSupplement(s),
                              ),
                            ],
                          ),
                        ),
                        if (idx < _supplements.length - 1)
                          Divider(height: 1, color: context.fast.line),
                      ],
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: FASTSpace.s40),

            FastButton(
              kind: FastButtonKind.ink,
              label: _isEdit ? tr(context, 'save') : tr(context, 'create_dish'),
              loading: _loading,
              onPressed: _loading ? null : _save,
            ),
            if (_isEdit) ...[
              const SizedBox(height: FASTSpace.s12),
              // Same action as the bin in the app bar, same confirmation.
              Opacity(
                opacity: _loading ? 0.55 : 1,
                child: FastTap(
                  onTap: _loading ? null : _delete,
                  pressedScale: 0.97,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                      border: Border.all(color: FASTBrand.error),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: FASTBrand.error,
                        ),
                        const SizedBox(width: FASTSpace.s8),
                        Flexible(
                          child: Text(
                            tr(context, 'del_dish'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FASTBrand.error,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: FASTSpace.s40),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      cursorColor: FASTPro.teal,
      style: FASTText.body.copyWith(color: context.fast.t1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.fast.t3, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: FASTPro.teal),
        filled: true,
        fillColor: context.fast.cardHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: context.fast.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: context.fast.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: const BorderSide(color: FASTPro.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FASTSpace.s16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      cursorColor: FASTPro.teal,
      style: TextStyle(color: context.fast.t1, fontSize: 15, height: 1.35),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.fast.t3, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: FASTPro.teal),
        prefixIcon: Icon(icon, color: context.fast.t3, size: 18),
        filled: true,
        fillColor: context.fast.cardHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: context.fast.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: context.fast.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: const BorderSide(color: FASTPro.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: const BorderSide(color: FASTBrand.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: const BorderSide(color: FASTBrand.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
