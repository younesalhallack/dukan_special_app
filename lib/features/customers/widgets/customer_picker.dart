import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/customer.dart';
import '../../../l10n/l10n.dart';
import '../../inventory/widgets/name_dialog.dart';
import '../providers/customers_providers.dart';

/// Bottom sheet to choose a customer, with search and quick add.
/// Returns the chosen (or newly created) customer, or null.
Future<Customer?> pickCustomer(BuildContext context) {
  return showModalBottomSheet<Customer>(
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
      title: l10n.newCustomer,
      label: l10n.customerName,
    );
    if (name == null || !mounted) return;
    try {
      final repo = ref.read(customerRepositoryProvider);
      final id = await repo.create(CustomerInput(name: name));
      final customer = await repo.getById(id);
      ref.refreshCustomers();
      if (mounted && customer != null) Navigator.pop(context, customer);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final customers = ref.watch(customerSearchProvider(_query)).value;
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
                  hintText: l10n.searchCustomers,
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
                  label: Text(l10n.newCustomer),
                ),
              ),
            ),
            Expanded(
              child: customers == null
                  ? const Center(child: CircularProgressIndicator())
                  : customers.isEmpty
                      ? Center(child: Text(l10n.noCustomers))
                      : ListView.separated(
                          itemCount: customers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return ListTile(
                              title: Text(customer.name),
                              subtitle: customer.phone == null
                                  ? null
                                  : Text(customer.phone!),
                              onTap: () => Navigator.pop(context, customer),
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
