import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/supplier_balance.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/suppliers_providers.dart';
import 'supplier_form_screen.dart';
import 'supplier_ledger_screen.dart';

/// Suppliers and what they owe (Al-Deftar).
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(supplierFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final filter = ref.watch(supplierFilterProvider);
    final filterNotifier = ref.read(supplierFilterProvider.notifier);
    final async = ref.watch(suppliersProvider);
    final suppliers = async.value;
    final totals = ref.watch(payableTotalsProvider).value;

    Widget list;
    if (suppliers == null) {
      list = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else if (suppliers.isEmpty) {
      list = Center(child: Text(l10n.noSuppliers));
    } else {
      list = ListView.separated(
        itemCount: suppliers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = suppliers[index];
          return ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SupplierLedgerScreen(supplierId: item.supplier.id),
              ),
            ),
            title: Text(item.supplier.name),
            subtitle: item.supplier.phone == null ? null : Text(item.supplier.phone!),
            trailing: _BalanceText(
              balance: item.balance,
              base: settings?.baseCurrency ?? Currency.syp,
              digits: digits,
            ),
          );
        },
      );
    }

    final base = settings?.baseCurrency ?? Currency.syp;
    final rate = settings != null && settings.isConfigured ? settings.rate : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suppliers),
        actions: [
          PopupMenuButton<SupplierSort>(
            icon: const Icon(Icons.sort),
            onSelected: filterNotifier.setSort,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: SupplierSort.name,
                checked: filter.sort == SupplierSort.name,
                child: Text(l10n.sortByName),
              ),
              CheckedPopupMenuItem(
                value: SupplierSort.debt,
                checked: filter.sort == SupplierSort.debt,
                child: Text(l10n.sortByDebt),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SupplierFormScreen()),
        ),
        tooltip: l10n.addSupplier,
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: Column(
        children: [
          if (totals != null && totals.byCurrency.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.totalPayables, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final entry in totals.byCurrency.entries)
                      Text(
                        Money.format(entry.value, entry.key, digits: digits),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    if (rate != null && totals.byCurrency.length > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.debtEquivalent}: ${Money.format(SupplierBalance(totals.byCurrency).owedIn(base, rate), base, digits: digits)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      l10n.suppliersWithDebt(
                        Digits.localize('${totals.suppliersOwed}', digits),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.searchSuppliers,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: filterNotifier.setQuery,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilterChip(
                label: Text(l10n.onlyWeOwe),
                selected: filter.onlyOwed,
                onSelected: filterNotifier.setOnlyOwed,
              ),
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}

/// The balance of a supplier in the list: red when he owes, another colour
/// when he has a credit in his favour.
class _BalanceText extends StatelessWidget {
  const _BalanceText({
    required this.balance,
    required this.base,
    required this.digits,
  });

  final SupplierBalance balance;
  final Currency base;
  final DigitStyle digits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lines = <Widget>[];
    for (final currency in [base, base.other]) {
      final value = balance.of(currency);
      if (value == 0) continue;
      lines.add(
        Text(
          value > 0
              ? Money.format(value, currency, digits: digits)
              : '${l10n.advanceWithSupplier}: ${Money.format(-value, currency, digits: digits)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: value > 0 ? scheme.error : scheme.primary,
          ),
        ),
      );
    }
    if (lines.isEmpty) {
      return Text(l10n.noPayable, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: lines,
    );
  }
}
