import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/database/database_providers.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/supplier_balance.dart';
import '../../../data/repositories/supplier_payment_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../purchases/providers/purchases_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/supplier_ledger_builder.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(appDatabaseProvider));
});

final supplierPaymentRepositoryProvider =
    Provider<SupplierPaymentRepository>((ref) {
  return SupplierPaymentRepository(ref.watch(appDatabaseProvider));
});

enum SupplierSort { name, debt }

/// Search text, "only what we owe" switch and sort order of the suppliers list.
class SupplierFilter {
  const SupplierFilter({
    this.query = '',
    this.onlyOwed = false,
    this.sort = SupplierSort.name,
  });

  final String query;
  final bool onlyOwed;
  final SupplierSort sort;
}

class SupplierFilterNotifier extends Notifier<SupplierFilter> {
  @override
  SupplierFilter build() => const SupplierFilter();

  void setQuery(String query) => state = SupplierFilter(
        query: query,
        onlyOwed: state.onlyOwed,
        sort: state.sort,
      );

  void setOnlyOwed(bool value) => state = SupplierFilter(
        query: state.query,
        onlyOwed: value,
        sort: state.sort,
      );

  void setSort(SupplierSort sort) => state = SupplierFilter(
        query: state.query,
        onlyOwed: state.onlyOwed,
        sort: sort,
      );
}

final supplierFilterProvider =
    NotifierProvider<SupplierFilterNotifier, SupplierFilter>(
  SupplierFilterNotifier.new,
);

/// Suppliers with balances, filtered and sorted as chosen.
final suppliersProvider =
    FutureProvider.autoDispose<List<SupplierWithBalance>>((ref) async {
  final filter = ref.watch(supplierFilterProvider);
  final settings = ref.watch(settingsProvider).value;
  var list = await ref
      .watch(supplierRepositoryProvider)
      .listWithBalances(query: filter.query);
  if (filter.onlyOwed) {
    list = list.where((item) => item.balance.owed).toList();
  }
  if (filter.sort == SupplierSort.debt &&
      settings != null &&
      settings.isConfigured) {
    final base = settings.baseCurrency!;
    int owed(SupplierWithBalance item) =>
        item.balance.owedIn(base, settings.rate);
    list = [...list]..sort((a, b) {
        final byDebt = owed(b).compareTo(owed(a));
        return byDebt != 0
            ? byDebt
            : a.supplier.name.compareTo(b.supplier.name);
      });
  }
  return list;
});

/// Total owed to all suppliers (advances are not subtracted).
class PayableTotals {
  const PayableTotals({required this.byCurrency, required this.suppliersOwed});

  final Map<Currency, int> byCurrency;
  final int suppliersOwed;
}

final payableTotalsProvider =
    FutureProvider.autoDispose<PayableTotals>((ref) async {
  final all = await ref.watch(supplierRepositoryProvider).listWithBalances();
  final totals = <Currency, int>{};
  var owed = 0;
  for (final item in all) {
    if (item.balance.owed) owed++;
    item.balance.amounts.forEach((currency, value) {
      if (value > 0) totals[currency] = (totals[currency] ?? 0) + value;
    });
  }
  return PayableTotals(byCurrency: totals, suppliersOwed: owed);
});

/// Supplier search for the picker in the purchase screen.
final supplierSearchProvider =
    FutureProvider.autoDispose.family<List<Supplier>, String>((ref, query) {
  return ref.watch(supplierRepositoryProvider).list(query: query);
});

final supplierByIdProvider =
    FutureProvider.autoDispose.family<Supplier?, int>((ref, id) {
  return ref.watch(supplierRepositoryProvider).getById(id);
});

/// A supplier, what the shop owes him and his statement.
class SupplierLedger {
  const SupplierLedger({
    required this.supplier,
    required this.balance,
    required this.entries,
  });

  final Supplier supplier;
  final SupplierBalance balance;

  /// Oldest first.
  final List<SupplierLedgerEntry> entries;
}

final supplierLedgerProvider =
    FutureProvider.autoDispose.family<SupplierLedger?, int>((ref, id) async {
  final suppliers = ref.watch(supplierRepositoryProvider);
  final supplier = await suppliers.getById(id);
  if (supplier == null) return null;
  final balance = await suppliers.balanceOf(id);
  final purchases =
      await ref.watch(purchaseRepositoryProvider).list(supplierId: id);
  final payments =
      await ref.watch(supplierPaymentRepositoryProvider).listForSupplier(id);
  return SupplierLedger(
    supplier: supplier,
    balance: balance,
    entries: SupplierLedgerBuilder.build(purchases: purchases, payments: payments),
  );
});

extension SuppliersRefresh on WidgetRef {
  /// Reloads everything that shows suppliers or what the shop owes.
  void refreshSuppliers() {
    invalidate(suppliersProvider);
    invalidate(payableTotalsProvider);
    invalidate(supplierSearchProvider);
    invalidate(supplierByIdProvider);
    invalidate(supplierLedgerProvider);
  }
}
