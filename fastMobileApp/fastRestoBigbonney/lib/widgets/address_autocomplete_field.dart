import 'dart:async';
import 'package:flutter/material.dart';
import '../services/assistant_service.dart';
import '../theme.dart';

/// Address text field with live place suggestions (Nominatim via the
/// backend). Picks fill the controller and hand back lat/lng + city.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.location_on_outlined, size: 18),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: context.fast.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.fast.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.fast.line),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: context.fast.t3,
                  ),
                  title: Text(
                    s.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.fast.t1),
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
      ],
    );
  }
}
