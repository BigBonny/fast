import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../models.dart';
import '../../theme.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  @override
  void initState() {
    super.initState();
    // Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore default orientations (all orientations supported by the app)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000), // Pure black for high contrast
      appBar: AppBar(
        backgroundColor: context.fast.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.fast.t1, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🍳 Écran Cuisine',
          style: TextStyle(fontWeight: FontWeight.w900, color: context.fast.t1, fontSize: 24),
        ),
        centerTitle: false,
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 24.0),
              child: StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.fast.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.fast.line),
                    ),
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 2.0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Consumer<RestoProvider>(
        builder: (context, rProv, child) {
          final activeOrders = rProv.restoOrders.where((o) => o.status == OrderStatus.preparing).toList();
          
          if (activeOrders.isEmpty) {
            return       Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Icon(Icons.restaurant_menu, size: 64, color: context.fast.faint),
                  SizedBox(height: 16), Text(
                    'Aucune commande en préparation...',
                    style: TextStyle(color: context.fast.t2, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate:       SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              return Container(
                decoration: BoxDecoration(
                  color: context.fast.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '#${order.id.split('-').last}',
                              style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.isUrgent) ...[
                                  SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                              child: Text('URGENT', style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: order.items.length,
                        itemBuilder: (context, i) {
                          final item = order.items[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [ Text('${item.quantity}x', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 18)),
                                      SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [ Text(item.menuItem.name, style: TextStyle(color: context.fast.t1, fontSize: 16, fontWeight: FontWeight.w600)),
                                      if (item.selectedOptions.isNotEmpty)
 Text(item.selectedOptions.join(', '), style: TextStyle(color: context.fast.t2, fontSize: 14)),
                                      if (item.allergyNotes.isNotEmpty)
 Text('Note: ${item.allergyNotes}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 48,
        color: context.fast.card,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Text(
          'TICKER: Aucun résumé actif.',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
