import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../resto_provider.dart';
import '../../theme.dart';
import '../../widgets/fast_image.dart';
import '../../l10n/tr.dart';

class RestoProfileScreen extends StatelessWidget {
        const RestoProfileScreen({super.key});

  Widget _placeholderImage(BuildContext context) => Container(
    color: context.fast.card,
    alignment: Alignment.center,
    child: Icon(Icons.restaurant, color: context.fast.t3, size: 72),
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RestoProvider>(context);
    final settings = provider.settings;

    return Scaffold(
      backgroundColor: context.fast.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: false,
            backgroundColor: context.fast.card,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  settings?.image != null && settings!.image.isNotEmpty
                      ? FastImage(settings.image, fit: BoxFit.cover, placeholder: _placeholderImage(context))
                      : _placeholderImage(context),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, context.fast.bg.withValues(alpha: 0.95)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF00C8B3).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(settings?.cuisineType.toUpperCase() ?? 'CUISINE', style: const TextStyle(color: Color(0xFF00C8B3), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                                  SizedBox(height: 12), Text(
                              settings?.name ?? tr(context, 'my_restaurant'),
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: context.fast.t1),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: context.fast.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.fast.line)),
                        child:       Row(
                          children: [ Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
                            SizedBox(width: 8), Text('4.8', style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                        SizedBox(height: 12),
                  Row(
                    children: [ Icon(Icons.location_on, color: context.fast.t2, size: 16),
                            SizedBox(width: 6), Text(
                        '${settings?.city ?? tr(context, 'city')} • ${tr(context, 'at_km').replaceAll('{n}', '2.4')}',
                        style: TextStyle(color: context.fast.t2, fontSize: 16),
                      ),
                    ],
                  ),
                        SizedBox(height: 48), Text(tr(context, 'public_preview'), style: TextStyle(color: context.fast.t1, fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: context.fast.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.fast.line)),
                    child:       Row(
                      children: [ Icon(Icons.visibility, color: Color(0xFF3B82F6), size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            tr(context, 'preview_notice'), 
                            style: TextStyle(color: context.fast.t2, height: 1.5)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
