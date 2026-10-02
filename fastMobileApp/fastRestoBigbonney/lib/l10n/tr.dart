import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../provider.dart';

/// Shorthand localization helper — resolves `key` against the language
/// selected in [FASTProvider]. Usable anywhere a BuildContext is available.
String tr(BuildContext context, String key) =>
    Provider.of<FASTProvider>(context).tr(key);
