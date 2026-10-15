import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/customer_balance.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/customers_providers.dart';
import 'customer_form_screen.dart';
import 'customer_ledger_screen.dart';

/// Customers and what they owe (Al-Deftar).
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(customerFilterProvider).query);
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
    final filter = ref.watch(customerFilterProvider);
    final filterNotifier = ref.read(customerFilterProvider.notifier);
    final async = ref.watch(customersProvider);
    final customers = async.value;
    final totals = ref.watch(debtTotalsProvider).value;

    Widget list;
    if (customers == null) {
      list = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else if (customers.isEmpty) {
      list = Center(child: Text(l10n.noCustomers));
    } else {
      list = ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = customers[index];
          return ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerLedgerScreen(customerId: item.customer.id),
              ),
            ),
            title: Text(item.customer.name),
            subtitle: item.customer.phone == null ? null : Text(item.customer.phone!),
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
        title: Text(l10n.customers),
        actions: [
          PopupMenuButton<CustomerSort>(
            icon: const Icon(Icons.sort),
            onSelected: filterNotifier.setSort,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: CustomerSort.name,
                checked: filter.sort == CustomerSort.name,
                child: Text(l10n.sortByName),
              ),
              CheckedPopupMenuItem(
                value: CustomerSort.debt,
                checked: filter.sort == CustomerSort.debt,
                child: Text(l10n.sortByDebt),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CustomerFormScreen()),
        ),
        tooltip: l10n.addCustomer,
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
                    Text(l10n.totalDebts, style: Theme.of(context).textTheme.titleSmall),
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
                        '${l10n.debtEquivalent}: ${Money.format(CustomerBalance(totals.byCurrency).owedIn(base, rate), base, digits: digits)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      l10n.customersWithDebt(
                        Digits.localize('${totals.customersWithDebt}', digits),
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
                hintText: l10n.searchCustomers,
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
                label: Text(l10n.onlyWithDebt),
                selected: filter.onlyWithDebt,
                onSelected: filterNotifier.setOnlyWithDebt,
              ),
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}

/// The balance of a customer in the list: red when he owes, another colour
/// when he has a credit in his favour.
class _BalanceText extends StatelessWidget {
  const _BalanceText({
    required this.balance,
    required this.base,
    required this.digits,
  });

  final CustomerBalance balance;
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
              : '${l10n.creditInFavor}: ${Money.format(-value, currency, digits: digits)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: value > 0 ? scheme.error : scheme.primary,
          ),
        ),
      );
    }
    if (lines.isEmpty) {
      return Text(l10n.noDebt, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: lines,
    );
  }
}
