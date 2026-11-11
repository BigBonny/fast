import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models.dart';
import 'menu_ai_scanner_screen.dart';
import 'menu_item_edit_screen.dart';
import '../../theme.dart';
import '../../widgets/fast_image.dart';
import '../../widgets/fast_night_surface.dart';
import '../../widgets/fast_parts.dart';
import '../../widgets/fast_ui.dart';
import '../../l10n/tr.dart';
import '../../services/menu_service.dart';

class RestoMenuScreen extends StatefulWidget {
  const RestoMenuScreen({super.key});

  @override
  State<RestoMenuScreen> createState() => _RestoMenuScreenState();
}

class _RestoMenuScreenState extends State<RestoMenuScreen> {
  String _filter = 'all';
  bool _generatingPhotos = false;

  /// "Photos IA" for the whole menu — fills every dish that still lacks
  /// a photo in one shot; the owner keeps editorial control afterwards.
  Future<void> _generateAllPhotos(BuildContext context) async {
    final prov = Provider.of<RestoProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (_generatingPhotos) return;
    final restaurantId = prov.restaurantId;
    if (restaurantId == null) {
      // Silent no-ops feel broken — say the menu hasn't loaded yet.
      messenger.showSnackBar(
        SnackBar(content: Text(tr(context, 'gen_photos_loading'))),
      );
      return;
    }
    setState(() => _generatingPhotos = true);
    try {
      // Each backend chunk lands here immediately — the menu fills
      // progressively instead of jumping all at once at the end.
      final photos = await MenuService().generateMenuPhotos(
        restaurantId,
        onBatch: prov.applyMenuPhotos,
      );
      final updated = photos.length;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updated == 0
                ? tr(context, 'gen_photos_none')
                : tr(context, 'gen_photos_done').replaceAll('{n}', '$updated'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr(context, 'gen_photos_err'))),
      );
    } finally {
      if (mounted) setState(() => _generatingPhotos = false);
    }
  }

  void _openEdit(BuildContext context, {MenuItem? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MenuItemEditScreen(item: item)),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.fast.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s24,
            FASTSpace.s16,
            FASTSpace.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'add_dish'),
                style: FASTText.title.copyWith(color: context.fast.t1),
              ),
              const SizedBox(height: FASTSpace.s12),
              _sheetOption(
                context,
                icon: Icons.document_scanner_outlined,
                title: tr(context, 'scan_menu_ai'),
                subtitle: tr(context, 'scan_menu_sub'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MenuAiScannerScreen(),
                    ),
                  );
                },
              ),
              Divider(color: context.fast.line, height: 1),
              _sheetOption(
                context,
                icon: Icons.edit_outlined,
                title: tr(context, 'manual_add'),
                subtitle: tr(context, 'create_dish_sub'),
                onTap: () {
                  Navigator.pop(context);
                  _openEdit(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final fast = context.fast;
    return FastTap(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fast.cardHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: FASTPro.teal, size: 20),
            ),
            const SizedBox(width: FASTSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FASTText.item.copyWith(color: fast.t1)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: FASTText.caption.copyWith(color: fast.t2),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fast.t3, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RestoProvider>(
      builder: (context, prov, _) {
        // GUEST staff accounts can only toggle availability (sold out).
        final isGuest = context.watch<AuthProvider>().user?.isGuest ?? false;
        final allItems = prov.menu;
        final categories = [
          'all',
          ...{for (final m in allItems) m.category},
        ];
        final filtered = _filter == 'all'
            ? allItems
            : allItems.where((m) => m.category == _filter).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: isGuest
              ? null
              : FastButton(
                  kind: FastButtonKind.ink,
                  expand: false,
                  icon: Icons.add,
                  label: tr(context, 'add'),
                  onPressed: () => _showAddOptions(context),
                ),
          body: prov.menuLoading
              ? const Center(
                  child: CircularProgressIndicator(color: FASTPro.teal),
                )
              : allItems.isEmpty
              ? _buildEmpty(context, isGuest)
              : _buildList(context, prov, categories, filtered, isGuest),
        );
      },
    );
  }

  /// Read-only preview of the menu exactly as clients see it.
  void _showClientPreview(BuildContext context, RestoProvider prov) {
    final resto = prov.settings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fast.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FASTRadius.md),
        ),
      ),
      builder: (ctx) {
        final items = prov.menu.where((m) => m.available).toList();
        final categories = {
          for (final m in items)
            m.category.isEmpty ? tr(context, 'menu') : m.category,
        }.toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (_, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  FASTSpace.s16,
                  FASTSpace.s16,
                  FASTSpace.s4,
                  FASTSpace.s4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: FASTPro.teal,
                      size: 20,
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    Expanded(
                      child: Text(
                        tr(context, 'preview_of').replaceAll(
                          '{n}',
                          resto?.name ?? tr(context, 'my_restaurant'),
                        ),
                        style: FASTText.title.copyWith(color: ctx.fast.t1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ctx.fast.t2),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(vertical: FASTSpace.s8),
                  children: [
                    for (final cat in categories) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          FASTSpace.s16,
                          FASTSpace.s24,
                          FASTSpace.s16,
                          FASTSpace.s4,
                        ),
                        child: Text(
                          cat,
                          style: FASTText.title.copyWith(color: ctx.fast.t1),
                        ),
                      ),
                      ...items
                          .where(
                            (m) =>
                                (m.category.isEmpty
                                    ? tr(context, 'menu')
                                    : m.category) ==
                                cat,
                          )
                          .map((m) => _previewRow(ctx, m)),
                    ],
                    const SizedBox(height: FASTSpace.s24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// One dish in the client preview: text first, square photo after.
  Widget _previewRow(BuildContext ctx, MenuItem m) {
    final fast = ctx.fast;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FASTSpace.s16,
        vertical: FASTSpace.s12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: fast.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.item.copyWith(color: fast.t1),
                ),
                if (m.description.isNotEmpty) ...[
                  const SizedBox(height: FASTSpace.s4),
                  Text(
                    m.description,
                    style: FASTText.body.copyWith(color: fast.t2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: FASTSpace.s8),
                Row(
                  children: [
                    FastPrice(m.price),
                    if (m.prepTime > 0) ...[
                      const SizedBox(width: FASTSpace.s12),
                      Icon(Icons.schedule, size: 14, color: fast.t3),
                      const SizedBox(width: FASTSpace.s4),
                      Text(
                        '~${m.prepTime} min',
                        style: FASTText.caption.copyWith(color: fast.t3),
                      ),
                    ],
                    if (m.videoUrl.isNotEmpty) ...[
                      const SizedBox(width: FASTSpace.s8),
                      const Icon(
                        Icons.play_circle_fill,
                        size: 16,
                        color: FASTPro.teal,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: FASTSpace.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(FASTRadius.sm),
            child: FastImage(
              m.image,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 72,
                height: 72,
                color: fast.cardHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageTitle(BuildContext context) {
    return Text(
      tr(context, 'menu'),
      style: FASTText.title.copyWith(color: context.fast.t1),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isGuest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s16,
            FASTSpace.s16,
            0,
          ),
          child: _pageTitle(context),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: FastEmpty(
                icon: Icons.restaurant_menu,
                accent: FASTPro.teal,
                title: tr(context, 'no_dishes'),
                subtitle: tr(context, 'first_dish'),
                action: isGuest
                    ? null
                    : FastButton(
                        kind: FastButtonKind.ink,
                        expand: false,
                        icon: Icons.add,
                        label: tr(context, 'add_dish'),
                        onPressed: () => _openEdit(context),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    RestoProvider prov,
    List<String> categories,
    List<MenuItem> items,
    bool isGuest,
  ) {
    // One column: a header per category (in menu order) followed by its
    // dishes. Entries are either a category name or a MenuItem.
    final groups = <String, List<MenuItem>>{};
    for (final m in items) {
      groups.putIfAbsent(m.category, () => []).add(m);
    }
    final entries = <Object>[
      for (final g in groups.entries) ...[
        _CategoryHeader(g.key, g.value.length),
        ...g.value,
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: entries.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildTop(context, prov, categories, items, isGuest);
        final entry = entries[i - 1];
        if (entry is _CategoryHeader) return _buildCategoryHeader(entry);
        final item = entry as MenuItem;
        final next = i < entries.length ? entries[i] : null;
        return _buildRow(
          context,
          prov,
          item,
          isGuest,
          divider: next is MenuItem,
        );
      },
    );
  }

  /// Title, client preview, whole-menu AI photos, category filter, count.
  Widget _buildTop(
    BuildContext context,
    RestoProvider prov,
    List<String> categories,
    List<MenuItem> items,
    bool isGuest,
  ) {
    final fast = context.fast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s16,
            FASTSpace.s16,
            FASTSpace.s12,
          ),
          child: Row(
            children: [
              _pageTitle(context),
              const SizedBox(width: FASTSpace.s12),
              // Client preview — see the menu exactly as customers do
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FastTap(
                    onTap: () => _showClientPreview(context, prov),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FASTSpace.s16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(FASTRadius.pill),
                        border: Border.all(color: fast.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: FASTPro.teal,
                          ),
                          const SizedBox(width: FASTSpace.s8),
                          Flexible(
                            child: Text(
                              tr(context, 'preview_client'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FASTText.caption.copyWith(
                                color: fast.t1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Whole-menu AI photos — a full-width action card, not a
        // squeezed second button: explains itself and can't clip.
        if (!isGuest)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FASTSpace.s16,
              FASTSpace.s4,
              FASTSpace.s16,
              FASTSpace.s12,
            ),
            child: FastTap(
              pressedScale: 0.98,
              onTap: _generatingPhotos
                  ? null
                  : () => _generateAllPhotos(context),
              child: FastNightSurface(
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: _generatingPhotos
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FastNightSurface.onNight,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              size: 22,
                              color: FASTBrand.gold,
                            ),
                    ),
                    const SizedBox(width: FASTSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'gen_all_photos'),
                            style: FASTText.item.copyWith(
                              color: FastNightSurface.onNight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(context, 'gen_photos_sub'),
                            style: FASTText.caption.copyWith(
                              color: FastNightSurface.onNightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: FASTSpace.s8),
                    const Icon(
                      Icons.chevron_right,
                      color: FastNightSurface.onNight,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Category filter tabs
        if (categories.length > 2)
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: FASTSpace.s16,
                vertical: 6,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: FASTSpace.s8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final active = cat == _filter;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s16,
                    ),
                    decoration: BoxDecoration(
                      color: active ? FASTPro.teal : fast.cardHigh,
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                      border: Border.all(
                        color: active ? FASTPro.teal : fast.line,
                      ),
                    ),
                    child: Text(
                      cat == 'all'
                          ? tr(context, 'all_lbl')
                          : cat.isEmpty
                          ? tr(context, 'uncategorized')
                          : cat,
                      style: FASTText.body.copyWith(
                        color: active ? FASTBrand.onAmber : fast.t1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Item count
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s8,
            FASTSpace.s16,
            0,
          ),
          child: Text(
            tr(context, 'dishes_count').replaceAll('{n}', '${items.length}'),
            style: FASTText.caption.copyWith(color: fast.t3),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(_CategoryHeader header) {
    final fast = context.fast;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FASTSpace.s16,
        FASTSpace.s24,
        FASTSpace.s16,
        FASTSpace.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              // F05 — an empty category means the AI couldn't classify
              // the dishes below: say so, each row carries the flag too.
              header.name.isEmpty ? tr(context, 'uncategorized') : header.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FASTText.title.copyWith(color: fast.t1),
            ),
          ),
          const SizedBox(width: FASTSpace.s8),
          Text(
            '${header.count}',
            style: FASTText.price.copyWith(
              color: fast.t3,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    RestoProvider prov,
    MenuItem item,
    bool isGuest, {
    required bool divider,
  }) {
    final fast = context.fast;
    const photo = 80.0;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FASTSpace.s16,
        FASTSpace.s12,
        FASTSpace.s16,
        FASTSpace.s4,
      ),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: fast.line)) : null,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: FASTText.item.copyWith(
                        color: item.available ? fast.t1 : fast.t3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: FASTSpace.s4),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FASTText.body.copyWith(color: fast.t2),
                      ),
                    ],
                    if (!item.available || item.category.isEmpty) ...[
                      const SizedBox(height: FASTSpace.s8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (!item.available)
                            FastTag(
                              tr(context, 'indispo'),
                              kind: FastTagKind.muted,
                            ),
                          // F05 — an empty category means the AI couldn't
                          // classify the dish: flag it so the owner knows
                          // to pick one.
                          if (item.category.isEmpty)
                            FastTag(
                              tr(context, 'uncategorized'),
                              kind: FastTagKind.accent,
                              icon: Icons.warning_amber_rounded,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: FASTSpace.s8),
                    Wrap(
                      spacing: FASTSpace.s8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FastPrice(item.price),
                        // The FAST markup is inside the client price — show
                        // the owner's base so the split stays transparent.
                        if (item.basePrice != null &&
                            item.basePrice != item.price)
                          Text(
                            '·  base ${fastPriceLabel(item.basePrice!)}',
                            style: FASTText.caption.copyWith(
                              color: fast.t3,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FASTSpace.s16),
              // Image + prep-time badge
              SizedBox(
                width: photo,
                height: photo,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FASTRadius.sm),
                      child: Opacity(
                        opacity: item.available ? 1 : 0.5,
                        child: item.image.isNotEmpty
                            ? FastImage(
                                item.image,
                                width: photo,
                                height: photo,
                                fit: BoxFit.cover,
                                placeholder: _imagePlaceholder(photo),
                              )
                            : _imagePlaceholder(photo),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 4,
                      start: 4,
                      child: GestureDetector(
                        onTap: isGuest
                            ? null
                            : () => _openEdit(context, item: item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.prepTime > 0
                                ? FASTPro.teal
                                : fast.card.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(
                              FASTRadius.pill,
                            ),
                          ),
                          child: item.prepTime > 0
                              ? Text(
                                  '~${item.prepTime}m',
                                  style: FASTText.caption.copyWith(
                                    color: FASTBrand.onAmber,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : Icon(Icons.more_time, size: 16, color: fast.t2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s4),
          // Actions — availability switch + edit + delete
          Row(
            children: [
              Semantics(
                label: item.available
                    ? tr(context, 'soldout')
                    : tr(context, 'dispo'),
                child: FastSwitch(
                  size: 24,
                  accent: FASTPro.teal,
                  value: item.available,
                  onChanged: (_) =>
                      prov.toggleMenuItemAvailability(item.id, !item.available),
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Expanded(
                child: Text(
                  tr(context, 'available'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FASTText.caption.copyWith(
                    color: item.available ? fast.t2 : fast.t3,
                  ),
                ),
              ),
              if (!isGuest) ...[
                IconButton(
                  tooltip: tr(context, 'edit_dish'),
                  icon: Icon(Icons.edit_outlined, color: fast.t2, size: 20),
                  onPressed: () => _openEdit(context, item: item),
                ),
                IconButton(
                  tooltip: tr(context, 'del'),
                  icon: Icon(Icons.delete_outline, color: fast.t2, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FASTRadius.md),
                        ),
                        title: Text(tr(context, 'del_dish_q')),
                        content: Text(
                          tr(
                            context,
                            'dish_removed',
                          ).replaceAll('{n}', item.name),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              tr(context, 'cancel'),
                              style: TextStyle(color: ctx.fast.t2),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              tr(context, 'del'),
                              style: const TextStyle(color: FASTBrand.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await prov.deleteMenuItem(item.id);
                    }
                  },
                ),
              ] else
                // Same row height with or without the owner's buttons.
                const SizedBox(height: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: context.fast.cardHigh,
      child: Icon(Icons.restaurant, color: context.fast.faint, size: 28),
    );
  }
}

/// A category title in the dish list, with the number of dishes under it.
class _CategoryHeader {
  const _CategoryHeader(this.name, this.count);

  final String name;
  final int count;
}
