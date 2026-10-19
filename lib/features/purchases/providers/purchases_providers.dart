import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../data/models/purchase.dart';
import '../../../data/repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(appDatabaseProvider));
});

/// The day shown in the purchases history (local date).
class PurchasesDayNotifier extends Notifier<DateTime> {
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

final purchasesDayProvider =
    NotifierProvider<PurchasesDayNotifier, DateTime>(PurchasesDayNotifier.new);

/// Purchases of the selected day, newest first.
final purchasesProvider = FutureProvider.autoDispose<List<Purchase>>((ref) {
  final day = ref.watch(purchasesDayProvider);
  final next = DateTime(day.year, day.month, day.day + 1);
  return ref.watch(purchaseRepositoryProvider).list(from: day, to: next);
});

final purchaseDetailsProvider =
    FutureProvider.autoDispose.family<PurchaseDetails?, int>((ref, id) {
  return ref.watch(purchaseRepositoryProvider).getWithItems(id);
});

extension PurchasesRefresh on WidgetRef {
  /// Reloads the purchase lists after a change.
  void refreshPurchases() {
    invalidate(purchasesProvider);
    invalidate(purchaseDetailsProvider);
  }
}
