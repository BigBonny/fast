import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../models.dart';

/// Shorthand localization helper — resolves `key` against the language
/// selected in [FASTProvider]. Usable anywhere a BuildContext is available.
String tr(BuildContext context, String key) =>
    Provider.of<FASTProvider>(context).tr(key);

const _catKeys = <String, String>{
  'burgers': 'cat_burgers',
  'Burgers': 'cat_burgers',
  'tacos': 'cat_tacos',
  'Tacos': 'cat_tacos',
  'kebab': 'cat_kebab',
  'Kebab': 'cat_kebab',
  'pizza': 'cat_pizza',
  'Pizza': 'cat_pizza',
  'poulet': 'cat_poulet',
  'Poulet': 'cat_poulet',
  'sandwichs': 'cat_sandwichs',
  'Sandwichs': 'cat_sandwichs',
  'fast-food': 'cat_fastfood',
  'Fast-food': 'cat_fastfood',
  'hot-dogs': 'cat_hotdogs',
  'Hot-dogs': 'cat_hotdogs',
  'sushi': 'cat_sushi',
  'Sushi': 'cat_sushi',
  'poke': 'cat_poke',
  'Poke': 'cat_poke',
  'chinois': 'cat_chinois',
  'Chinois': 'cat_chinois',
  'vietnamien': 'cat_vietnamien',
  'Vietnamien': 'cat_vietnamien',
  'indien': 'cat_indien',
  'Indien': 'cat_indien',
  'thailandais': 'cat_thai',
  'Thaïlandais': 'cat_thai',
  'coreen': 'cat_coreen',
  'Coréen': 'cat_coreen',
  'mexicain': 'cat_mexicain',
  'Mexicain': 'cat_mexicain',
  'italien': 'cat_italien',
  'Italien': 'cat_italien',
  'grec': 'cat_grec',
  'Grec': 'cat_grec',
  'monde': 'cat_monde',
  'Cuisine du monde': 'cat_monde',
  'grillades': 'cat_grillades',
  'Grillades & Viandes': 'cat_grillades',
  'poisson': 'cat_poisson',
  'Poisson & Fruits de mer': 'cat_poisson',
  'vegan': 'cat_vegan',
  'Vegan & Végétarien': 'cat_vegan',
  'halal': 'cat_halal',
  'Halal': 'cat_halal',
  'boulangerie': 'cat_boulangerie',
  'Boulangerie': 'cat_boulangerie',
  'sandwicherie': 'cat_sandwicherie',
  'Sandwicherie': 'cat_sandwicherie',
  'crepes': 'cat_crepes',
  'Crêpes & Gaufres': 'cat_crepes',
  'dessert': 'cat_desserts',
  'Desserts': 'cat_desserts',
  'glaces': 'cat_glaces',
  'Glaces': 'cat_glaces',
  'bubble-tea': 'cat_bubble',
  'Bubble Tea': 'cat_bubble',
  'cafe': 'cat_cafe',
  'Café': 'cat_cafe',
  'brasserie': 'cat_brasserie',
  'Brasserie': 'cat_brasserie',
  'traditionnel': 'cat_trad',
  'Traditionnel': 'cat_trad',
  'Restaurant traditionnel': 'cat_trad',
  'gastronomique': 'cat_gastro',
  'Gastronomique': 'cat_gastro',
  'Restaurant gastronomique': 'cat_gastro',
  'buffet': 'cat_buffet',
  'Buffet': 'cat_buffet',
  'mediterraneen': 'cat_med',
  'Méditerranéen': 'cat_med',
  'Cuisine méditerranéenne': 'cat_med',
  'africain': 'cat_africaine',
  'Africain': 'cat_africaine',
  'Cuisine africaine': 'cat_africaine',
  'antillais': 'cat_antillais',
  'Antillais & Créole': 'cat_antillais',
  'Cuisine antillaise & créole': 'cat_antillais',
  'autre': 'cat_autres',
  'Autres': 'cat_autres',
};

/// Translates a restaurant category given its id (client strip) or its
/// French display name (resto pickers). Unknown values pass through.
String catLabel(BuildContext context, String idOrName) {
  final k = _catKeys[idOrName];
  return k == null ? idOrName : tr(context, k);
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
