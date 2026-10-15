import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/database/database_providers.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/customer_balance.dart';
import '../../../data/repositories/customer_payment_repository.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../pos/providers/sales_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/ledger_builder.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(appDatabaseProvider));
});

final customerPaymentRepositoryProvider =
    Provider<CustomerPaymentRepository>((ref) {
  return CustomerPaymentRepository(ref.watch(appDatabaseProvider));
});

enum CustomerSort { name, debt }

/// Search text, "only with debt" switch and sort order of the customers list.
class CustomerFilter {
  const CustomerFilter({
    this.query = '',
    this.onlyWithDebt = false,
    this.sort = CustomerSort.name,
  });

  final String query;
  final bool onlyWithDebt;
  final CustomerSort sort;
}

class CustomerFilterNotifier extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() => const CustomerFilter();

  void setQuery(String query) => state = CustomerFilter(
        query: query,
        onlyWithDebt: state.onlyWithDebt,
        sort: state.sort,
      );

  void setOnlyWithDebt(bool value) => state = CustomerFilter(
        query: state.query,
        onlyWithDebt: value,
        sort: state.sort,
      );

  void setSort(CustomerSort sort) => state = CustomerFilter(
        query: state.query,
        onlyWithDebt: state.onlyWithDebt,
        sort: sort,
      );
}

final customerFilterProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilter>(
  CustomerFilterNotifier.new,
);

/// Customers with balances, filtered and sorted as chosen.
final customersProvider =
    FutureProvider.autoDispose<List<CustomerWithBalance>>((ref) async {
  final filter = ref.watch(customerFilterProvider);
  final settings = ref.watch(settingsProvider).value;
  var list = await ref
      .watch(customerRepositoryProvider)
      .listWithBalances(query: filter.query);
  if (filter.onlyWithDebt) {
    list = list.where((item) => item.balance.owes).toList();
  }
  if (filter.sort == CustomerSort.debt &&
      settings != null &&
      settings.isConfigured) {
    final base = settings.baseCurrency!;
    int owed(CustomerWithBalance item) =>
        item.balance.owedIn(base, settings.rate);
    list = [...list]..sort((a, b) {
        final byDebt = owed(b).compareTo(owed(a));
        return byDebt != 0
            ? byDebt
            : a.customer.name.compareTo(b.customer.name);
      });
  }
  return list;
});

/// Total owed by all customers (credit balances are not subtracted).
class DebtTotals {
  const DebtTotals({required this.byCurrency, required this.customersWithDebt});

  final Map<Currency, int> byCurrency;
  final int customersWithDebt;
}

final debtTotalsProvider = FutureProvider.autoDispose<DebtTotals>((ref) async {
  final all = await ref.watch(customerRepositoryProvider).listWithBalances();
  final totals = <Currency, int>{};
  var withDebt = 0;
  for (final item in all) {
    if (item.balance.owes) withDebt++;
    item.balance.amounts.forEach((currency, value) {
      if (value > 0) totals[currency] = (totals[currency] ?? 0) + value;
    });
  }
  return DebtTotals(byCurrency: totals, customersWithDebt: withDebt);
});

/// Customer search for the picker in the checkout screen.
final customerSearchProvider =
    FutureProvider.autoDispose.family<List<Customer>, String>((ref, query) {
  return ref.watch(customerRepositoryProvider).list(query: query);
});

final customerByIdProvider =
    FutureProvider.autoDispose.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).getById(id);
});

/// A customer, his balances and his statement.
class CustomerLedger {
  const CustomerLedger({
    required this.customer,
    required this.balance,
    required this.entries,
  });

  final Customer customer;
  final CustomerBalance balance;

  /// Oldest first.
  final List<LedgerEntry> entries;
}

final customerLedgerProvider =
    FutureProvider.autoDispose.family<CustomerLedger?, int>((ref, id) async {
  final customers = ref.watch(customerRepositoryProvider);
  final customer = await customers.getById(id);
  if (customer == null) return null;
  final balance = await customers.balanceOf(id);
  final invoices =
      await ref.watch(transactionRepositoryProvider).list(customerId: id);
  final payments =
      await ref.watch(customerPaymentRepositoryProvider).listForCustomer(id);
  return CustomerLedger(
    customer: customer,
    balance: balance,
    entries: LedgerBuilder.build(invoices: invoices, payments: payments),
  );
});

extension CustomersRefresh on WidgetRef {
  /// Reloads everything that shows customers or debts.
  void refreshCustomers() {
    invalidate(customersProvider);
    invalidate(debtTotalsProvider);
    invalidate(customerSearchProvider);
    invalidate(customerByIdProvider);
    invalidate(customerLedgerProvider);
  }
}
