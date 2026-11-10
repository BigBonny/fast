import 'dart:async';
import 'package:flutter/material.dart';
import '../services/assistant_service.dart';
import '../theme.dart';

/// Address text field with live place suggestions (French BAN API via
/// the backend). Picks fill the controller and hand back lat/lng + city.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final void Function(PlaceSuggestion suggestion)? onSelected;
  final void Function(String value)? onChanged;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.label,
    this.onSelected,
    this.onChanged,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (value.trim().length < 3) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      if (mounted) setState(() => _loading = true);
      try {
        final results = await AssistantService.instance.searchPlaces(value);
        if (mounted) setState(() => _suggestions = results);
      } catch (_) {
        // Autocomplete is a convenience — typing still works without it.
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(FASTRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          cursorColor: fast.ink,
          style: FASTText.body.copyWith(color: fast.t1),
          decoration: InputDecoration(
            labelText: widget.label,
            floatingLabelStyle: FASTText.body.copyWith(color: fast.t2),
            filled: true,
            fillColor: fast.cardHigh,
            border: border(fast.line),
            enabledBorder: border(fast.line),
            focusedBorder: border(fast.ink, 1.5),
            suffixIcon: _loading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fast.t2,
                      ),
                    ),
                  )
                : Icon(Icons.location_on_outlined, size: 20, color: fast.t2),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: FASTSpace.s4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: fast.card,
              borderRadius: BorderRadius.circular(FASTRadius.sm),
              border: Border.all(color: fast.line),
              boxShadow: FASTShadow.card(context),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: Material(
              type: MaterialType.transparency,
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, thickness: 1, color: fast.line),
                itemBuilder: (context, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    shape: const RoundedRectangleBorder(),
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: FASTSpace.s12,
                      end: FASTSpace.s12,
                    ),
                    horizontalTitleGap: FASTSpace.s12,
                    minLeadingWidth: 20,
                    leading: Icon(
                      Icons.place_outlined,
                      size: 20,
                      color: fast.t2,
                    ),
                    title: Text(
                      s.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FASTText.body.copyWith(color: fast.t1),
                    ),
                    onTap: () {
                      widget.controller.text = s.label;
                      setState(() => _suggestions = []);
                      widget.onChanged?.call(s.label);
                      widget.onSelected?.call(s);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
