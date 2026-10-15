import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../data/repositories/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

/// The day shown in the sales history (local date, time part is midnight).
class SalesDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDay(DateTime day) => state = DateTime(day.year, day.month, day.day);

  void shift(int days) =>
      state = DateTime(state.year, state.month, state.day + days);

  void today() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final salesDayProvider =
    NotifierProvider<SalesDayNotifier, DateTime>(SalesDayNotifier.new);

/// Invoices of the selected day, newest first.
final invoicesProvider =
    FutureProvider.autoDispose<List<SaleTransaction>>((ref) {
  final day = ref.watch(salesDayProvider);
  final next = DateTime(day.year, day.month, day.day + 1);
  return ref.watch(transactionRepositoryProvider).list(from: day, to: next);
});

final invoiceDetailsProvider =
    FutureProvider.autoDispose.family<InvoiceDetails?, int>((ref, id) {
  return ref.watch(transactionRepositoryProvider).getWithItems(id);
});
