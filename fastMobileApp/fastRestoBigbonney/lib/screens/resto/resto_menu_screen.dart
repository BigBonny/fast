import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models.dart';
import 'menu_ai_scanner_screen.dart';
import 'menu_item_edit_screen.dart';
import '../../theme.dart';
import '../../widgets/fast_image.dart';
import '../../l10n/tr.dart';

class RestoMenuScreen extends StatefulWidget {
  const RestoMenuScreen({super.key});

  @override
  State<RestoMenuScreen> createState() => _RestoMenuScreenState();
}

class _RestoMenuScreenState extends State<RestoMenuScreen> {
  String _filter = 'all';

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'add_dish'),
                style: TextStyle(
                  color: context.fast.t1,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                title: Text(
                  tr(context, 'scan_menu_ai'),
                  style: TextStyle(
                    color: context.fast.t1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  tr(context, 'scan_menu_sub'),
                  style: TextStyle(color: context.fast.t2, fontSize: 12),
                ),
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
              Divider(color: context.fast.line, height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8B3).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF00C8B3),
                    size: 20,
                  ),
                ),
                title: Text(
                  tr(context, 'manual_add'),
                  style: TextStyle(
                    color: context.fast.t1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  tr(context, 'create_dish_sub'),
                  style: TextStyle(color: context.fast.t2, fontSize: 12),
                ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<RestoProvider>(
      builder: (context, prov, _) {
        // GUEST staff accounts can only toggle availability (sold out).
        final isGuest = context.watch<AuthProvider>().user?.role == 'GUEST';
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
              : FloatingActionButton.extended(
                  onPressed: () => _showAddOptions(context),
                  backgroundColor: const Color(0xFF00C8B3),
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: Text(
                    tr(context, 'add'),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          body: prov.menuLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C8B3)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF00C8B3),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(context, 'preview_of').replaceAll(
                          '{n}',
                          resto?.name ?? tr(context, 'my_restaurant'),
                        ),
                        style: TextStyle(
                          color: ctx.fast.t1,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    for (final cat in categories) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          cat.toUpperCase(),
                          style: TextStyle(
                            color: ctx.fast.t3,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
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
                          .map(
                            (m) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ctx.fast.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ctx.fast.line),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: FastImage(
                                      m.image,
                                      width: 56,
                                      height: 56,
                                      placeholder: Container(
                                        width: 56,
                                        height: 56,
                                        color: ctx.fast.cardHigh,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: TextStyle(
                                            color: ctx.fast.t1,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (m.description.isNotEmpty)
                                          Text(
                                            m.description,
                                            style: TextStyle(
                                              color: ctx.fast.t3,
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${m.price.toStringAsFixed(2)} €',
                                              style: const TextStyle(
                                                color: Color(0xFF00C8B3),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (m.prepTime > 0) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.schedule,
                                                size: 11,
                                                color: ctx.fast.t3,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '~${m.prepTime} min',
                                                style: TextStyle(
                                                  color: ctx.fast.t3,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                            if (m.videoUrl.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.play_circle_fill,
                                                size: 14,
                                                color: Color(0xFF00C8B3),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool isGuest) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, color: context.fast.faint, size: 56),
          SizedBox(height: 16),
          Text(
            tr(context, 'no_dishes'),
            style: TextStyle(
              color: context.fast.t2,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            tr(context, 'first_dish'),
            style: TextStyle(color: context.fast.t3, fontSize: 13),
          ),
          SizedBox(height: 24),
          if (!isGuest)
            ElevatedButton.icon(
              onPressed: () => _openEdit(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00C8B3),
                foregroundColor: FASTBrand.onAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add),
              label: Text(
                tr(context, 'add_dish'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    RestoProvider prov,
    List<String> categories,
    List<MenuItem> items,
    bool isGuest,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Client preview — see the menu exactly as customers do
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: OutlinedButton.icon(
            onPressed: () => _showClientPreview(context, prov),
            icon: const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Color(0xFF00C8B3),
            ),
            label: Text(
              tr(context, 'preview_client'),
              style: TextStyle(
                color: Color(0xFF00C8B3),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00C8B3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        // Category filter tabs
        if (categories.length > 2)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final active = cat == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = cat),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? Color(0xFF00C8B3) : context.fast.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat == 'all' ? tr(context, 'all_lbl') : cat,
                      style: TextStyle(
                        color: active ? context.fast.bg : context.fast.t1,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Item count
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${items.length} plat${items.length == 1 ? '' : 's'}',
            style: TextStyle(color: context.fast.t3, fontSize: 12),
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildCard(context, prov, items[i], isGuest),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    RestoProvider prov,
    MenuItem item,
    bool isGuest,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.available ? context.fast.line : context.fast.faint,
        ),
      ),
      child: Row(
        children: [
          // Image + prep-time badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
                child: item.image.isNotEmpty
                    ? FastImage(
                        item.image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: GestureDetector(
                  onTap: isGuest ? null : () => _openEdit(context, item: item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.prepTime > 0
                          ? const Color(0xFF00C8B3)
                          : context.fast.cardHigh.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.prepTime > 0 ? '~${item.prepTime}m' : '+⏱',
                      style: TextStyle(
                        color: item.prepTime > 0
                            ? Colors.black
                            : context.fast.t3,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Info
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: item.available
                                ? context.fast.t1
                                : context.fast.t3,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.available)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.fast.faint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tr(context, 'indispo'),
                            style: TextStyle(
                              color: context.fast.t3,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    item.category,
                    style: TextStyle(color: context.fast.t3, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00C8B3),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions — Base44 style: Épuiser (red) / Dispo (green) + edit + delete
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () =>
                      prov.toggleMenuItemAvailability(item.id, !item.available),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: item.available
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF34D399),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.available
                          ? tr(context, 'soldout')
                          : tr(context, 'dispo'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!isGuest)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF00C8B3),
                          size: 19,
                        ),
                        onPressed: () => _openEdit(context, item: item),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFF94A3B8),
                          size: 19,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
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
                                  child: Text(tr(context, 'cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    tr(context, 'del'),
                                    style: TextStyle(color: Color(0xFFEF4444)),
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
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: context.fast.line,
      child: Icon(Icons.restaurant, color: context.fast.faint, size: 28),
    );
  }
}
