import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/supplier.dart';
import '../../../l10n/l10n.dart';
import '../../inventory/widgets/name_dialog.dart';
import '../providers/suppliers_providers.dart';

/// Bottom sheet to choose a supplier, with search and quick add.
/// Returns the chosen (or newly created) supplier, or null.
Future<Supplier?> pickSupplier(BuildContext context) {
  return showModalBottomSheet<Supplier>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PickerSheet(),
  );
}

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet();

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final l10n = context.l10n;
    final name = await showNameDialog(
      context,
      title: l10n.newSupplier,
      label: l10n.supplierName,
    );
    if (name == null || !mounted) return;
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final id = await repo.create(SupplierInput(name: name));
      final supplier = await repo.getById(id);
      ref.refreshSuppliers();
      if (mounted && supplier != null) Navigator.pop(context, supplier);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suppliers = ref.watch(supplierSearchProvider(_query)).value;
    final height = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: l10n.searchSuppliers,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addNew,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l10n.newSupplier),
                ),
              ),
            ),
            Expanded(
              child: suppliers == null
                  ? const Center(child: CircularProgressIndicator())
                  : suppliers.isEmpty
                      ? Center(child: Text(l10n.noSuppliers))
                      : ListView.separated(
                          itemCount: suppliers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final supplier = suppliers[index];
                            return ListTile(
                              title: Text(supplier.name),
                              subtitle: supplier.phone == null
                                  ? null
                                  : Text(supplier.phone!),
                              onTap: () => Navigator.pop(context, supplier),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
