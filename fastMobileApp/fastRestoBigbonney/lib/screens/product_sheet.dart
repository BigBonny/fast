// lib/screens/product_sheet.dart
//
// The sheet a customer sees after tapping a dish: photo, name, free
// options, paid supplements, a notes field, and a pinned bar with the
// quantity stepper and the add-to-cart button.
//
// What is sent to the cart is unchanged from the previous dialog:
// `provider.addToCart(item, qty, [...free option labels, ...supplement
// ids], notes)`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../provider.dart';
import '../theme.dart';
import '../widgets/fast_image.dart';
import '../widgets/fast_parts.dart';
import '../widgets/fast_ui.dart';

Future<void> showProductSheet(
  BuildContext context,
  FASTProvider provider,
  MenuItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.fast.card,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FASTRadius.md)),
    ),
    builder: (_) => ProductSheet(provider: provider, item: item),
  );
}

class ProductSheet extends StatefulWidget {
  const ProductSheet({super.key, required this.provider, required this.item});

  final FASTProvider provider;
  final MenuItem item;

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  final _notes = TextEditingController();
  final List<String> _selectedFree = [];
  final List<String> _selectedPaid = [];
  int _qty = 1;

  FASTProvider get _p => widget.provider;
  MenuItem get _item => widget.item;

  /// Free options — no extra charge. The same six the app has always
  /// offered on every dish.
  late final List<String> _freeOptions = [
    _p.tr('opt_no_onions'),
    _p.tr('opt_no_cheese'),
    _p.tr('opt_gluten'),
    _p.tr('opt_spicy'),
    _p.tr('opt_well'),
    _p.tr('opt_rare'),
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  double get _extrasTotal {
    var sum = 0.0;
    for (final id in _selectedPaid) {
      for (final s in _item.supplements) {
        if (s.id == id) {
          sum += s.price;
          break;
        }
      }
    }
    return sum;
  }

  double get _total => (_item.price + _extrasTotal) * _qty;

  void _toggle(List<String> list, String value) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!list.remove(value)) list.add(value);
    });
  }

  void _add() {
    HapticFeedback.lightImpact();
    _p.addToCart(_item, _qty, [
      ..._selectedFree,
      ..._selectedPaid,
    ], _notes.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final media = MediaQuery.of(context);
    final hasPhoto = _item.image.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasPhoto) _photo(context) else _handle(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FASTSpace.s16,
                      FASTSpace.s16,
                      FASTSpace.s16,
                      FASTSpace.s24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.name,
                          style: FASTText.title.copyWith(color: fast.t1),
                        ),
                        if (_item.description.isNotEmpty) ...[
                          const SizedBox(height: FASTSpace.s8),
                          Text(
                            _item.description,
                            style: FASTText.body.copyWith(color: fast.t2),
                          ),
                        ],
                        const SizedBox(height: FASTSpace.s8),
                        FastPrice(_item.price),
                        const SizedBox(height: FASTSpace.s24),
                        _groupLabel(context, _p.tr('options')),
                        for (final o in _freeOptions)
                          _OptionRow(
                            label: o,
                            selected: _selectedFree.contains(o),
                            onTap: () => _toggle(_selectedFree, o),
                          ),
                        if (_item.supplements.isNotEmpty) ...[
                          const SizedBox(height: FASTSpace.s24),
                          _groupLabel(context, _p.tr('extras')),
                          for (final s in _item.supplements)
                            _OptionRow(
                              label: s.name,
                              trailing: '+${fastPriceLabel(s.price)}',
                              selected: _selectedPaid.contains(s.id),
                              onTap: () => _toggle(_selectedPaid, s.id),
                            ),
                        ],
                        const SizedBox(height: FASTSpace.s24),
                        _groupLabel(context, _p.tr('notes_label')),
                        const SizedBox(height: FASTSpace.s8),
                        TextField(
                          controller: _notes,
                          maxLines: 3,
                          minLines: 2,
                          style: FASTText.body.copyWith(color: fast.t1),
                          decoration: InputDecoration(
                            hintText: _p.tr('allergy_hint'),
                            hintStyle: FASTText.body.copyWith(color: fast.t3),
                            filled: true,
                            fillColor: fast.cardHigh,
                            contentPadding: const EdgeInsets.all(FASTSpace.s12),
                            border: _fieldBorder(fast.line),
                            enabledBorder: _fieldBorder(fast.line),
                            focusedBorder: _fieldBorder(fast.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pinned bar: stepper and the add button with the running total.
          Container(
            decoration: BoxDecoration(
              color: fast.card,
              border: Border(top: BorderSide(color: fast.line)),
            ),
            padding: EdgeInsets.fromLTRB(
              FASTSpace.s16,
              FASTSpace.s12,
              FASTSpace.s16,
              FASTSpace.s12 + media.viewInsets.bottom + media.padding.bottom,
            ),
            child: Row(
              children: [
                FastStepper(
                  value: _qty,
                  onChanged: (v) => setState(() => _qty = v),
                ),
                const SizedBox(width: FASTSpace.s16),
                Expanded(
                  child: FastButton(
                    kind: FastButtonKind.ink,
                    label: _p
                        .tr('add_cart_price')
                        .replaceAll('{n}', _total.toStringAsFixed(2)),
                    onPressed: _add,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(FASTRadius.sm),
    borderSide: BorderSide(color: color),
  );

  Widget _groupLabel(BuildContext context, String text) => Text(
    fastLabelCase(context, text),
    style: FASTText.label.copyWith(color: context.fast.t2),
  );

  Widget _handle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: FASTSpace.s12),
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.fast.faint,
          borderRadius: BorderRadius.circular(FASTRadius.pill),
        ),
      ),
    ),
  );

  Widget _photo(BuildContext context) {
    final fast = context.fast;
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: FastImage(
            _item.image,
            fit: BoxFit.cover,
            cacheWidth: 900,
            placeholder: Container(
              color: fast.cardHigh,
              alignment: Alignment.center,
              child: Icon(Icons.restaurant, size: 40, color: fast.faint),
            ),
          ),
        ),
        PositionedDirectional(
          top: FASTSpace.s12,
          start: FASTSpace.s12,
          child: FastTap(
            onTap: () => Navigator.of(context).pop(),
            child: Semantics(
              button: true,
              label: MaterialLocalizations.of(context).closeButtonLabel,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fast.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 20, color: fast.onInk),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One selectable line in the sheet: label, optional extra price, and a
/// check mark that fills with ink when selected.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Semantics(
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: fast.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
                  child: Text(
                    label,
                    style: FASTText.body.copyWith(
                      color: fast.t1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: FASTSpace.s12),
                Text(
                  trailing!,
                  style: FASTText.price.copyWith(fontSize: 14, color: fast.t2),
                ),
              ],
              const SizedBox(width: FASTSpace.s12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? fast.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? fast.ink : fast.faint,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: fast.onInk)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
