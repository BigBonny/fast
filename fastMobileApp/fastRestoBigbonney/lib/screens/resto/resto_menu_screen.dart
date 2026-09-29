import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import 'menu_ai_scanner_screen.dart';
import 'menu_item_edit_screen.dart';
import '../../theme.dart';

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
      MaterialPageRoute(
          builder: (_) => MenuItemEditScreen(item: item)),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.fast.card,
      shape:       RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ Text('Ajouter un plat',
                  style: TextStyle(
                      color: context.fast.t1,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy,
                      color: Color(0xFF8B5CF6), size: 20),
                ),
                title: Text('Scanner un menu (IA)',
                    style: TextStyle(
                        color: context.fast.t1, fontWeight: FontWeight.w600)),
                subtitle: Text('Import automatique via photo',
                    style: TextStyle(
                        color: context.fast.t2, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MenuAiScannerScreen()));
                },
              ),
                    Divider(color: context.fast.line, height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFFF59E0B), size: 20),
                ),
                title: Text('Ajout manuel',
                    style: TextStyle(
                        color: context.fast.t1, fontWeight: FontWeight.w600)),
                subtitle: Text('Créer un plat de zéro',
                    style: TextStyle(
                        color: context.fast.t2, fontSize: 12)),
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
        final allItems = prov.menu;
        final categories = ['all', ...{for (final m in allItems) m.category}];
        final filtered = _filter == 'all'
            ? allItems
            : allItems.where((m) => m.category == _filter).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context),
            backgroundColor: const Color(0xFFF59E0B),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Ajouter',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: prov.menuLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFF59E0B)))
              : allItems.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, prov, categories, filtered),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [ Icon(Icons.restaurant_menu,
              color: context.fast.faint, size: 56),
                SizedBox(height: 16), Text('Aucun plat dans le menu',
              style: TextStyle(
                  color: context.fast.t2,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
                SizedBox(height: 8), Text('Ajoutez votre premier plat',
              style: TextStyle(color: context.fast.t3, fontSize: 13)),
                SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openEdit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF59E0B),
              foregroundColor: FASTBrand.onAmber,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un plat',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter tabs
        if (categories.length > 2)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) =>       SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final active = cat == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = cat),
                  child: AnimatedContainer(
                    duration:       Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ?       Color(0xFFF59E0B)
                          : context.fast.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat == 'all' ? 'Tout' : cat,
                      style: TextStyle(
                        color: active
                            ? context.fast.bg
                            : context.fast.t1,
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
            style: TextStyle(
                color: context.fast.t3, fontSize: 12),
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildCard(context, prov, items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
      BuildContext context, RestoProvider prov, MenuItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.available
              ? context.fast.line
              : context.fast.faint,
        ),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomLeft: Radius.circular(10),
            ),
            child: item.image.isNotEmpty
                ? Image.network(
                    item.image,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
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
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                context.fast.faint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Indispo',
                              style: TextStyle(
                                  color: context.fast.t3,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                        SizedBox(height: 2), Text(
                    item.category,
                    style: TextStyle(
                        color: context.fast.t3, fontSize: 12),
                  ),
                  const SizedBox(height: 4), Text(
                    '€${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Column(
            children: [
              Switch(
                value: item.available,
                onChanged: (v) =>
                    prov.toggleMenuItemAvailability(item.id, v),
                activeThumbColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ), IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFFF59E0B), size: 20),
                onPressed: () => _openEdit(context, item: item),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 4),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: context.fast.line,
      child: Icon(Icons.restaurant,
          color: context.fast.faint, size: 28),
    );
  }
}
