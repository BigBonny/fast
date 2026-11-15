import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart' show foldText;
import '../theme.dart';

/// Returns the entries of [options] matching [query], ignoring case and
/// accents: names starting with the query first, then names containing it.
List<String> suggestMatches(
  Iterable<String> options,
  String query, {
  int limit = 8,
}) {
  final q = foldText(query);
  final seen = <String>{};
  final starts = <String>[];
  final contains = <String>[];
  for (final o in options) {
    final f = foldText(o);
    if (f.isEmpty || !seen.add(f)) continue;
    if (q.isEmpty || f.startsWith(q)) {
      starts.add(o);
    } else if (f.contains(q)) {
      contains.add(o);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// The entry of [options] that equals [value] once case and accents are
/// ignored, or null. Lets "boissons" reuse the existing "Boissons".
String? existingOption(Iterable<String> options, String value) {
  final v = foldText(value);
  if (v.isEmpty) return null;
  for (final o in options) {
    if (foldText(o) == v) return o;
  }
  return null;
}

/// Text field that searches a list while typing: matching entries appear
/// as chips under it (one tap fills the field), and when nothing matches
/// a "create" chip offers to add what was typed. The suggestions sit in
/// the layout, not in an overlay, so the field works inside scroll views.
class SuggestField extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.options,
    required this.decoration,
    this.onSelected,
    this.onCreate,
    this.createLabel,
    this.style,
    this.accent,
    this.validator,
    this.maxLength,
    this.clearOnPick = false,
    this.showOnEmpty = true,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final List<String> options;
  final InputDecoration decoration;

  /// An existing entry was tapped.
  final ValueChanged<String>? onSelected;

  /// The "create" chip was tapped; null hides it.
  final ValueChanged<String>? onCreate;

  /// Label of the create chip for the typed text.
  final String Function(String typed)? createLabel;
  final TextStyle? style;
  final Color? accent;
  final String? Function(String?)? validator;
  final int? maxLength;

  /// Empties the field after a pick (multi-select pickers).
  final bool clearOnPick;

  /// Shows the first entries as soon as the field has focus.
  final bool showOnEmpty;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  // Hidden right after a pick, until the text changes again.
  bool _dismissed = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final text = widget.controller.text;
    setState(() {
      if (text != _lastText) {
        _lastText = text;
        _dismissed = false;
      }
    });
  }

  void _pick(String value, {required bool created}) {
    HapticFeedback.selectionClick();
    final c = widget.controller;
    if (widget.clearOnPick) {
      c.clear();
      _lastText = '';
    } else {
      c.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _lastText = value;
    }
    setState(() => _dismissed = true);
    if (created) {
      widget.onCreate?.call(value);
    } else {
      widget.onSelected?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final accent = widget.accent ?? fast.ink;
    final typed = widget.controller.text.trim();
    final active = _focus.hasFocus && !_dismissed;
    final matches = active && (typed.isNotEmpty || widget.showOnEmpty)
        ? suggestMatches(widget.options, typed)
        : const <String>[];
    final exact = existingOption(widget.options, typed);
    final canCreate =
        active && widget.onCreate != null && typed.length >= 2 && exact == null;
    // Nothing to offer when the only match is exactly what is typed.
    final chips = matches.where((m) => m != typed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          validator: widget.validator,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.maxLength != null
              ? [LengthLimitingTextInputFormatter(widget.maxLength)]
              : null,
          cursorColor: accent,
          style: widget.style ?? FASTText.body.copyWith(color: fast.t1),
          decoration: widget.decoration,
        ),
        if (chips.isNotEmpty || canCreate)
          Padding(
            padding: const EdgeInsets.only(top: FASTSpace.s8),
            child: Wrap(
              spacing: FASTSpace.s8,
              runSpacing: FASTSpace.s8,
              children: [
                for (final m in chips)
                  ActionChip(
                    label: Text(m),
                    labelStyle: FASTText.caption.copyWith(
                      color: fast.t1,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: fast.card,
                    side: BorderSide(color: fast.line),
                    shape: const StadiumBorder(),
                    onPressed: () => _pick(m, created: false),
                  ),
                if (canCreate)
                  ActionChip(
                    avatar: Icon(Icons.add, size: 16, color: accent),
                    label: Text(widget.createLabel?.call(typed) ?? typed),
                    labelStyle: FASTText.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: accent.withValues(alpha: 0.10),
                    side: BorderSide(color: accent),
                    shape: const StadiumBorder(),
                    onPressed: () => _pick(typed, created: true),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
