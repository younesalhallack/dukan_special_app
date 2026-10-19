import 'package:sqflite/sqflite.dart';

import '../../core/currency/currency.dart';
import '../../core/database/schema.dart';
import '../models/supplier_balance.dart';

/// The one place where supplier balances are computed:
///
///   balance = sum(total - paid) of completed credit purchases
///           - sum(applied_amount) of supplier payments that are not voided
///
/// per supplier and per currency.
abstract final class SupplierBalanceQueries {
  static Future<Map<int, SupplierBalance>> forAll(
    DatabaseExecutor executor, {
    int? supplierId,
  }) async {
    final filter = supplierId == null ? '' : ' AND supplier_id = ?';
    final args = supplierId == null ? <Object?>[] : <Object?>[supplierId];

    final purchases = await executor.rawQuery(
      'SELECT supplier_id, currency, SUM(total_amount - paid_amount) AS amount '
      'FROM ${Tables.purchases} '
      "WHERE payment_type = 'credit' AND status = 'completed' "
      'AND supplier_id IS NOT NULL$filter '
      'GROUP BY supplier_id, currency',
      args,
    );
    final payments = await executor.rawQuery(
      'SELECT supplier_id, applied_currency AS currency, '
      'SUM(applied_amount) AS amount '
      'FROM ${Tables.supplierPayments} '
      'WHERE is_voided = 0$filter '
      'GROUP BY supplier_id, applied_currency',
      args,
    );

    final totals = <int, Map<Currency, int>>{};
    void add(List<Map<String, Object?>> rows, int sign) {
      for (final row in rows) {
        final id = row['supplier_id'] as int;
        final currency = Currency.fromCode(row['currency'] as String);
        final amount = (row['amount'] as num).toInt() * sign;
        final byCurrency = totals.putIfAbsent(id, () => <Currency, int>{});
        byCurrency[currency] = (byCurrency[currency] ?? 0) + amount;
      }
    }

    add(purchases, 1);
    add(payments, -1);
    return {
      for (final entry in totals.entries) entry.key: SupplierBalance(entry.value),
    };
  }

  static Future<SupplierBalance> forSupplier(
    DatabaseExecutor executor,
    int supplierId,
  ) async {
    final all = await forAll(executor, supplierId: supplierId);
    return all[supplierId] ?? SupplierBalance.zero;
  }
}
