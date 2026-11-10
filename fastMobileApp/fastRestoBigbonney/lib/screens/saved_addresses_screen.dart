import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_exceptions.dart';
import '../provider.dart';
import '../l10n/tr.dart';
import '../theme.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/fast_ui.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(ApiConfig.addresses) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _addresses = data.cast<Map<String, dynamic>>();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : tr(context, 'err_retry');
        _loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final label = TextEditingController(
      text: address?['label'] as String? ?? '',
    );
    final street = TextEditingController(
      text: address?['address'] as String? ?? '',
    );
    final city = TextEditingController(text: address?['city'] as String? ?? '');
    final form = GlobalKey<FormState>();
    bool saving = false;
    bool isDefault = address?['isDefault'] == true;
    bool? saved;
    try {
      saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              FASTSpace.s16,
              FASTSpace.s24,
              FASTSpace.s16,
              MediaQuery.viewInsetsOf(ctx).bottom + FASTSpace.s16,
            ),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(ctx, address == null ? 'address_add' : 'edit'),
                    style: FASTText.title.copyWith(color: ctx.fast.t1),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: tr(ctx, 'address_label'),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? tr(ctx, 'required_f')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AddressAutocompleteField(
                    controller: street,
                    label: tr(ctx, 'full_address'),
                    onSelected: (s) {
                      if (city.text.trim().isEmpty) city.text = s.city;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: city,
                    decoration: InputDecoration(labelText: tr(ctx, 'city')),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr(ctx, 'address_default'),
                      style: FASTText.body.copyWith(color: ctx.fast.t1),
                    ),
                    value: isDefault,
                    onChanged: saving
                        ? null
                        : (value) => setSheet(() => isDefault = value ?? false),
                  ),
                  const SizedBox(height: FASTSpace.s8),
                  FastButton(
                    kind: FastButtonKind.ink,
                    label: tr(ctx, saving ? 'saving' : 'save'),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            setSheet(() => saving = true);
                            final body = {
                              'label': label.text.trim(),
                              'address': street.text.trim(),
                              'city': city.text.trim(),
                              'isDefault': isDefault,
                            };
                            try {
                              if (address == null) {
                                await _api.post(
                                  ApiConfig.addresses,
                                  body: body,
                                );
                              } else {
                                await _api.patch(
                                  ApiConfig.savedAddress(
                                    address['id'] as String,
                                  ),
                                  body: body,
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setSheet(() => saving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e is ApiException
                                        ? e.message
                                        : tr(ctx, 'err_retry'),
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      label.dispose();
      street.dispose();
      city.dispose();
    }
    if (saved == true && mounted) await _load();
  }

  Future<void> _remove(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(ctx, 'del'),
          style: FASTText.item.copyWith(color: ctx.fast.t1),
        ),
        content: Text(
          address['label'] as String,
          style: FASTText.body.copyWith(color: ctx.fast.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: ctx.fast.t2),
            child: Text(tr(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FASTBrand.error),
            child: Text(tr(ctx, 'del')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete(ApiConfig.savedAddress(address['id'] as String));
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is ApiException ? e.message : tr(context, 'err_retry'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: FASTText.body.copyWith(color: FASTBrand.error),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _load,
                      style: TextButton.styleFrom(
                        foregroundColor: context.fast.t1,
                      ),
                      child: Text(tr(context, 'retry')),
                    ),
                  ),
                ] else if (_addresses.isEmpty)
                  FastEmpty(
                    icon: Icons.location_on_outlined,
                    title: tr(context, 'no_addresses'),
                  ),
                for (final address in _addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FASTSpace.s12),
                    child: Material(
                      color: context.fast.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FASTRadius.md),
                        side: BorderSide(color: context.fast.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          context.read<FASTProvider>().setDeliveryAddress(
                            '${address['address']}, ${address['city']}',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr(context, 'save'))),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            FASTSpace.s16,
                            FASTSpace.s16,
                            FASTSpace.s4,
                            FASTSpace.s16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                address['isDefault'] == true
                                    ? Icons.home_outlined
                                    : Icons.location_on_outlined,
                                color: context.fast.t2,
                                size: 22,
                              ),
                              const SizedBox(width: FASTSpace.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      address['label'] as String,
                                      style: FASTText.item.copyWith(
                                        color: context.fast.t1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${address['address']}\n${address['city']}',
                                      style: FASTText.body.copyWith(
                                        color: context.fast.t2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: context.fast.t2,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(address);
                                  } else {
                                    _remove(address);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(tr(ctx, 'edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(tr(ctx, 'del')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: FASTSpace.s12),
                FastButton(
                  kind: FastButtonKind.ink,
                  onPressed: _edit,
                  icon: Icons.add_location_alt_outlined,
                  label: tr(context, 'address_add'),
                ),
              ],
            ),
          );
    return widget.embedded
        ? body
        : Scaffold(
            backgroundColor: context.fast.bg,
            appBar: AppBar(
              title: Text(
                tr(context, 'addresses'),
                style: FASTText.item.copyWith(
                  color: context.fast.t1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            body: body,
          );
  }
}
