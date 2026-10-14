import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';

/// Shorthand localization helper — resolves `key` against the language
/// selected in [FASTProvider]. Usable anywhere a BuildContext is available.
String tr(BuildContext context, String key) {
  Localizations.maybeLocaleOf(context);
  return Provider.of<FASTProvider>(context, listen: false).tr(key);
}

/// Translates a restaurant category given its id (client strip) or its
/// French display name (resto pickers). Falls back to the canonical
/// category name — never leaks a raw localization key into the UI.
String catLabel(BuildContext context, String idOrName) {
  final provider = Provider.of<FASTProvider>(context, listen: false);
  final id = FASTProvider.normalizeCategoryId(idOrName);
  final key = 'cat_$id';
  final label = provider.tr(key);
  if (label != key) return label;
  for (final c in provider.categories) {
    if (c.id == id) return c.name;
  }
  return idOrName;
}

String dietLabel(BuildContext context, DietaryPreference d) =>
    tr(context, 'diet_${d.name.toLowerCase()}');

String orderStatusLabel(BuildContext context, OrderStatus s) {
  const keys = {
    'placed': 'ost_placed',
    'preparing': 'ost_preparing',
    'readyForPickup': 'ost_ready',
    'completed': 'ost_completed',
    'cancelled': 'ost_cancelled',
  };
  return tr(context, keys[s.name] ?? 'ost_placed');
}
